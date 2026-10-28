import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/widgets/beam_ui.dart';
import '../../../auth/presentation/widgets/auth_widgets.dart';
import '../../../onboarding/presentation/cubit/app_flow_cubit.dart';

class SetupCompletePage extends StatefulWidget {
  const SetupCompletePage({super.key});
  @override
  State<SetupCompletePage> createState() => _SetupCompleteState();
}

class _SetupCompleteState extends State<SetupCompletePage> {
  bool saving = false;
  String? error;
  Future<void> proceed(bool connect) async {
    if (saving) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final flow = context.read<AppFlowCubit>();
      if (connect) {
        await flow.finishSetupReview();
      } else {
        await flow.finishDevice();
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not continue. Please try again.');
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final setup = context.watch<AppFlowCubit>().state.setup;
    final wellness = setup.wellness;
    final enabled = setup.permissions.entries
        .where((entry) => entry.value && entry.key != 'healthRequested')
        .map((entry) => entry.key)
        .join(' · ');
    final rows = [
      (
        'person',
        'Profile Information',
        '${setup.name}${wellness['birthday'] == null ? '' : ' · ${wellness['birthday'].toString().split('T').first}'}',
      ),
      (
        'ruler',
        'Measurement Units',
        wellness['units'] == 'imperial'
            ? 'Imperial (lb, ft)'
            : 'Metric (kg, cm)',
      ),
      (
        'target',
        'Daily Goals',
        '${wellness['steps'] ?? 8000} steps · ${wellness['sleepHours'] ?? 7.5}h sleep · ${wellness['activeMinutes'] ?? 60} min',
      ),
      (
        'heart',
        'Wellness Preferences',
        (wellness['preferences'] as List?)?.join(' · ') ?? 'None selected',
      ),
      (
        'shield',
        'Permissions & Privacy',
        enabled.isEmpty ? 'Optional permissions skipped' : enabled,
      ),
    ];
    return Theme(
      data: beamTheme(context),
      child: Scaffold(
        backgroundColor: beamNavy,
        body: SafeArea(
          child: AuthSurface(
            transparent: true,
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 14),
            child: Column(
              children: [
                const BeamLogo(width: 110, horizontal: true),
                const BeamReveal(
                  art: true,
                  child: SizedBox(
                    width: 200,
                    height: 82,
                    child: CustomPaint(painter: _SetupSuccessPainter()),
                  ),
                ),
                const Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: 'You’re '),
                      TextSpan(
                        text: 'All Set!',
                        style: TextStyle(color: beamCyan),
                      ),
                    ],
                  ),
                  style: TextStyle(fontSize: 27, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your wellness profile is ready.',
                  style: TextStyle(color: beamMuted, fontSize: 12),
                ),
                LayoutBuilder(
                  builder: (context, box) => SizedBox(
                    width: box.maxWidth,
                    height: box.maxWidth * 1086 / 1448 - 34,
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.topCenter,
                        minHeight: 0,
                        maxHeight: double.infinity,
                        child: BeamReveal(
                          art: true,
                          child: Image.asset(
                            BeamAssets.setupBackground,
                            width: box.maxWidth,
                            fit: BoxFit.fitWidth,
                            filterQuality: FilterQuality.high,
                            semanticLabel:
                                'E Health Pulse smartwatch beside the E Health app',
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF002A3E), Color(0xFF001726)],
                      ),
                      border: Border.all(color: beamBorder),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your Setup Summary',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (final row in rows)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF004258),
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: BeamIcon(row.$1, size: 20),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        row.$2,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        row.$3.isEmpty
                                            ? 'None selected'
                                            : row.$3,
                                        style: const TextStyle(
                                          color: beamMuted,
                                          fontSize: 10,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: beamCyan,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.all(3),
                                    child: Icon(
                                      Icons.check,
                                      size: 11,
                                      color: beamNavy,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Column(
                    children: [
                      if (error != null)
                        Text(
                          error!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      BeamButton(
                        saving ? 'Saving…' : 'Connect E Health Pulse',
                        arrow: true,
                        onPressed: saving ? null : () => proceed(true),
                      ),
                      const SizedBox(height: 10),
                      BeamButton(
                        'Continue to Dashboard',
                        secondary: true,
                        arrow: true,
                        onPressed: saving ? null : () => proceed(false),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SetupSuccessPainter extends CustomPainter {
  const _SetupSuccessPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final ring = Paint()
      ..color = beamCyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(
      center,
      28,
      Paint()
        ..color = beamCyan.withValues(alpha: .35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(center, 28, Paint()..color = const Color(0xFF004D60));
    canvas.drawCircle(center, 28, ring);
    canvas.drawPath(
      Path()
        ..moveTo(center.dx - 11, center.dy)
        ..lineTo(center.dx - 2, center.dy + 9)
        ..lineTo(center.dx + 13, center.dy - 8),
      Paint()
        ..color = const Color(0xFFC6FFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    for (final point in const [
      Offset(-68, -12),
      Offset(-54, 15),
      Offset(-60, -29),
      Offset(-40, -19),
      Offset(65, -21),
      Offset(55, 8),
      Offset(42, -30),
      Offset(73, 1),
    ]) {
      canvas.save();
      canvas.translate(center.dx + point.dx, center.dy + point.dy);
      canvas.rotate(point.dx / 22);
      canvas.drawRect(
        const Rect.fromLTWH(-3, -1.5, 6, 3),
        Paint()
          ..color = point.dx.abs() > 60 ? const Color(0xFFE9D88C) : beamCyan,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_SetupSuccessPainter oldDelegate) => false;
}
