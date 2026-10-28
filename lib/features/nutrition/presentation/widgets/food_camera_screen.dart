import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../shared/widgets/beam_ui.dart';

class FoodCameraScreen extends StatefulWidget {
  const FoodCameraScreen({super.key});

  @override
  State<FoodCameraScreen> createState() => _FoodCameraScreenState();
}

class _FoodCameraScreenState extends State<FoodCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  String? _error;
  bool _isCapturing = false;
  bool _isStarting = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      controller.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed && mounted) {
      _startCamera();
    }
  }

  Future<void> _startCamera() async {
    if (!mounted) return;
    setState(() {
      _isStarting = true;
      _error = null;
    });
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException(
          'NoCamera',
          'No camera is available on this device.',
        );
      }
      final camera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      await controller.setFlashMode(FlashMode.off);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await _controller?.dispose();
      setState(() {
        _controller = controller;
        _isStarting = false;
      });
    } on CameraException catch (error) {
      if (!mounted) return;
      setState(() {
        _isStarting = false;
        _error = _cameraError(error);
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _isStarting = false;
        _error = 'Could not start the camera: $error';
      });
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _isCapturing) {
      return;
    }
    setState(() => _isCapturing = true);
    try {
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();
      if (mounted) Navigator.of(context).pop<Uint8List>(bytes);
    } on CameraException catch (error) {
      if (mounted) setState(() => _error = _cameraError(error));
    } on Exception catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not capture the meal: $error');
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  String _cameraError(CameraException error) {
    final code = error.code.toLowerCase();
    if (code.contains('denied') || code.contains('restricted')) {
      return 'Camera access is disabled. Allow camera access in Settings to scan your meal.';
    }
    return error.description ?? 'Camera is not available right now.';
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: beamTheme(context),
    child: Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildPreview(),
            const Positioned.fill(child: _CameraShade()),
            Positioned(
              top: 14,
              left: 16,
              child: _circleButton(
                icon: Icons.chevron_left_rounded,
                tooltip: 'Close camera',
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const Positioned(
              top: 26,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Column(
                  children: [
                    Text(
                      'E-HEALTH',
                      style: TextStyle(
                        color: beamCyan,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.2,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Scan meal',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 14,
              right: 16,
              child: _circleButton(
                icon: Icons.flash_off_rounded,
                tooltip: 'Flash is off',
                onPressed: _controller == null ? null : _toggleFlash,
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: AspectRatio(
                  aspectRatio: .76,
                  child: CustomPaint(painter: _CameraFramePainter()),
                ),
              ),
            ),
            Positioned(left: 0, right: 0, bottom: 0, child: _buildControls()),
            if (_isStarting) const _CameraLoading(),
            if (_error != null) _buildError(),
          ],
        ),
      ),
    ),
  );

  Widget _buildPreview() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Positioned.fill(child: ColoredBox(color: Color(0xFF5E6B6A)));
    }
    return Positioned.fill(
      child: ClipRect(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final portrait =
                MediaQuery.orientationOf(context) == Orientation.portrait;
            // CameraPreview already rotates its Android texture. Match that
            // portrait ratio here so the outer crop never double-scales it.
            final previewAspect = portrait
                ? 1 / controller.value.aspectRatio
                : controller.value.aspectRatio;
            final screenAspect = constraints.maxWidth / constraints.maxHeight;
            final Size previewSize;
            if (screenAspect > previewAspect) {
              previewSize = Size(
                constraints.maxWidth,
                constraints.maxWidth / previewAspect,
              );
            } else {
              previewSize = Size(
                constraints.maxHeight * previewAspect,
                constraints.maxHeight,
              );
            }
            return Center(
              child: SizedBox(
                width: previewSize.width,
                height: previewSize.height,
                child: CameraPreview(controller),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (controller == null) return;
    final next = controller.value.flashMode == FlashMode.off
        ? FlashMode.auto
        : FlashMode.off;
    await controller.setFlashMode(next);
    if (mounted) setState(() {});
  }

  Widget _circleButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) => Material(
    color: Colors.black.withValues(alpha: .32),
    shape: const CircleBorder(),
    child: IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      color: Colors.white,
      iconSize: 25,
      icon: Icon(icon),
    ),
  );

  Widget _buildControls() => Container(
    padding: const EdgeInsets.fromLTRB(24, 34, 24, 22),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Color(0xF0001321)],
      ),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Center your meal inside the frame',
          style: TextStyle(color: Colors.white, fontSize: 13),
        ),
        const SizedBox(height: 5),
        const Text(
          'Use good light for a more accurate estimate',
          style: TextStyle(color: Color(0xFFB9CAD2), fontSize: 11),
        ),
        const SizedBox(height: 18),
        GestureDetector(
          onTap: _capture,
          child: Container(
            width: 76,
            height: 76,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: beamCyan.withValues(alpha: .35),
                  blurRadius: 18,
                ),
              ],
            ),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: beamCyan,
                shape: BoxShape.circle,
              ),
              child: _isCapturing
                  ? const Padding(
                      padding: EdgeInsets.all(18),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: beamNavy,
                      ),
                    )
                  : const Icon(
                      Icons.camera_alt_rounded,
                      color: beamNavy,
                      size: 29,
                    ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildError() => Positioned(
    left: 20,
    right: 20,
    bottom: 205,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xE83A1F2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF9DAF)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFFFFB7C4)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          if (_error!.contains('Settings'))
            IconButton(
              tooltip: 'Open Settings',
              onPressed: openAppSettings,
              icon: const Icon(Icons.settings_rounded, color: Colors.white),
            ),
        ],
      ),
    ),
  );
}

class _CameraLoading extends StatelessWidget {
  const _CameraLoading();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(color: beamCyan),
        SizedBox(height: 14),
        Text('Starting camera…', style: TextStyle(color: Colors.white)),
      ],
    ),
  );
}

class _CameraShade extends StatelessWidget {
  const _CameraShade();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            beamNavy.withValues(alpha: .54),
            Colors.transparent,
            beamNavy.withValues(alpha: .3),
          ],
          stops: const [0, .35, 1],
        ),
      ),
    ),
  );
}

class _CameraFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: .9)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const corner = 31.0;
    final path = Path()
      ..moveTo(0, corner)
      ..lineTo(0, 0)
      ..lineTo(corner, 0)
      ..moveTo(size.width - corner, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, corner)
      ..moveTo(0, size.height - corner)
      ..lineTo(0, size.height)
      ..lineTo(corner, size.height)
      ..moveTo(size.width - corner, size.height)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width, size.height - corner);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
