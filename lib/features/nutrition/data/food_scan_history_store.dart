import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'food_analysis_service.dart';

/// A lightweight, on-device history record for a completed food analysis.
///
/// The captured photo is intentionally not persisted. Keeping only the
/// nutrition result makes history fast and prevents the app from growing with
/// every scan.
class FoodScanHistoryEntry {
  const FoodScanHistoryEntry({
    required this.scannedAt,
    required this.mealName,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.ingredients,
    this.confidence,
    this.note,
  });

  factory FoodScanHistoryEntry.fromResult(
    FoodAnalysisResult result, {
    DateTime? scannedAt,
  }) => FoodScanHistoryEntry(
    scannedAt: scannedAt ?? DateTime.now(),
    mealName: result.mealName,
    calories: result.calories,
    protein: result.protein,
    carbs: result.carbs,
    fat: result.fat,
    ingredients: result.ingredients,
    confidence: result.confidence,
    note: result.note,
  );

  factory FoodScanHistoryEntry.fromJson(Map<String, dynamic> json) {
    final scannedAtValue = json['scannedAt'];
    final scannedAt = scannedAtValue is String
        ? DateTime.tryParse(scannedAtValue)
        : null;
    if (scannedAt == null) {
      throw const FormatException('Invalid scan history timestamp.');
    }

    final rawIngredients = json['ingredients'];
    final ingredients = rawIngredients is List
        ? rawIngredients.whereType<Map>().map((item) {
            final value = Map<String, dynamic>.from(item);
            return FoodIngredient(
              name: value['name']?.toString() ?? 'Detected ingredient',
              portion: _string(value['portion']),
              calories: _number(value['calories']),
            );
          }).toList()
        : const <FoodIngredient>[];

    return FoodScanHistoryEntry(
      scannedAt: scannedAt,
      mealName: _string(json['mealName']) ?? 'Identified meal',
      calories: _number(json['calories']) ?? 0,
      protein: _number(json['protein']) ?? 0,
      carbs: _number(json['carbs']) ?? 0,
      fat: _number(json['fat']) ?? 0,
      ingredients: ingredients,
      confidence: _number(json['confidence']),
      note: _string(json['note']),
    );
  }

  final DateTime scannedAt;
  final String mealName;
  final num calories;
  final num protein;
  final num carbs;
  final num fat;
  final List<FoodIngredient> ingredients;
  final num? confidence;
  final String? note;

  Map<String, dynamic> toJson() => {
    'scannedAt': scannedAt.toIso8601String(),
    'mealName': mealName,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'ingredients': [
      for (final ingredient in ingredients)
        {
          'name': ingredient.name,
          if (ingredient.portion != null) 'portion': ingredient.portion,
          if (ingredient.calories != null) 'calories': ingredient.calories,
        },
    ],
    if (confidence != null) 'confidence': confidence,
    if (note != null) 'note': note,
  };

  static String? _string(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static num? _number(Object? value) {
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '');
  }
}

class FoodScanHistoryStore {
  static const storageKey = 'ehealth.food_scan_history.v1';
  static const maxEntries = 50;

  Future<List<FoodScanHistoryEntry>> load() async {
    final preferences = await SharedPreferences.getInstance();
    return _read(preferences);
  }

  Future<FoodScanHistoryEntry> add(
    FoodAnalysisResult result, {
    DateTime? scannedAt,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final entry = FoodScanHistoryEntry.fromResult(result, scannedAt: scannedAt);
    final entries = [entry, ..._read(preferences)].take(maxEntries).toList();
    await preferences.setString(
      storageKey,
      jsonEncode(entries.map((item) => item.toJson()).toList()),
    );
    return entry;
  }

  List<FoodScanHistoryEntry> _read(SharedPreferences preferences) {
    final raw = preferences.getString(storageKey);
    if (raw == null || raw.trim().isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final entries = <FoodScanHistoryEntry>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        try {
          entries.add(
            FoodScanHistoryEntry.fromJson(Map<String, dynamic>.from(item)),
          );
        } on FormatException {
          // Ignore one corrupt record without losing the remaining history.
        }
      }
      entries.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
      return entries;
    } on FormatException {
      return const [];
    }
  }
}
