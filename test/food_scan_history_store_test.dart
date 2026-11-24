import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:e_health_app/features/nutrition/data/food_analysis_service.dart';
import 'package:e_health_app/features/nutrition/data/food_scan_history_store.dart';

void main() {
  test(
    'saves completed scans and reloads them in newest-first order',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = FoodScanHistoryStore();

      final first = await store.add(
        const FoodAnalysisResult(
          mealName: 'Chicken bowl',
          calories: 540,
          protein: 32,
          carbs: 48,
          fat: 19,
          ingredients: [FoodIngredient(name: 'Chicken', portion: '120 g')],
        ),
        scannedAt: DateTime(2026, 10, 29, 12),
      );
      final second = await store.add(
        const FoodAnalysisResult(
          mealName: 'Fruit plate',
          calories: 220,
          protein: 4,
          carbs: 42,
          fat: 3,
          ingredients: [],
        ),
        scannedAt: DateTime(2026, 10, 29, 13),
      );

      final loaded = await FoodScanHistoryStore().load();

      expect(first.mealName, 'Chicken bowl');
      expect(second.mealName, 'Fruit plate');
      expect(loaded, hasLength(2));
      expect(loaded.first.mealName, 'Fruit plate');
      expect(loaded.first.calories, 220);
      expect(loaded.last.mealName, 'Chicken bowl');
      expect(loaded.last.ingredients.single.name, 'Chicken');
    },
  );
}
