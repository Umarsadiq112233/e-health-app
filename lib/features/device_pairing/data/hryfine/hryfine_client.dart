import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart' as ble;

import 'hryfine_protocol.dart';

/// Everything one health sync collected from the watch, already decoded
/// by the parsers in `hryfine_protocol.dart`.
class HryFineHealthData {
  final List<HryFineStepDay> stepDays;
  final List<HryFineHeartRateSample> heartRateSamples;
  final List<HryFineBloodPressureSample> bloodPressureSamples;
  final List<HryFineSleepTotals> sleepNights;
  final List<HryFineTemperatureSample> temperatureSamples;
  final List<HryFineBloodOxygenSample> bloodOxygenSamples;
  final HryFineTodaySteps? todaySteps;
  const HryFineHealthData({
    required this.stepDays,
    required this.heartRateSamples,
    required this.bloodPressureSamples,
    required this.sleepNights,
    required this.temperatureSamples,
    required this.bloodOxygenSamples,
    required this.todaySteps,
  });

  bool get isEmpty =>
      stepDays.isEmpty &&
      heartRateSamples.isEmpty &&
      bloodPressureSamples.isEmpty &&
      sleepNights.isEmpty &&
      temperatureSamples.isEmpty &&
      bloodOxygenSamples.isEmpty &&
      todaySteps == null;
}

/// Talks to a HryFine-family watch (including the H9 Max) over the Nordic
/// UART pair, following the connection sequence of the official app:
///
/// 1. subscribe to UART notifications,
/// 2. verification handshake (0xF0 → check reply → 0xF1 confirm),
/// 3. bind with the stable per-user id (0x03),
/// 4. push the phone's time (0x02 / sub 0x01),
/// 5. sync all health history (0x05 / sub 0x01) until the watch sends the
///    sync-finished marker (sub 0x08), ACKing every data frame.
///
/// The device must already be connected (the app connects through
/// `DeviceRepository` first). Commands are sent strictly one at a time and
/// every frame is written in 20-byte chunks, exactly as the official app
/// does — see PROTOCOL.md sections 3–5.
class HryFineClient {
  // Lazy, mirroring NativeDeviceRepository: the Bluetooth stack must not
  // initialise during app startup (notably on iOS).
  ble.FlutterReactiveBle? _client;
  ble.FlutterReactiveBle get _ble => _client ??= ble.FlutterReactiveBle();

  StreamSubscription<List<int>>? _subscription;
  final _reassembler = HryFineFrameReassembler();
  Future<void> _writeChain = Future<void>.value();

  // State filled by the notification dispatch while a sync runs.
  final _stepDays = <String, HryFineStepDay>{};
  final _heartRate = <HryFineHeartRateSample>[];
  final _bloodPressure = <HryFineBloodPressureSample>[];
  final _sleepNights = <String, HryFineSleepTotals>{};
  final _temperature = <HryFineTemperatureSample>[];
  final _bloodOxygen = <HryFineBloodOxygenSample>[];
  HryFineTodaySteps? _todaySteps;
  bool _syncFinished = false;
  DateTime? _lastHealthFrameAt;
  int? _verificationReplyByte;
  HryFineAck? _lastAck;
  HryFineFrame? _bindResponse;

  void _log(String message) {
    if (kDebugMode) debugPrint('[BLE] [HryFine] $message');
  }

  ble.QualifiedCharacteristic _characteristic(String deviceId, String uuid) =>
      ble.QualifiedCharacteristic(
        serviceId: ble.Uuid.parse(HryFineUuids.uartService),
        characteristicId: ble.Uuid.parse(uuid),
        deviceId: deviceId,
      );

  /// Runs the full sequence against an already-connected watch and returns
  /// the decoded health history. Throws [StateError] when the device does
  /// not expose the HryFine UART service or refuses binding.
  Future<HryFineHealthData> syncHealth(
    String deviceId, {
    required String userId,
  }) async {
    if (userId.length != 8) {
      throw ArgumentError('The HryFine user id must be 8 characters');
    }
    await _ensureUartService(deviceId);
    _resetSyncState();
    _subscription = _ble
        .subscribeToCharacteristic(
          _characteristic(deviceId, HryFineUuids.uartNotify),
        )
        .listen(
          (chunk) => _onNotification(deviceId, chunk),
          onError: (Object error) => _log('Notification error: $error'),
        );
    try {
      await _verificationHandshake(deviceId, userId);
      await _bind(deviceId, userId);
      await _syncTime(deviceId);
      await _syncAllHealth(deviceId);
      return HryFineHealthData(
        stepDays: _stepDays.values.toList(),
        heartRateSamples: List.unmodifiable(_heartRate),
        bloodPressureSamples: List.unmodifiable(_bloodPressure),
        sleepNights: _sleepNights.values.toList(),
        temperatureSamples: List.unmodifiable(_temperature),
        bloodOxygenSamples: List.unmodifiable(_bloodOxygen),
        todaySteps: _todaySteps,
      );
    } finally {
      await _subscription?.cancel();
      _subscription = null;
    }
  }

  Future<void> _ensureUartService(String deviceId) async {
    var services = await _ble.getDiscoveredServices(deviceId);
    if (services.isEmpty) {
      await _ble.discoverAllServices(deviceId);
      services = await _ble.getDiscoveredServices(deviceId);
    }
    final uart = ble.Uuid.parse(HryFineUuids.uartService).toString();
    final found = services.any(
      (service) => service.id.toString().toLowerCase() == uart,
    );
    if (!found) {
      throw StateError(
        'This device does not expose the HryFine data service, so its '
        'health data cannot be read.',
      );
    }
  }

  void _resetSyncState() {
    _reassembler.reset();
    _stepDays.clear();
    _heartRate.clear();
    _bloodPressure.clear();
    _sleepNights.clear();
    _temperature.clear();
    _bloodOxygen.clear();
    _todaySteps = null;
    _syncFinished = false;
    _lastHealthFrameAt = null;
    _verificationReplyByte = null;
    _lastAck = null;
    _bindResponse = null;
  }

  // ---------------------------------------------------------------------
  // Notification dispatch
  // ---------------------------------------------------------------------

  void _onNotification(String deviceId, List<int> chunk) {
    for (final raw in _reassembler.feed(chunk)) {
      final parsed = parseHryFineFrame(raw);
      if (parsed is HryFineAck) {
        _lastAck = parsed;
        continue;
      }
      if (parsed is! HryFineFrame) continue;
      // The official app ACKs every complete, checksum-valid data frame.
      unawaited(
        _enqueueWrite(
          deviceId,
          buildHryFineAck(parsed.command, parsed.subCommand),
        ),
      );
      _dispatchFrame(parsed);
    }
  }

  void _dispatchFrame(HryFineFrame frame) {
    if (frame.command == HryFineCommands.firmwareQuery) {
      // The verification reply carries the code at frame offset 10,
      // which is payload index 1.
      if (frame.raw.length > 10) _verificationReplyByte = frame.raw[10];
      return;
    }
    if (frame.command == HryFineCommands.bind) {
      _bindResponse = frame;
      return;
    }
    if (frame.command != HryFineCommands.health) return;
    _lastHealthFrameAt = DateTime.now();
    switch (frame.subCommand) {
      case HryFineHealthSubs.hourlySteps:
        final day = parseHryFineHourlySteps(frame.payload);
        if (day != null) _stepDays[day.date.toString()] = day;
      case HryFineHealthSubs.heartRateHistory:
        _heartRate.addAll(parseHryFineHeartRateHistory(frame.payload));
      case HryFineHealthSubs.bloodPressureHistory:
        _bloodPressure.addAll(
          parseHryFineBloodPressureHistory(frame.payload),
        );
      case HryFineHealthSubs.sleepTotals:
        final night = parseHryFineSleepTotals(frame.payload);
        if (night != null) _sleepNights[night.date.toString()] = night;
      case HryFineHealthSubs.todayTotalSteps:
        _todaySteps = parseHryFineTodaySteps(frame.payload);
      case HryFineHealthSubs.temperatureHistory:
        _temperature.addAll(parseHryFineTemperatureHistory(frame.payload));
      case HryFineHealthSubs.bloodOxygen:
        final sample = parseHryFineBloodOxygen(frame.payload);
        if (sample != null) _bloodOxygen.add(sample);
      case HryFineHealthSubs.syncFinished:
        _syncFinished = true;
    }
  }

  // ---------------------------------------------------------------------
  // Writes — strictly serial, chunked at 20 bytes like the official app.
  // ---------------------------------------------------------------------

  Future<void> _enqueueWrite(String deviceId, Uint8List frame) {
    final task = _writeChain.then((_) async {
      final characteristic = _characteristic(deviceId, HryFineUuids.uartWrite);
      for (final chunk in chunkHryFineFrame(
        frame,
        HryFineProtocolConfig.chunkSize,
      )) {
        await _ble.writeCharacteristicWithoutResponse(
          characteristic,
          value: chunk,
        );
        await Future<void>.delayed(HryFineProtocolConfig.chunkGap);
      }
    });
    _writeChain = task.catchError((Object _) {});
    return task;
  }

  Future<void> _sendCommand(
    String deviceId,
    int command,
    int subCommand, [
    List<int>? payload,
  ]) => _enqueueWrite(deviceId, buildHryFineFrame(command, subCommand, payload));

  /// Polls [condition] every 50 ms until it holds or [timeout] elapses.
  Future<bool> _waitFor(bool Function() condition, Duration timeout) async {
    final stopwatch = Stopwatch()..start();
    while (stopwatch.elapsed < timeout) {
      if (condition()) return true;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    return condition();
  }

  // ---------------------------------------------------------------------
  // Connection sequence
  // ---------------------------------------------------------------------

  Future<void> _verificationHandshake(String deviceId, String userId) async {
    final payload = ascii.encode(userId);
    final expectedCode = hryFineVerificationCode(payload);
    await _sendCommand(
      deviceId,
      HryFineCommands.firmwareQuery,
      0x00,
      payload,
    );
    final answered = await _waitFor(
      () => _verificationReplyByte != null,
      HryFineProtocolConfig.responseTimeout,
    );
    if (!answered) {
      // TODO(hardware): Whether the H9 Max firmware requires this
      // handshake before other commands, or merely supports it, can only
      // be confirmed on the real unit (PROTOCOL.md section 9). The
      // official app always performs it, so it is attempted here, but a
      // silent watch is not treated as fatal.
      _log('Verification handshake unanswered; continuing.');
      return;
    }
    if (_verificationReplyByte != expectedCode) {
      throw StateError('The watch failed the HryFine verification handshake.');
    }
    await _sendCommand(deviceId, HryFineCommands.verificationConfirm, 0x00, [
      0x00,
    ]);
  }

  Future<void> _bind(String deviceId, String userId) async {
    _lastAck = null;
    _bindResponse = null;
    await _sendCommand(deviceId, HryFineCommands.bind, 0x00, ascii.encode(userId));
    final answered = await _waitFor(
      () =>
          _bindResponse != null ||
          (_lastAck?.command == HryFineCommands.bind && _lastAck != null),
      HryFineProtocolConfig.responseTimeout,
    );
    final response = _bindResponse;
    if (response != null &&
        response.payload.isNotEmpty &&
        response.payload[0] == 0) {
      // A bind response payload byte of 0 means the watch refused.
      throw StateError(
        'The watch refused binding. Unbind it from any previous phone app '
        'and try again.',
      );
    }
    final ack = _lastAck;
    if (ack != null && ack.command == HryFineCommands.bind && !ack.success) {
      throw StateError('The watch refused the bind command.');
    }
    if (!answered) {
      // As with the handshake, some firmwares answer bind only implicitly;
      // the health sync below is the real proof and will fail loudly if
      // the watch is not bound.
      _log('Bind unanswered; continuing to health sync.');
    }
  }

  Future<void> _syncTime(String deviceId) async {
    _lastAck = null;
    await _sendCommand(
      deviceId,
      HryFineCommands.settings,
      0x01,
      packHryFineDateTime(DateTime.now()),
    );
    await _waitFor(
      () =>
          _lastAck?.command == HryFineCommands.settings &&
          _lastAck?.subCommand == 0x01,
      HryFineProtocolConfig.responseTimeout,
    );
  }

  Future<void> _syncAllHealth(String deviceId) async {
    _syncFinished = false;
    _lastHealthFrameAt = DateTime.now();
    await _sendCommand(
      deviceId,
      HryFineCommands.health,
      HryFineHealthSubs.syncAllHistory,
    );
    final stopwatch = Stopwatch()..start();
    while (!_syncFinished &&
        stopwatch.elapsed < HryFineProtocolConfig.syncOverallTimeout) {
      final lastFrame = _lastHealthFrameAt;
      if (lastFrame != null &&
          DateTime.now().difference(lastFrame) >
              HryFineProtocolConfig.responseTimeout * 3) {
        // The watch stopped sending without a finished marker; keep
        // whatever history arrived instead of hanging.
        _log('Health sync went quiet; finishing with collected data.');
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (!_syncFinished) {
      _log('Health sync ended without the finished marker.');
    }
    // After history, the official app enables the real-time step switch.
    await _sendCommand(
      deviceId,
      HryFineCommands.health,
      HryFineHealthSubs.realtimeStepSwitch,
      [0x01],
    );
  }
}
