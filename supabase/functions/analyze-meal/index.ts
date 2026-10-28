const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

const resultShape = `{
  "mealName": "short meal name",
  "calories": 0,
  "protein": 0,
  "carbs": 0,
  "fat": 0,
  "confidence": 0,
  "ingredients": [{"name": "ingredient", "portion": "serving", "calories": 0}],
  "note": "brief uncertainty note"
}`;

function isImageDataUrl(value: unknown): value is string {
  return typeof value === "string" &&
    /^data:image\/(jpeg|jpg|png|webp);base64,[A-Za-z0-9+/=]+$/.test(value);
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ error: "POST required" }, 405);

  const apiKey = Deno.env.get("OPENAI_API_KEY") ?? "";
  if (!apiKey) return json({ error: "Food analysis service is not configured" }, 503);

  let body: { imageUrl?: unknown };
  try {
    body = await request.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }
  if (!isImageDataUrl(body.imageUrl)) {
    return json({ error: "A camera image is required" }, 400);
  }
  if (body.imageUrl.length > 15_000_000) {
    return json({ error: "Image is too large. Please retake the photo." }, 413);
  }

  const response = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: Deno.env.get("FOOD_VISION_MODEL") ?? "gpt-4o-mini",
      temperature: 0.1,
      response_format: { type: "json_object" },
      messages: [
        {
          role: "system",
          content: `You are a careful nutrition estimation assistant. Identify the visible meal and estimate calories and macros for the complete pictured portion. Never claim medical certainty. Return only valid JSON matching this shape: ${resultShape}. Use numbers for calories and grams. If the photo is not food, return mealName "Food not identified", all numeric values 0, an empty ingredients array, and explain it in note.`,
        },
        {
          role: "user",
          content: [
            { type: "text", text: "Analyse this food photo for a wellness app." },
            { type: "image_url", image_url: { url: body.imageUrl, detail: "low" } },
          ],
        },
      ],
    }),
    signal: AbortSignal.timeout(35_000),
  });

  if (!response.ok) {
    await response.body?.cancel();
    return json({ error: "Food analysis is temporarily unavailable" }, 502);
  }

  try {
    const provider = await response.json();
    const content = provider?.choices?.[0]?.message?.content;
    const analysis = typeof content === "string" ? JSON.parse(content) : null;
    if (!analysis || typeof analysis !== "object") {
      return json({ error: "No nutrition result was returned" }, 502);
    }
    return json({ success: true, data: analysis });
  } catch {
    return json({ error: "Food analysis returned an invalid result" }, 502);
  }
});
