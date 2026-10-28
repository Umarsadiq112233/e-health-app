import 'dart:convert';
import 'dart:typed_data';

import 'package:e_health_app/features/nutrition/data/food_analysis_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('posts the camera image and parses nutrition values', () async {
    late Map<String, dynamic> requestBody;
    final client = MockClient((request) async {
      requestBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'mealName': 'Chicken salad',
            'calories': 420,
            'protein': 32,
            'carbs': 18,
            'fat': 21,
            'ingredients': [
              {'name': 'Chicken', 'portion': '120 g', 'calories': 210},
            ],
          },
        }),
        200,
      );
    });
    final service = FoodAnalysisService(
      client: client,
      endpoint: 'https://example.test/analyze',
      publishableKey: 'test-key',
    );

    final result = await service.analyze(Uint8List.fromList([1, 2, 3]));

    expect(requestBody['imageUrl'], 'data:image/jpeg;base64,AQID');
    expect(result.mealName, 'Chicken salad');
    expect(result.calories, 420);
    expect(result.protein, 32);
    expect(result.ingredients.single.name, 'Chicken');
  });

  test('falls back to the working compatibility function when project function is missing', () async {
    final urls = <String>[];
    final client = MockClient((request) async {
      urls.add(request.url.toString());
      if (urls.length == 1) {
        return http.Response('{"error":"function not found"}', 404);
      }
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {'mealName': 'Fruit bowl', 'calories': 180},
        }),
        200,
      );
    });
    final service = FoodAnalysisService(
      client: client,
      endpoint:
          'https://agigsbwjaupsfvhcnseg.supabase.co/functions/v1/analyze-meal',
      publishableKey: 'test-key',
    );

    final result = await service.analyze(Uint8List.fromList([1]));

    expect(result.mealName, 'Fruit bowl');
    expect(urls, [
      'https://agigsbwjaupsfvhcnseg.supabase.co/functions/v1/analyze-meal',
      'https://bnineticuomwftfnjhrk.supabase.co/functions/v1/analyze-meal-ingredients-v8',
    ]);
  });
}
