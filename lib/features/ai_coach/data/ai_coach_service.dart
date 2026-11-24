import 'package:supabase_flutter/supabase_flutter.dart';

import '../../health_metrics/domain/health_reading.dart';
import '../../health_metrics/presentation/cubit/health_cubit.dart';

/// Sends AI Coach conversations to the `ai-coach` Supabase Edge Function,
/// which proxies them to the AI provider so no API key ships in the app.
class AiCoachService {
  const AiCoachService();

  /// [storedMessages] are the conversation's stored strings; entries
  /// starting with 'ai:' are earlier coach replies (prefix stripped),
  /// everything else is a user message. Returns the coach's reply text.
  /// Throws an [Exception] when the function call fails or returns no reply.
  Future<String> reply({required List<String> storedMessages}) async {
    final messages = [
      for (final stored in storedMessages)
        if (stored.startsWith('ai:'))
          {'role': 'assistant', 'content': stored.substring(3)}
        else
          {'role': 'user', 'content': stored},
    ];
    final FunctionResponse response;
    try {
      response = await Supabase.instance.client.functions.invoke(
        'ai-coach',
        body: {'messages': messages, 'context': _healthContext()},
      );
    } catch (error) {
      throw Exception('AI coach request failed: $error');
    }
    if (response.status != 200) {
      throw Exception('AI coach request failed (${response.status})');
    }
    final data = response.data;
    final text = data is Map ? data['reply'] : null;
    if (text is! String || text.trim().isEmpty) {
      throw Exception('AI coach returned an empty reply');
    }
    return text;
  }

  /// One-line summary of the user's current health readings, used to
  /// personalise replies. Empty when there is no recorded data yet.
  String _healthContext() {
    final state = HealthCubit.instance.state;
    if (state.readings.isEmpty) return '';
    final now = DateTime.now();
    // Step readings are cumulative daily totals, so — like the health
    // screens — the day's value is the largest reading, not the sum.
    var stepsToday = 0.0;
    for (final r in state.readings) {
      if (r.metric == HealthMetricType.steps &&
          _isToday(r.timestamp, now) &&
          r.value > stepsToday) {
        stepsToday = r.value;
      }
    }
    final heartRate = state.latest(HealthMetricType.heartRate);
    final sleep = state.latest(HealthMetricType.sleep);
    final parts = <String>[
      if (stepsToday > 0) 'steps today: ${stepsToday.round()}',
      if (heartRate != null)
        'latest heart rate: ${heartRate.value.round()} ${heartRate.unit}',
      if (sleep != null)
        'most recent sleep: ${sleep.value.toStringAsFixed(1)} ${sleep.unit}',
    ];
    return parts.join(', ');
  }

  bool _isToday(DateTime timestamp, DateTime now) {
    final local = timestamp.toLocal();
    return local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
  }
}
