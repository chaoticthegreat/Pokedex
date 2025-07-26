import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraModalSheet extends StatefulWidget {
  const CameraModalSheet({super.key});

  @override
  State<CameraModalSheet> createState() => _CameraModalSheetState();
}

class _CameraModalSheetState extends State<CameraModalSheet> {
  List<CameraDescription?> _cameras = [];
  CameraController? _controller;
  Future<void>? _initializeFuture;
  bool _isTaking = false;

  @override
  void initState() {
    super.initState();
    _setupCamera();
  }

  Future<void> _setupCamera() async {
    final granted = await _ensureCameraPermission();

    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera permission is required to scan Pokémon'),
          ),
        );
      }
      return;
    }

    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _cameras = cameras;

    _controller = CameraController(
      cameras.first,
      ResolutionPreset.low,
      enableAudio: false,
    );

    _initializeFuture = _controller?.initialize();

    setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<bool> _ensureCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) return true;
    final result = await Permission.camera.request();
    return result.isGranted;
  }

  Future<void> _capture() async {
    if (_isTaking) return;

    setState(() => _isTaking = true);

    try {
      final photo = await _controller?.takePicture();

      if (mounted) Navigator.of(context).pop(photo);
    } finally {
      setState(() => _isTaking = false);
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;

    final currentIndex = _cameras.indexOf(_controller?.description);
    final nextIndex = (currentIndex + 1) % _cameras.length;

    _controller?.dispose();
    _controller = CameraController(
      _cameras[nextIndex]!,
      ResolutionPreset.low,
      enableAudio: false,
    );

    _initializeFuture = _controller?.initialize();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.75;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            // Drag handle
            const Padding(
              padding: EdgeInsets.only(top: 12, bottom: 8),
              child: Center(
                child: SizedBox(
                  width: 48,
                  height: 6,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.all(Radius.circular(3)),
                    ),
                  ),
                ),
              ),
            ),

            // Camera preview + capture button
            Expanded(
              child: FutureBuilder<void>(
                future: _initializeFuture,
                builder: (_, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return Stack(
                    children: [
                      if (_controller != null) CameraPreview(_controller!),

                      if (_isTaking)
                        const Center(child: CircularProgressIndicator()),

                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 32),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              FloatingActionButton(
                                onPressed: _capture,
                                backgroundColor: Colors.red,
                                child: const Icon(
                                  Icons.camera,
                                  size: 32,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 16),
                              FloatingActionButton(
                                onPressed: _switchCamera,
                                backgroundColor: Colors.blue,
                                child: const Icon(
                                  Icons.switch_camera,
                                  size: 32,
                                  color: Colors.white,
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
            ),
          ],
        ),
      ),
    );
  }
}
