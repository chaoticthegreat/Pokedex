import 'dart:io';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cross_file/cross_file.dart';
import 'camera_modal_sheet.dart';
import '../image_classifier.dart';
import 'pokemon_detail_screen.dart';
import '../classification_probabilities.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImageClassifier _classifier = ImageClassifier(
    'assets/models/image-cnn.tflite',
  );

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _classifier.close();
    super.dispose();
  }

  void _onScanPokemon(BuildContext context) async {
    if (!context.mounted) return;

    final XFile? picture = await showModalBottomSheet<XFile>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black.withAlpha(200),
      useSafeArea: true,
      enableDrag: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      builder: (context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: CameraModalSheet(),
        ),
      ),
    );

    // if the user took one, navigate
    if (picture != null) {
      ClassificationProbabilities probabilities = ClassificationProbabilities(
        await _classifier.classifyImage(picture),
      );

      if (!context.mounted) return;

      print('Probabilities: $probabilities');

      Navigator.of(context).pushNamed(
        PokemonDetailScreen.routeName,
        arguments: {
          'probabilities': probabilities,
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
            ],
          ),
        ),
      ),
    );
  }
}
