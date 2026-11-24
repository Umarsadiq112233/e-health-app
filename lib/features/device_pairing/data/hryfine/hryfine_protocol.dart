import 'dart:typed_data';

/// HryFine BLE protocol — pure packet layer.
///
/// Reverse-engineered from the official HryFine Android app (v3.8.26) and
/// documented in `~/workspace/hryfine-apk/PROTOCOL.md`. This file has no
/// Flutter or BLE imports: it only builds, parses and validates the frames
/// that travel over the Nordic UART characteristic pair, and decodes the
/// health payloads of command group 0x05. Transport lives in
/// `hryfine_client.dart`.
///
/// Frame layout (data frames, header 0xDF):
///   byte 0    : 0xDF
///   byte 1–2  : length, big-endian = payloadLength + 5
///   byte 3    : checksum — 8-bit sum of every other byte of the frame
///   byte 4    : command group
///   byte 5    : protocol version (0x01)
///   byte 6    : sub-command
///   byte 7–8  : payload length, big-endian
///   byte 9…   : payload
/// Total on-wire size = payloadLength + 9.
abstract final class HryFineUuids {
  static const String uartService = '6E400001-B5A3-F393-E0A9-E50E24DCCA9F';

  /// App → watch writes.
  static const String uartWrite = '6E400002-B5A3-F393-E0A9-E50E24DCCA9F';

  /// Watch → app notifications.
  static const String uartNotify = '6E400003-B5A3-F393-E0A9-E50E24DCCA9F';

  static const String batteryService = '0000180F-0000-1000-8000-00805F9B34FB';
  static const String batteryLevel = '00002A19-0000-1000-8000-00805F9B34FB';
}

abstract final class HryFineCommands {
  static const int settings = 0x02;
  static const int bind = 0x03;
  static const int unbind = 0x04;
  static const int health = 0x05;
  static const int requestSettings = 0x09;
  static const int requestFeatures = 0x19;
  static const int firmwareQuery = 0xF0;
  static const int verificationConfirm = 0xF1;
  static const int deviceInfo = 0xF3;
}

abstract final class HryFineHealthSubs {
  static const int syncAllHistory = 0x01;
  static const int hourlySteps = 0x02;
  static const int heartRateHistory = 0x04;
  static const int bloodPressureHistory = 0x05;
  static const int realtimeStepSwitch = 0x06;
  static const int syncStarted = 0x07;
  static const int syncFinished = 0x08;
  static const int sleepTotals = 0x09;
  static const int syncTodayHistory = 0x0A;
  static const int todayTotalSteps = 0x0C;
  static const int temperatureHistory = 0x0D;
  static const int bloodOxygen = 0x0E;
}

/// Values that could not be fully resolved from the decompiled app and must
/// be confirmed on a real H9 Max (see PROTOCOL.md section 9). They are kept
/// together here so hardware testing can tune them in one place.
abstract final class HryFineProtocolConfig {
  /// TODO(hardware): The official app disconnects when a response is late,
  /// but its exact timeout constant could not be read reliably from the
  /// decompiled code. PROTOCOL.md suggests starting at ~2 s and tuning on
  /// the real watch.
  static const Duration responseTimeout = Duration(seconds: 2);

  /// Overall cap for one full health-history sync, so a watch that never
  /// sends the sync-finished marker cannot hang the sync forever.
  static const Duration syncOverallTimeout = Duration(seconds: 45);

  /// The official app requests a small MTU and writes frames in 20-byte
  /// chunks with ~20 ms gaps. Mirror that here.
  static const int chunkSize = 20;
  static const Duration chunkGap = Duration(milliseconds: 20);

  /// TODO(hardware): Packed dates store the year in 7 bits. The decompiled
  /// date decoder adds 2000 back when formatting, so the year is stored as
  /// year − 2000. One HCI capture should confirm this offset.
  static const int yearBase = 2000;
}

const int _dataHeader = 0xDF;
const int _ackHeader = 0xFD;
const int _protocolVersion = 0x01;

/// One decoded 0xDF data frame.
class HryFineFrame {
  final int command;
  final int subCommand;
  final Uint8List payload;

  /// The complete on-wire frame, checksum included.
  final Uint8List raw;
  const HryFineFrame({
    required this.command,
    required this.subCommand,
    required this.payload,
    required this.raw,
  });
}

/// One decoded 0xFD acknowledgement frame.
class HryFineAck {
  final int command;
  final int subCommand;
  final bool success;
  const HryFineAck({
    required this.command,
    required this.subCommand,
    required this.success,
  });
}

int _checksumOf(List<int> bytes) {
  var sum = 0;
  for (final byte in bytes) {
    sum = (sum + (byte & 0xFF)) & 0xFF;
  }
  return sum;
}

/// Builds a complete 0xDF data frame, checksum inserted at byte 3.
///
/// The official app builds the frame without a checksum and then inserts
/// the 8-bit sum of all those bytes at index 3; this reproduces that
/// exactly.
Uint8List buildHryFineFrame(int command, int subCommand, [List<int>? payload]) {
  final body = payload ?? const <int>[];
  final length = body.length + 5;
  final raw = Uint8List(body.length + 8);
  raw[0] = _dataHeader;
  raw[1] = (length >> 8) & 0xFF;
  raw[2] = length & 0xFF;
  raw[3] = command & 0xFF;
  raw[4] = _protocolVersion;
  raw[5] = subCommand & 0xFF;
  raw[6] = (body.length >> 8) & 0xFF;
  raw[7] = body.length & 0xFF;
  raw.setRange(8, 8 + body.length, body);
  final checksum = _checksumOf(raw);
  final frame = Uint8List(raw.length + 1);
  frame.setRange(0, 3, raw);
  frame[3] = checksum;
  frame.setRange(4, frame.length, raw.sublist(3));
  return frame;
}

/// Builds the fixed 9-byte 0xFD ACK the app sends after a valid 0xDF frame.
Uint8List buildHryFineAck(int command, int subCommand, {bool success = true}) {
  final frame = Uint8List(9);
  frame[0] = _ackHeader;
  frame[1] = 0x00;
  frame[2] = 0x05;
  frame[4] = command & 0xFF;
  frame[5] = subCommand & 0xFF;
  frame[6] = 0x00;
  frame[7] = 0x00;
  frame[8] = success ? 1 : 0;
  frame[3] = _checksumOf(frame);
  return frame;
}

bool _hasValidChecksum(Uint8List frame) {
  if (frame.length < 4) return false;
  var sum = 0;
  for (var i = 0; i < frame.length; i++) {
    if (i == 3) continue;
    sum = (sum + frame[i]) & 0xFF;
  }
  return sum == frame[3];
}

/// Parses one complete frame. Returns a [HryFineFrame] for 0xDF frames, a
/// [HryFineAck] for 0xFD frames, and null for anything malformed or with a
/// bad checksum.
Object? parseHryFineFrame(Uint8List frame) {
  if (frame.isEmpty) return null;
  if (frame[0] == _ackHeader) {
    if (frame.length != 9 || !_hasValidChecksum(frame)) return null;
    return HryFineAck(
      command: frame[4],
      subCommand: frame[5],
      success: frame[8] == 1,
    );
  }
  if (frame[0] != _dataHeader || frame.length < 9) return null;
  if (!_hasValidChecksum(frame)) return null;
  final lengthField = (frame[1] << 8) | frame[2];
  if (frame.length != lengthField + 4) return null;
  final payloadLength = (frame[7] << 8) | frame[8];
  if (payloadLength != frame.length - 9) return null;
  return HryFineFrame(
    command: frame[4],
    subCommand: frame[6],
    payload: Uint8List.sublistView(frame, 9),
    raw: frame,
  );
}

/// Reassembles complete frames from the ≤20-byte notification chunks the
/// watch sends. Feed every notification; take the completed raw frames out.
class HryFineFrameReassembler {
  final _buffer = <int>[];

  List<Uint8List> feed(List<int> chunk) {
    _buffer.addAll(chunk);
    final frames = <Uint8List>[];
    while (true) {
      final frame = _tryExtract();
      if (frame == null) break;
      frames.add(frame);
    }
    return frames;
  }

  Uint8List? _tryExtract() {
    if (_buffer.isEmpty) return null;
    final header = _buffer[0];
    if (header == _ackHeader) {
      if (_buffer.length < 9) return null;
      final frame = Uint8List.fromList(_buffer.sublist(0, 9));
      _buffer.removeRange(0, 9);
      return frame;
    }
    if (header != _dataHeader) {
      // Unknown byte: drop it and resynchronise on the next header.
      _buffer.removeAt(0);
      return _tryExtract();
    }
    if (_buffer.length < 3) return null;
    final total = (((_buffer[1] << 8) | _buffer[2]) + 4);
    if (total < 9 || total > 4096) {
      _buffer.removeAt(0);
      return _tryExtract();
    }
    if (_buffer.length < total) return null;
    final frame = Uint8List.fromList(_buffer.sublist(0, total));
    _buffer.removeRange(0, total);
    return frame;
  }

  void reset() => _buffer.clear();
}

/// Splits an outgoing frame into the 20-byte writes the watch expects.
List<Uint8List> chunkHryFineFrame(Uint8List frame, [int chunkSize = 20]) {
  final chunks = <Uint8List>[];
  for (var start = 0; start < frame.length; start += chunkSize) {
    final end = start + chunkSize > frame.length ? frame.length : start + chunkSize;
    chunks.add(Uint8List.sublistView(frame, start, end));
  }
  return chunks;
}

/// The verification code for the 0xF0 handshake: sum of (byte XOR 0xFF)
/// over the 8 payload bytes, kept to 8 bits.
int hryFineVerificationCode(List<int> payload) {
  var code = 0;
  for (final byte in payload) {
    code = (code + ((byte & 0xFF) ^ 0xFF)) & 0xFF;
  }
  return code;
}

/// A calendar date decoded from the 2-byte packed format used at the start
/// of health payloads: [year−2000 : 7][month : 4][day : 5], big-endian.
class HryFineDate {
  final int year;
  final int month;
  final int day;
  const HryFineDate(this.year, this.month, this.day);

  DateTime toDateTime() => DateTime(year, month, day);

  @override
  String toString() => '$year-$month-$day';
}

HryFineDate decodeHryFineDate(int byte0, int byte1) {
  final year = ((byte0 & 0x7F) >> 1) + HryFineProtocolConfig.yearBase;
  final month = ((byte0 & 0x01) << 3) | ((byte1 & 0xE0) >> 5);
  final day = byte1 & 0x1F;
  return HryFineDate(year, month, day);
}

/// Packs a date/time into the 4-byte format the settings group uses for
/// the system-time sync (0x02, sub 0x01). See the year-offset TODO on
/// [HryFineProtocolConfig.yearBase].
Uint8List packHryFineDateTime(DateTime time) {
  final yearOffset = time.year - HryFineProtocolConfig.yearBase;
  final bytes = Uint8List(4);
  bytes[0] = ((yearOffset << 2) | (time.month >> 2)) & 0xFF;
  bytes[1] = (((time.month & 0x03) << 6) | (time.day << 1) | (time.hour >> 4)) & 0xFF;
  bytes[2] = (((time.hour & 0x0F) << 4) | (time.minute >> 2)) & 0xFF;
  bytes[3] = (((time.minute & 0x03) << 6) | time.second) & 0xFF;
  return bytes;
}

int _u16be(List<int> bytes, int offset) =>
    ((bytes[offset] & 0xFF) << 8) | (bytes[offset + 1] & 0xFF);

int _u32be(List<int> bytes, int offset) =>
    ((bytes[offset] & 0xFF) << 24) |
    ((bytes[offset + 1] & 0xFF) << 16) |
    ((bytes[offset + 2] & 0xFF) << 8) |
    (bytes[offset + 3] & 0xFF);

/// One day of step data from the hourly-steps payload (sub 0x02).
class HryFineStepDay {
  final HryFineDate date;

  /// Steps per hour, 24 entries; -1 marks an hour with no data.
  final List<int> hourlySteps;
  final int distanceMeters;
  final int calories;
  const HryFineStepDay({
    required this.date,
    required this.hourlySteps,
    required this.distanceMeters,
    required this.calories,
  });

  int get totalSteps =>
      hourlySteps.where((steps) => steps > 0).fold(0, (a, b) => a + b);
}

/// Parses sub 0x02: [date:2][24 × record:8] where each record is steps
/// u16 BE, distance u16 BE, calories u32 BE, and 0xFFFF steps = no data.
/// The official app clamps any single record above 20000 to 20000.
HryFineStepDay? parseHryFineHourlySteps(Uint8List payload) {
  if (payload.length < 2 + 24 * 8) return null;
  final date = decodeHryFineDate(payload[0], payload[1]);
  final hourly = <int>[];
  var distance = 0;
  var calories = 0;
  for (var hour = 0; hour < 24; hour++) {
    final offset = 2 + hour * 8;
    final steps = _u16be(payload, offset);
    if (steps == 0xFFFF) {
      hourly.add(-1);
      continue;
    }
    hourly.add(steps > 20000 ? 20000 : steps);
    final hourDistance = _u16be(payload, offset + 2);
    distance += hourDistance > 20000 ? 20000 : hourDistance;
    calories += _u32be(payload, offset + 4);
  }
  return HryFineStepDay(
    date: date,
    hourlySteps: hourly,
    distanceMeters: distance,
    calories: calories,
  );
}

/// Today's totals from sub 0x0C: steps u32 BE, distance u32 BE,
/// calories u32 BE.
class HryFineTodaySteps {
  final int steps;
  final int distanceMeters;
  final int calories;
  const HryFineTodaySteps({
    required this.steps,
    required this.distanceMeters,
    required this.calories,
  });
}

HryFineTodaySteps? parseHryFineTodaySteps(Uint8List payload) {
  if (payload.length < 12) return null;
  final steps = _u32be(payload, 0);
  final distance = _u32be(payload, 4);
  final calories = _u32be(payload, 8);
  if (steps > 240000 || distance > 192000 || calories > 4464000) {
    // The official app discards out-of-range totals.
    return const HryFineTodaySteps(steps: 0, distanceMeters: 0, calories: 0);
  }
  return HryFineTodaySteps(
    steps: steps,
    distanceMeters: distance,
    calories: calories,
  );
}

/// One heart-rate sample. [type] is the watch's own measurement-type byte.
class HryFineHeartRateSample {
  final DateTime timestamp;
  final int bpm;
  final int type;
  const HryFineHeartRateSample({
    required this.timestamp,
    required this.bpm,
    required this.type,
  });
}

/// Parses sub 0x04: [date:2][?:1][count:1][count × record:8]. Each record
/// is seconds-since-midnight u32 BE, a type byte, two unresolved bytes,
/// and the HR value in the last byte. The official app keeps 40–160 bpm.
///
/// TODO(hardware): Record bytes 5–6 are not fully resolved in the
/// decompiled parser (PROTOCOL.md section 9); they are skipped here and
/// must be confirmed from an HCI capture before they are used.
List<HryFineHeartRateSample> parseHryFineHeartRateHistory(Uint8List payload) {
  if (payload.length < 4) return const [];
  final date = decodeHryFineDate(payload[0], payload[1]).toDateTime();
  final count = payload[3];
  final samples = <HryFineHeartRateSample>[];
  for (var i = 0; i < count; i++) {
    final offset = 4 + i * 8;
    if (offset + 8 > payload.length) break;
    final seconds = _u32be(payload, offset);
    final bpm = payload[offset + 7];
    if (bpm < 40 || bpm > 160) continue;
    samples.add(
      HryFineHeartRateSample(
        timestamp: date.add(Duration(seconds: seconds)),
        bpm: bpm,
        type: payload[offset + 4],
      ),
    );
  }
  return samples;
}

class HryFineBloodPressureSample {
  final DateTime timestamp;
  final int systolic;
  final int diastolic;
  const HryFineBloodPressureSample({
    required this.timestamp,
    required this.systolic,
    required this.diastolic,
  });
}

/// Parses sub 0x05: same envelope as heart rate; each record is
/// seconds-since-midnight u32 BE, two unresolved bytes, systolic in record
/// byte 6 and diastolic in record byte 7. The official app keeps systolic
/// 50–300 and diastolic 30–200.
List<HryFineBloodPressureSample> parseHryFineBloodPressureHistory(
  Uint8List payload,
) {
  if (payload.length < 4) return const [];
  final date = decodeHryFineDate(payload[0], payload[1]).toDateTime();
  final count = payload[3];
  final samples = <HryFineBloodPressureSample>[];
  for (var i = 0; i < count; i++) {
    final offset = 4 + i * 8;
    if (offset + 8 > payload.length) break;
    final systolic = payload[offset + 6];
    final diastolic = payload[offset + 7];
    if (systolic < 50 || systolic > 300 || diastolic < 30 || diastolic > 200) {
      continue;
    }
    samples.add(
      HryFineBloodPressureSample(
        timestamp: date.add(Duration(seconds: _u32be(payload, offset))),
        systolic: systolic,
        diastolic: diastolic,
      ),
    );
  }
  return samples;
}

/// One night of sleep totals from sub 0x09. All durations are minutes;
/// start/end are minute offsets within the day, as the watch reports them.
class HryFineSleepTotals {
  final HryFineDate date;
  final int startOffsetMinutes;
  final int endOffsetMinutes;
  final int lightMinutes;
  final int deepMinutes;
  final int awakeMinutes;
  const HryFineSleepTotals({
    required this.date,
    required this.startOffsetMinutes,
    required this.endOffsetMinutes,
    required this.lightMinutes,
    required this.deepMinutes,
    required this.awakeMinutes,
  });

  int get totalSleepMinutes => lightMinutes + deepMinutes;
}

/// Parses sub 0x09: [date:2][start u16][light u16][deep u16][end u16]
/// [awake u16]. The official app discards the night when any duration is
/// above 1439 minutes.
HryFineSleepTotals? parseHryFineSleepTotals(Uint8List payload) {
  if (payload.length < 12) return null;
  var light = _u16be(payload, 4);
  var deep = _u16be(payload, 6);
  var awake = _u16be(payload, 10);
  if (light > 1439 || deep > 1439 || awake > 1439) {
    light = 0;
    deep = 0;
    awake = 0;
  }
  return HryFineSleepTotals(
    date: decodeHryFineDate(payload[0], payload[1]),
    startOffsetMinutes: _u16be(payload, 2),
    endOffsetMinutes: _u16be(payload, 8),
    lightMinutes: light,
    deepMinutes: deep,
    awakeMinutes: awake,
  );
}

class HryFineTemperatureSample {
  final DateTime timestamp;
  final double celsius;
  final int type;
  const HryFineTemperatureSample({
    required this.timestamp,
    required this.celsius,
    required this.type,
  });
}

/// Parses sub 0x0D: same envelope as heart rate; the value is
/// record byte 6 + record byte 7 / 10, in °C. The official app keeps
/// 30–50 °C.
List<HryFineTemperatureSample> parseHryFineTemperatureHistory(
  Uint8List payload,
) {
  if (payload.length < 4) return const [];
  final date = decodeHryFineDate(payload[0], payload[1]).toDateTime();
  final count = payload[3];
  final samples = <HryFineTemperatureSample>[];
  for (var i = 0; i < count; i++) {
    final offset = 4 + i * 8;
    if (offset + 8 > payload.length) break;
    final celsius = payload[offset + 6] + payload[offset + 7] / 10.0;
    if (celsius < 30 || celsius > 50) continue;
    samples.add(
      HryFineTemperatureSample(
        timestamp: date.add(Duration(seconds: _u32be(payload, offset))),
        celsius: celsius,
        type: payload[offset + 4],
      ),
    );
  }
  return samples;
}

class HryFineBloodOxygenSample {
  final DateTime timestamp;
  final int percent;
  const HryFineBloodOxygenSample({
    required this.timestamp,
    required this.percent,
  });
}

/// Parses sub 0x0E (a single reading): [date:2][?:2][seconds-of-day u32
/// at payload 4–7][…][SpO2 % at payload 11].
HryFineBloodOxygenSample? parseHryFineBloodOxygen(Uint8List payload) {
  if (payload.length < 12) return null;
  final date = decodeHryFineDate(payload[0], payload[1]).toDateTime();
  final percent = payload[11];
  if (percent <= 0 || percent > 100) return null;
  return HryFineBloodOxygenSample(
    timestamp: date.add(Duration(seconds: _u32be(payload, 4))),
    percent: percent,
  );
}
