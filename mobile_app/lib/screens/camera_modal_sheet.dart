import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraModalSheet extends StatefulWidget {
  final CameraDescription camera;
  const CameraModalSheet({required this.camera, super.key});

  @override
  State<CameraModalSheet> createState() => _CameraModalSheetState();
}

class _CameraModalSheetState extends State<CameraModalSheet> {
  late final CameraController _controller;
  late final Future<void> _initializeFuture;
  bool _isTaking = false;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.medium,
      enableAudio: false, // no audio for stills
    );

    _initializeFuture = _controller.initialize().then((_) async {
      // ensure preview is running immediately on first open
      try {
        await _controller.resumePreview();
      } catch (_) {
        // ignore if already running or unsupported
      }
      if (mounted) setState(() {}); // trigger rebuild once ready
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    if (_isTaking) return;
    setState(() => _isTaking = true);

    try {
      final photo = await _controller.takePicture();
      // pause preview to avoid maxImages warnings on some platforms
      try {
        await _controller.pausePreview();
      } catch (_) {}
      if (context.mounted) Navigator.of(context).pop(photo);
    } finally {
      if (mounted) setState(() => _isTaking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.85;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.black,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3), // corrected opacity
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
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
                      // ORIGINAL preview, no aspect tweaks
                      CameraPreview(_controller),

                      if (_isTaking)
                        Container(
                          color: Colors.black54,
                          child: const Center(child: CircularProgressIndicator()),
                        ),

                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 32),
                          child: FloatingActionButton(
                            onPressed: _capture,
                            backgroundColor: Colors.red,
                            child: const Icon(
                              Icons.camera,
                              size: 32,
                              color: Colors.white,
                            ),
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
