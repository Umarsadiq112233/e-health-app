import 'dart:async';

import 'package:e_health_app/features/health_metrics/data/local_health_repository.dart';
import 'package:e_health_app/features/health_metrics/domain/health_reading.dart';
import 'package:e_health_app/features/health_metrics/presentation/cubit/health_cubit.dart';
import 'package:e_health_app/shared/widgets/health_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

HealthReading sample(DateTime timestamp, {double value = 64}) => HealthReading(
  metric: HealthMetricType.heartRate,
  value: value,
  unit: 'BPM',
  timestamp: timestamp,
  source: HealthSource.wearable,
  deviceId: 'test-only-device',
);

class ControlledHealthRepository implements HealthRepository {
  List<HealthReading> values = [];
  bool offline = false;
  Completer<List<HealthReading>>? pending;
  @override
  Future<List<HealthReading>> read(String userId) async {
    if (offline) throw StateError('private backend failure');
    return pending?.future ?? values;
  }

  @override
  Future<void> save(String userId, List<HealthReading> readings) async {
    if (offline) throw StateError('private backend failure');
    values = readings;
  }
}

void main() {
  test('Readings enforce finite values, units and wearable provenance', () {
    expect(
      () => sample(DateTime.now(), value: double.nan),
      throwsArgumentError,
    );
    expect(
      () => HealthReading(
        metric: HealthMetricType.steps,
        value: 2,
        unit: 'steps',
        timestamp: DateTime.now(),
        source: HealthSource.wearable,
      ),
      throwsArgumentError,
    );
    expect(sample(DateTime(2026)).timestamp.isUtc, true);
  });
  test(
    'Repository deduplicates and isolates accounts without generating data',
    () async {
      final repository = LocalHealthRepository();
      final reading = sample(DateTime.utc(2026, 10, 6));
      expect(await repository.read('a'), isEmpty);
      await repository.save('a', [reading, reading]);
      expect(await repository.read('a'), hasLength(1));
      expect(await repository.read('b'), isEmpty);
    },
  );
  test(
    'History filters today, seven and thirty days; excludes future samples',
    () {
      final now = DateTime(2026, 10, 6, 12);
      final state = HealthState(
        readings: [
          for (final day in [0, 2, 10, 35, -1])
            sample(now.subtract(Duration(days: day))),
        ],
      );
      expect(
        state.history(HealthMetricType.heartRate, 1, now: now),
        hasLength(1),
      );
      expect(
        state.history(HealthMetricType.heartRate, 7, now: now),
        hasLength(2),
      );
      expect(
        state.history(HealthMetricType.heartRate, 30, now: now),
        hasLength(3),
      );
      expect(state.history(HealthMetricType.sleep, 30, now: now), isEmpty);
    },
  );
  test(
    'Backend failure preserves timestamped history and retry recovers',
    () async {
      final repository = ControlledHealthRepository()
        ..values = [sample(DateTime.utc(2026, 10, 6))];
      final cubit = HealthCubit(repository);
      await cubit.bindUser('a');
      expect(cubit.state.phase, HealthPhase.available);
      repository.offline = true;
      await cubit.refresh();
      expect(cubit.state.phase, HealthPhase.error);
      expect(cubit.state.readings, hasLength(1));
      expect(cubit.state.error, isNot(contains('private')));
      cubit.deviceDisconnected();
      expect(cubit.state.readings, hasLength(1));
      repository.offline = false;
      await cubit.refresh();
      expect(cubit.state.phase, HealthPhase.available);
      await cubit.bindUser(null);
      expect(cubit.state.readings, isEmpty);
      await cubit.close();
    },
  );
  test('Logout ignores in-flight data from the previous account', () async {
    final repository = ControlledHealthRepository()
      ..pending = Completer<List<HealthReading>>();
    final cubit = HealthCubit(repository);
    final load = cubit.bindUser('a');
    await cubit.bindUser(null);
    repository.pending!.complete([sample(DateTime.now())]);
    await load;
    expect(cubit.state.phase, HealthPhase.noData);
    expect(cubit.state.readings, isEmpty);
    await cubit.close();
  });
  testWidgets(
    'Charts render empty, one and multiple real samples without errors',
    (tester) async {
      for (final count in [0, 1, 3]) {
        final values = [
          for (var i = 0; i < count; i++)
            sample(DateTime.utc(2026, 10, 6, i), value: 60 + i.toDouble()),
        ];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: HealthChart(readings: values)),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        if (count == 0) {
          expect(find.text('No readings in this period'), findsOneWidget);
        }
      }
    },
  );
}
