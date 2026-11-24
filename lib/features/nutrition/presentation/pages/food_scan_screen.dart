import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../shared/widgets/beam_ui.dart';
import '../../../ai_coach/presentation/pages/ai_coach_screen.dart';
import '../../data/food_analysis_service.dart';
import '../../data/food_scan_history_store.dart';
import '../widgets/food_camera_screen.dart';

class FoodScanScreen extends StatefulWidget {
  const FoodScanScreen({super.key, this.service});

  final FoodAnalysisService? service;

  @override
  State<FoodScanScreen> createState() => _FoodScanScreenState();
}

class _FoodScanScreenState extends State<FoodScanScreen> {
  late final FoodAnalysisService _service =
      widget.service ?? FoodAnalysisService();
  final FoodScanHistoryStore _historyStore = FoodScanHistoryStore();
  Uint8List? _imageBytes;
  FoodAnalysisResult? _result;
  List<FoodScanHistoryEntry> _history = const [];
  String? _error;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final history = await _historyStore.load();
      if (mounted) setState(() => _history = history);
    } on Exception {
      // History should never prevent the camera and live analysis from working.
    }
  }

  @override
  void dispose() {
    if (widget.service == null) _service.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    if (_isScanning) return;
    setState(() => _error = null);
    try {
      final bytes = await Navigator.of(context, rootNavigator: true)
          .push<Uint8List>(
            MaterialPageRoute<Uint8List>(
              builder: (_) => const FoodCameraScreen(),
              fullscreenDialog: true,
            ),
          );
      if (bytes == null || !mounted) return;
      setState(() {
        _imageBytes = bytes;
        _result = null;
      });
      await _scan(bytes);
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _error = _cameraMessage(error));
    }
  }

  Future<void> _scan(Uint8List bytes) async {
    setState(() {
      _isScanning = true;
      _error = null;
    });
    try {
      final result = await _service.analyze(bytes);
      if (mounted) setState(() => _result = result);

      // Persist the completed nutrition result independently from the current
      // screen, so it remains available after navigation or app restart.
      try {
        final savedEntry = await _historyStore.add(result);
        if (mounted) {
          setState(() => _history = [savedEntry, ..._history]);
        }
      } on Exception {
        // A storage issue must not hide a successful analysis from the user.
      }
    } on FoodAnalysisException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Exception catch (error) {
      if (mounted) setState(() => _error = 'Could not scan this photo: $error');
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  String _cameraMessage(Exception error) {
    final message = error.toString().toLowerCase();
    if (message.contains('permission') || message.contains('denied')) {
      return 'Camera permission is required to scan food. Enable it in Settings and try again.';
    }
    return 'Could not open the camera. Please check camera permission and try again.';
  }

  Future<void> _showScanHistory() async {
    await _loadHistory();
    if (!mounted) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: beamNavy,
      showDragHandle: true,
      isScrollControlled: true,
      builder: _buildHistorySheet,
    );
  }

  Widget _buildHistorySheet(BuildContext context) => SafeArea(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .78,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Scan history',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  '${_history.length} saved',
                  style: const TextStyle(color: beamMuted, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 5),
            const Text(
              'Your analyzed meals are saved securely on this device.',
              style: TextStyle(color: beamMuted, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _history.isEmpty
                  ? _buildEmptyHistory(context)
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 4),
                      itemCount: _history.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, index) =>
                          _buildHistoryEntry(_history[index], context),
                    ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildEmptyHistory(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: beamCyan.withValues(alpha: .1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.history_rounded, color: beamCyan, size: 28),
          ),
          const SizedBox(height: 12),
          const Text(
            'No scans yet',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          const Text(
            'Complete your first food scan and it will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: beamMuted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _takePhoto();
            },
            icon: const Icon(Icons.camera_alt_rounded),
            label: const Text('Scan a meal'),
          ),
        ],
      ),
    ),
  );

  Widget _buildHistoryEntry(
    FoodScanHistoryEntry entry,
    BuildContext context,
  ) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFF032235),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: beamBorder),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: beamCyan.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.restaurant_rounded, color: beamCyan),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.mealName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${MaterialLocalizations.of(context).formatShortDate(entry.scannedAt.toLocal())} · ${TimeOfDay.fromDateTime(entry.scannedAt.toLocal()).format(context)}',
                style: const TextStyle(color: beamMuted, fontSize: 11),
              ),
              const SizedBox(height: 8),
              Text(
                'P ${entry.protein.toStringAsFixed(1)}g  ·  C ${entry.carbs.toStringAsFixed(1)}g  ·  F ${entry.fat.toStringAsFixed(1)}g',
                style: const TextStyle(color: beamMuted, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${entry.calories.round()}',
              style: const TextStyle(
                color: beamCyan,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Text(
              'kcal',
              style: TextStyle(color: beamMuted, fontSize: 10),
            ),
          ],
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Theme(
    data: beamTheme(context),
    child: Scaffold(
      backgroundColor: beamNavy,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              children: [
                BeamTabHeader(
                  title: 'Scan Food',
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
                  trailing: BeamHeaderAction(
                    icon: Icons.history_rounded,
                    tooltip: 'Scan history',
                    onPressed: _isScanning ? null : _showScanHistory,
                  ),
                ),
                _buildIntro(),
                const SizedBox(height: 16),
                _buildCameraCard(),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  _buildError(),
                ],
                if (_result != null) ...[
                  const SizedBox(height: 14),
                  _buildResult(_result!),
                  const SizedBox(height: 12),
                  _buildCoachPrompt(),
                ],
                const SizedBox(height: 16),
                const Text(
                  'Nutrition values are estimates. For the best result, place the full meal in good lighting and keep the camera steady.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: beamMuted,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _buildIntro() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Expanded(
            child: Text(
              'Know your plate.',
              style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: beamCyan.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: beamCyan.withValues(alpha: .65)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome_rounded, color: beamCyan, size: 15),
                SizedBox(width: 6),
                Text(
                  'AI-powered',
                  style: TextStyle(
                    color: beamCyan,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 3),
      const Text(
        'Snap a meal. Discover its nutrition.',
        style: TextStyle(color: beamMuted, fontSize: 16, height: 1.35),
      ),
    ],
  );

  Widget _buildCameraCard() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF032235),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: beamBorder),
    ),
    child: Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 1.45,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_imageBytes == null)
                  Stack(
                    fit: StackFit.expand,
                    children: [
                      SvgPicture.asset(
                        'assets/icons/connect/food-placeholder.svg',
                        fit: BoxFit.cover,
                        excludeFromSemantics: true,
                      ),
                      ColoredBox(
                        color: beamNavy.withValues(alpha: .18),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                color: beamCyan.withValues(alpha: .12),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: beamCyan.withValues(alpha: .65),
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                size: 28,
                                color: beamCyan,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Aim your camera at the meal',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Good light gives better estimates',
                              style: TextStyle(color: beamMuted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                else
                  Image.memory(_imageBytes!, fit: BoxFit.cover),
                const IgnorePointer(child: _ScanFrameCorners()),
                if (!_isScanning)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 14,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF032235).withValues(alpha: .9),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: beamCyan),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: beamCyan,
                              size: 15,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _imageBytes == null
                                  ? 'Camera ready'
                                  : 'Meal captured',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (_isScanning) const _ScanLoadingOverlay(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _isScanning ? null : _takePhoto,
            icon: Icon(Icons.camera_alt_rounded),
            label: Text(
              _isScanning
                  ? 'Analysing your meal…'
                  : _imageBytes == null
                  ? 'Take food photo'
                  : 'Retake food photo',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: beamCyan,
              foregroundColor: beamNavy,
              minimumSize: const Size.fromHeight(50),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded, color: beamMuted, size: 14),
            SizedBox(width: 5),
            Flexible(
              child: Text(
                'Camera only · no gallery upload',
                textAlign: TextAlign.center,
                style: TextStyle(color: beamMuted, fontSize: 11),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _buildError() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF3A1F2A),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFF9C5268)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline_rounded, color: Color(0xFFFF9DAF)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            _error!,
            style: const TextStyle(
              color: Color(0xFFFFC4CE),
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildResult(FoodAnalysisResult result) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFF032235),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: beamCyan.withValues(alpha: .55)),
      boxShadow: [
        BoxShadow(color: beamCyan.withValues(alpha: .08), blurRadius: 22),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Nutrition estimate',
                style: TextStyle(color: beamMuted, fontSize: 13),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: beamCyan.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: beamCyan.withValues(alpha: .6)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome_rounded, color: beamCyan, size: 13),
                  SizedBox(width: 5),
                  Text(
                    'AI estimate',
                    style: TextStyle(
                      color: beamCyan,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          result.mealName,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${result.calories.round()}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.w800,
                height: .95,
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 8, bottom: 4),
              child: Text(
                'kcal',
                style: TextStyle(color: beamMuted, fontSize: 14),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _macro('Protein', result.protein, const Color(0xFF62A5FF)),
            _macro('Carbs', result.carbs, const Color(0xFFFFC55B)),
            _macro('Fat', result.fat, const Color(0xFFFF7890)),
          ],
        ),
        if (result.ingredients.isNotEmpty) ...[
          const SizedBox(height: 18),
          const Text(
            'Detected ingredients',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (final ingredient in result.ingredients) _ingredient(ingredient),
        ],
        if (result.note != null) ...[
          const SizedBox(height: 12),
          Text(
            result.note!,
            style: const TextStyle(color: beamMuted, fontSize: 12),
          ),
        ],
      ],
    ),
  );

  Widget _macro(String label, num value, Color color) => Expanded(
    child: Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            '${value.toStringAsFixed(1)}g',
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(color: beamMuted, fontSize: 11)),
        ],
      ),
    ),
  );

  Widget _ingredient(FoodIngredient ingredient) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      children: [
        const Icon(Icons.check_circle_rounded, color: beamCyan, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(ingredient.name, style: const TextStyle(fontSize: 13)),
        ),
        if (ingredient.portion != null)
          Text(
            ingredient.portion!,
            style: const TextStyle(color: beamMuted, fontSize: 12),
          ),
        if (ingredient.calories != null) ...[
          const SizedBox(width: 8),
          Text(
            '${ingredient.calories!.round()} kcal',
            style: const TextStyle(color: beamMuted, fontSize: 12),
          ),
        ],
      ],
    ),
  );

  Widget _buildCoachPrompt() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF032235),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: beamBorder),
    ),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: beamCyan.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Image.asset(
            'assets/icons/connect/chatbot.png',
            width: 25,
            height: 25,
            semanticLabel: 'AI Coach chatbot',
          ),
        ),
        const SizedBox(width: 11),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Need meal guidance?',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              SizedBox(height: 3),
              Text(
                'Get personalized advice from AI Coach.',
                style: TextStyle(color: beamMuted, fontSize: 11),
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: () => Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute<void>(builder: (_) => AiCoachScreen.resume()),
          ),
          icon: const SizedBox.shrink(),
          label: const Text('Ask AI Coach'),
          style: TextButton.styleFrom(
            foregroundColor: beamCyan,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ScanLoadingOverlay extends StatefulWidget {
  const _ScanLoadingOverlay();

  @override
  State<_ScanLoadingOverlay> createState() => _ScanLoadingOverlayState();
}

class _ScanLoadingOverlayState extends State<_ScanLoadingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  late final CurvedAnimation progress = CurvedAnimation(
    parent: animation,
    curve: Curves.easeInOutCubic,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      animation.stop();
    } else if (!animation.isAnimating) {
      animation.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    progress.dispose();
    animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: progress,
    builder: (context, _) => LayoutBuilder(
      builder: (context, box) {
        final scanProgress = MediaQuery.disableAnimationsOf(context)
            ? .25
            : progress.value;
        final scanTop = 18 + (box.maxHeight - 36) * scanProgress;
        return Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: beamNavy.withValues(alpha: .26)),
            Positioned(
              left: 18,
              right: 18,
              top: scanTop,
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  color: beamCyan,
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: const [
                    BoxShadow(color: beamCyan, blurRadius: 12, spreadRadius: 2),
                  ],
                ),
              ),
            ),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF032235).withValues(alpha: .94),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: beamCyan.withValues(alpha: .75)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x5500D7E8),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: beamCyan, size: 17),
                    SizedBox(width: 8),
                    Text(
                      'Analyzing your meal',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _ScanFrameCorners extends StatelessWidget {
  const _ScanFrameCorners();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(18),
    child: CustomPaint(painter: _ScanCornersPainter()),
  );
}

class _ScanCornersPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = beamCyan
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const length = 30.0;
    final path = Path()
      ..moveTo(0, length)
      ..lineTo(0, 0)
      ..lineTo(length, 0)
      ..moveTo(size.width - length, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, length)
      ..moveTo(0, size.height - length)
      ..lineTo(0, size.height)
      ..lineTo(length, size.height)
      ..moveTo(size.width - length, size.height)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width, size.height - length);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
