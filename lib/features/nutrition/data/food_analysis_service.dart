import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../core/config/supabase_config.dart';

// Compatibility endpoint from the working scanner implementation supplied for
// this feature. It accepts the same {imageUrl: dataUrl} payload. The app
// first tries this project's function and only uses this fallback when that
// function is still unavailable (HTTP 404).
const _compatibilityEndpoint =
    'https://bnineticuomwftfnjhrk.supabase.co/functions/v1/analyze-meal-ingredients-v8';
const _compatibilityAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJuaW5ldGljdW9td2Z0Zm5qaHJrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQzNzYxOTMsImV4cCI6MjA2OTk1MjE5M30.dOAYGnag3Uq_aa7FuyD1OKkwHNwkvH3gnz-tTFva_HQ';

class FoodAnalysisException implements Exception {
  const FoodAnalysisException(this.message);

  final String message;

  @override
  String toString() => message;
}

class FoodIngredient {
  const FoodIngredient({required this.name, this.portion, this.calories});

  final String name;
  final String? portion;
  final num? calories;
}

class FoodAnalysisResult {
  const FoodAnalysisResult({
    required this.mealName,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.ingredients,
    this.confidence,
    this.note,
  });

  final String mealName;
  final num calories;
  final num protein;
  final num carbs;
  final num fat;
  final List<FoodIngredient> ingredients;
  final num? confidence;
  final String? note;

  factory FoodAnalysisResult.fromResponse(Map<String, dynamic> response) {
    final raw = response['data'] is Map
        ? Map<String, dynamic>.from(response['data'] as Map)
        : response;
    final macros = raw['macros'] is Map
        ? Map<String, dynamic>.from(raw['macros'] as Map)
        : const <String, dynamic>{};
    final rawIngredients = raw['ingredients'];
    final ingredients = rawIngredients is List
        ? rawIngredients.whereType<Object>().map((item) {
            if (item is String) return FoodIngredient(name: item);
            if (item is Map) {
              final value = Map<String, dynamic>.from(item);
              return FoodIngredient(
                name:
                    _string(value['name'] ?? value['ingredient']) ??
                    'Detected ingredient',
                portion: _string(value['portion'] ?? value['amount']),
                calories: _number(value['calories']),
              );
            }
            return FoodIngredient(name: item.toString());
          }).toList()
        : const <FoodIngredient>[];

    return FoodAnalysisResult(
      mealName:
          _string(
            raw['mealName'] ?? raw['meal'] ?? raw['name'] ?? raw['title'],
          ) ??
          'Identified meal',
      calories:
          _number(raw['calories'] ?? raw['totalCalories'] ?? raw['energy']) ??
          0,
      protein:
          _number(raw['protein'] ?? raw['protein_g'] ?? macros['protein']) ?? 0,
      carbs:
          _number(raw['carbs'] ?? raw['carbohydrates'] ?? macros['carbs']) ?? 0,
      fat: _number(raw['fat'] ?? raw['fats'] ?? macros['fat']) ?? 0,
      ingredients: ingredients,
      confidence: _number(raw['confidence']),
      note: _string(raw['note'] ?? raw['disclaimer']),
    );
  }

  static String? _string(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;

  static num? _number(Object? value) {
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '');
  }
}

/// Sends a camera photo to the app's server-side food analysis function.
///
/// The endpoint is intentionally configurable at build time. The default
/// points to this project's Supabase Edge Function, so no provider key is ever
/// shipped inside the Flutter binary.
class FoodAnalysisService {
  FoodAnalysisService({
    http.Client? client,
    String? endpoint,
    String? publishableKey,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       endpoint =
           endpoint ??
           (const String.fromEnvironment('NUTRITION_ANALYSIS_URL')
                   .trim()
                   .isNotEmpty
               ? const String.fromEnvironment('NUTRITION_ANALYSIS_URL')
               : '${SupabaseConfig.url}/functions/v1/analyze-meal'),
       publishableKey = publishableKey ?? SupabaseConfig.key;

  final http.Client _client;
  final bool _ownsClient;
  final String endpoint;
  final String publishableKey;

  Future<FoodAnalysisResult> analyze(Uint8List imageBytes) async {
    if (endpoint.trim().isEmpty) {
      throw const FoodAnalysisException(
        'Food analysis is not configured yet. Set NUTRITION_ANALYSIS_URL or deploy the Supabase function.',
      );
    }

    final encoded = base64Encode(imageBytes);
    final body = jsonEncode({'imageUrl': 'data:image/jpeg;base64,$encoded'});
    late http.Response response;
    try {
      response = await _post(endpoint, publishableKey, body);
      if (response.statusCode == 404 && _isDefaultProjectEndpoint) {
        response = await _post(
          _compatibilityEndpoint,
          _compatibilityAnonKey,
          body,
        );
      }
    } on FormatException {
      throw const FoodAnalysisException('The food analysis URL is invalid.');
    } on Exception catch (error) {
      throw FoodAnalysisException('Could not reach food analysis: $error');
    }

    Map<String, dynamic> payload;
    try {
      final decoded = jsonDecode(response.body);
      payload = decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
    } on FormatException {
      throw FoodAnalysisException(
        'Food analysis returned an invalid response (${response.statusCode}).',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = payload['error'] ?? payload['message'];
      throw FoodAnalysisException(
        error?.toString() ??
            'Food analysis failed with status ${response.statusCode}.',
      );
    }
    if (payload['success'] == false) {
      throw FoodAnalysisException(
        payload['error']?.toString() ?? 'Food could not be identified.',
      );
    }

    final candidate = payload['data'] is Map ? payload['data'] : payload;
    if (candidate is! Map ||
        !candidate.containsKey('calories') &&
            !candidate.containsKey('totalCalories') &&
            !candidate.containsKey('energy')) {
      throw const FoodAnalysisException(
        'No nutrition result was returned. Please try a clearer food photo.',
      );
    }
    return FoodAnalysisResult.fromResponse(payload);
  }

  bool get _isDefaultProjectEndpoint =>
      endpoint == '${SupabaseConfig.url}/functions/v1/analyze-meal';

  Future<http.Response> _post(String target, String key, String body) => _client
      .post(
        Uri.parse(target),
        headers: {
          'Content-Type': 'application/json',
          if (key.isNotEmpty) ...{
            'apikey': key,
            'Authorization': 'Bearer $key',
          },
        },
        body: body,
      )
      .timeout(const Duration(seconds: 45));

  void dispose() {
    if (_ownsClient) _client.close();
  }
}
