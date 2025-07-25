import 'dart:io';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import 'camera_modal_sheet.dart';
import 'pokemon_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isProcessing = false;

  Future<bool> _ensureCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) return true;
    final result = await Permission.camera.request();
    return result.isGranted;
  }

  void _onScanPokemon(BuildContext context) async {
    final cameras = await availableCameras();

    if (cameras.isEmpty) return;

    if (!context.mounted) return;

    // show the modal, await the XFile
    final XFile? picture = await showModalBottomSheet<XFile>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (_) => CameraModalSheet(camera: cameras.first),
    );

    // if the user took one, navigate
    if (picture != null) {
      final model = await Interpreter.fromAsset('assets/models/image-cnn.tflite');

      Random random = Random();

      List<List<List<List<double>>>> input = [List.generate(200, (_) => List.generate(200, (_) => List.generate(3, (_) => random.nextDouble())))];
      var output = List.filled(1*8, 0).reshape([1,8]);

      model.run(input, output);

      // TODO: preprocess the image, resize to 200x200, mean and std

      Navigator.of(context).pushNamed(
        PokemonDetailScreen.routeName,
        arguments: {
          'speciesName': 'Pikachu',
          'confidence': 0.98,
          'image': File(picture.path),
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Color.fromRGBO(17, 17, 17, 1)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Stack(
            children: [
              Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Pokédex',
                        style: GoogleFonts.bangers(
                          fontSize: 72,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFFFCB05),
                          letterSpacing: 2,
                          shadows: [
                            Shadow(
                              blurRadius: 8,
                              color: Colors.black.withValues(alpha: 0.25),
                              offset: const Offset(2, 4),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Snap or record to identify Pokémon instantly!',
                        style: GoogleFonts.dmSans(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 40,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: double.infinity,
                              height: 64,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.camera_alt, size: 32),
                                label: const Text('Scan Pokémon'),
                                style: ElevatedButton.styleFrom(
                                  textStyle: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: () => _onScanPokemon(context),
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Detect from Audio button
                            SizedBox(
                              width: double.infinity,
                              height: 64,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.mic, size: 32),
                                label: const Text('Detect from Audio'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color.fromRGBO(
                                    234,
                                    163,
                                    17,
                                    1,
                                  ),
                                  foregroundColor: Colors.black,
                                  textStyle: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 4,
                                ),
                                onPressed: () {}, // No action yet
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_isProcessing)
                Container(
                  color: Colors.black.withValues(alpha: 0.5),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Identifying Pokémon...',
                          style: TextStyle(color: Colors.white, fontSize: 20),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
