import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/card_parser.dart';
import '../services/ocr_service.dart';

/// Always-running live scanner (like a UPI scanner).
/// When the same valid number is read in 2 consecutive frames -> onDetected.
class LiveScanner extends StatefulWidget {
  final void Function(CardInfo info) onDetected;

  const LiveScanner({super.key, required this.onDetected});

  @override
  State<LiveScanner> createState() => _LiveScannerState();
}

class _LiveScannerState extends State<LiveScanner> with WidgetsBindingObserver {
  static const _frameGapMs = 600; // gap between OCR runs (saves battery / heat)

  static const _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  final OcrService _ocr = OcrService();
  CameraController? _controller;
  bool _busy = false;
  bool _torch = false;
  int _lastRunMs = 0;
  String? _lastKey;
  CardInfo? _lastInfo;
  String? _error;

  // Camera start/stop state (guards against start-up races).
  bool _wantCamera = true; // app is in the foreground
  bool _initializing = false; // a start is already running
  int _gen = 0; // bumped on every release; cancels a start that is in flight
  Future<void>? _disposing; // previous camera still being released

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  Future<void> _initCamera() async {
    // Never run two starts at once, never start if a camera is already running.
    if (_initializing || _controller != null) return;
    _initializing = true;
    final gen = ++_gen;
    try {
      if (mounted) setState(() => _error = null);

      var status = await Permission.camera.status;
      if (!status.isGranted) status = await Permission.camera.request();
      if (!mounted || gen != _gen) return;
      if (!status.isGranted) {
        setState(() => _error = 'Camera permission is required. Please allow it in Settings.');
        return;
      }

      // Wait until the previous camera is fully released.
      await _disposing;
      if (!mounted || gen != _gen) return;

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _error = 'No camera found on this device.');
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup:
            Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );

      try {
        await controller.initialize().timeout(const Duration(seconds: 15));
      } catch (e) {
        await controller.dispose();
        rethrow;
      }
      if (!mounted || gen != _gen) {
        await controller.dispose();
        return;
      }

      try {
        await controller.setFocusMode(FocusMode.auto);
      } catch (_) {
        // some devices do not support it - ignore
      }

      _controller = controller;
      _torch = false;
      await controller.startImageStream(_onFrame);
      if (mounted) setState(() => _error = null);
    } catch (e) {
      if (mounted && gen == _gen) setState(() => _error = 'Camera error: $e');
    } finally {
      _initializing = false;
      // The app came back to the foreground while this start was cancelled: start again.
      if (mounted && _wantCamera && _controller == null && _error == null) {
        _initCamera();
      }
    }
  }

  /// Releases the camera. Safe to call any time, even in the middle of a start.
  void _releaseCamera() {
    _gen++; // cancels a start that is still in flight
    final c = _controller;
    _controller = null;
    _lastKey = null;
    _lastInfo = null;
    if (c == null) return;
    _disposing = _disposeController(c);
  }

  Future<void> _disposeController(CameraController c) async {
    try {
      if (c.value.isStreamingImages) await c.stopImageStream();
    } catch (_) {}
    try {
      await c.dispose();
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Only "paused" (really in background). "inactive" also fires for the
    // permission dialog and notification shade, which must NOT stop the camera.
    if (state == AppLifecycleState.paused) {
      _wantCamera = false;
      _releaseCamera();
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed) {
      _wantCamera = true;
      if (_controller == null) _initCamera();
    }
  }

  Future<void> _onFrame(CameraImage image) async {
    if (_busy) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastRunMs < _frameGapMs) return;
    _busy = true;
    _lastRunMs = now;
    try {
      final input = _toInputImage(image);
      if (input == null) return;
      final recognized = await _ocr.recognize(input);
      final info = CardParser.parseRecognized(recognized);
      if (info.numbers.isEmpty) {
        _lastKey = null;
        _lastInfo = null;
        return;
      }
      final key = ([...info.numbers]..sort()).join(',');
      if (key == _lastKey) {
        // Same numbers in 2 frames. Fill name/email from the earlier frame if this one missed them.
        final merged = CardInfo(
          numbers: info.numbers,
          name: info.name ?? _lastInfo?.name,
          email: info.email ?? _lastInfo?.email,
        );
        _lastKey = null;
        _lastInfo = null;
        if (mounted) widget.onDetected(merged);
      } else {
        // Seen once - confirm in one more frame to avoid wrong OCR reads.
        _lastKey = key;
        _lastInfo = info;
      }
    } catch (_) {
      // ignore a single failed frame
    } finally {
      _busy = false;
    }
  }

  InputImage? _toInputImage(CameraImage image) {
    final controller = _controller;
    if (controller == null) return null;
    final camera = controller.description;
    final sensor = camera.sensorOrientation;

    int? rotationDeg;
    if (Platform.isIOS) {
      rotationDeg = sensor;
    } else if (Platform.isAndroid) {
      final comp = _orientations[controller.value.deviceOrientation];
      if (comp == null) return null;
      rotationDeg = camera.lensDirection == CameraLensDirection.front
          ? (sensor + comp) % 360
          : (sensor - comp + 360) % 360;
    }
    if (rotationDeg == null) return null;

    final rotation = InputImageRotation.values.cast<InputImageRotation?>().firstWhere(
          (r) => r!.rawValue == rotationDeg,
          orElse: () => null,
        );
    if (rotation == null) return null;

    final InputImageFormat format;
    if (Platform.isAndroid && image.format.group == ImageFormatGroup.nv21) {
      format = InputImageFormat.nv21;
    } else if (Platform.isIOS && image.format.group == ImageFormatGroup.bgra8888) {
      format = InputImageFormat.bgra8888;
    } else {
      return null;
    }
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Future<void> _toggleTorch() async {
    final c = _controller;
    if (c == null) return;
    _torch = !_torch;
    await c.setFlashMode(_torch ? FlashMode.torch : FlashMode.off);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _wantCamera = false;
    _releaseCamera();
    _ocr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF25D366);
    final c = _controller;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        color: Colors.black,
        child: _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white)),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () async {
                          if (await Permission.camera.isPermanentlyDenied) {
                            await openAppSettings();
                          } else {
                            _initCamera();
                          }
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            : (c == null || !c.value.isInitialized)
                ? const Center(child: CircularProgressIndicator(color: green))
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: c.value.previewSize!.height,
                          height: c.value.previewSize!.width,
                          child: CameraPreview(c),
                        ),
                      ),
                      const Positioned(
                        left: 0,
                        right: 0,
                        bottom: 12,
                        child: Text(
                          'Point the camera at the card',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            shadows: [Shadow(blurRadius: 6, color: Colors.black)],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton(
                          onPressed: _toggleTorch,
                          icon: Icon(_torch ? Icons.flash_on : Icons.flash_off),
                          color: Colors.white,
                          style: IconButton.styleFrom(backgroundColor: Colors.black38),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}