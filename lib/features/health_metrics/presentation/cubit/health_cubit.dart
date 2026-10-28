import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';

import '../../domain/health_reading.dart';
import '../../data/local_health_repository.dart';

enum HealthPhase { loading, available, noData, disconnected, syncing, error }

class HealthState {
  final HealthPhase phase;
  final List<HealthReading> readings;
  final String? error;
  const HealthState({
    this.phase = HealthPhase.noData,
    this.readings = const [],
    this.error,
  });
  List<HealthReading> history(
    HealthMetricType metric,
    int days, {
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final local = current.toLocal();
    final start = DateTime(
      local.year,
      local.month,
      local.day,
    ).subtract(Duration(days: days - 1)).toUtc();
    return readings
        .where(
          (r) =>
              r.metric == metric &&
              !r.timestamp.isBefore(start) &&
              !r.timestamp.isAfter(current.toUtc()),
        )
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  HealthReading? latest(HealthMetricType metric) {
    final values = readings.where((r) => r.metric == metric).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return values.isEmpty ? null : values.first;
  }
}

class HealthCubit extends Cubit<HealthState> {
  static final instance = HealthCubit(LocalHealthRepository());
  final HealthRepository repository;
  String? _userId;
  int _generation = 0;
  HealthCubit(this.repository) : super(const HealthState());
  Future<void> bindUser(String? id) async {
    if (_userId == id) return;
    _userId = id;
    ++_generation;
    emit(const HealthState());
    if (id != null) await refresh();
  }

  Future<void> refresh() async {
    final id = _userId;
    if (id == null || state.phase == HealthPhase.loading) return;
    final generation = _generation;
    final cached = state.readings;
    emit(HealthState(phase: HealthPhase.loading, readings: cached));
    try {
      final readings = await repository
          .read(id)
          .timeout(const Duration(seconds: 15));
      if (isClosed || generation != _generation) return;
      if (kDebugMode && readings.isEmpty) {
        debugPrint('[Health] No wearable data available');
      }
      emit(
        HealthState(
          phase: readings.isEmpty ? HealthPhase.noData : HealthPhase.available,
          readings: List.unmodifiable(readings),
        ),
      );
    } catch (_) {
      if (!isClosed && generation == _generation) {
        emit(
          HealthState(
            phase: HealthPhase.error,
            readings: cached,
            error: 'Readings could not be loaded. Your previous readings are still available.',
          ),
        );
      }
    }
  }

  Future<void> store(List<HealthReading> readings) async {
    final owner = _userId;
    if (owner == null) throw StateError('Sign in before saving readings');
    final generation = _generation;
    await repository.save(owner, readings).timeout(const Duration(seconds: 15));
    if (generation != _generation || isClosed) return;
    await refresh();
    if (generation == _generation && state.phase == HealthPhase.error) {
      throw StateError('Saved readings could not be reloaded');
    }
  }

  void deviceDisconnected() {
    if (!isClosed) {
      emit(
        HealthState(phase: HealthPhase.disconnected, readings: state.readings),
      );
    }
  }

  void syncing() {
    if (!isClosed) {
      emit(HealthState(phase: HealthPhase.syncing, readings: state.readings));
    }
  }
}
