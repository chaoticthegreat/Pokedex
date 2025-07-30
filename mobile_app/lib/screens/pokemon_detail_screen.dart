import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../services/hugging_face_service.dart';
import '../services/pokemon_info_generator.dart';
import '../utils/classification_probabilities.dart';

class PokemonDetailScreen extends StatefulWidget {
  static const routeName = '/pokemon_detail';

  const PokemonDetailScreen({
    super.key,
    required this.probabilities,
    this.image,
  });

  final ClassificationProbabilities probabilities;
  final dynamic image;

  @override
  State<PokemonDetailScreen> createState() => _PokemonDetailScreenState();
}

class _PokemonDetailScreenState extends State<PokemonDetailScreen> {
  double _progress = 0;
  bool _isDownloading = false;
  String _modelPath = '';
  String _status = 'Waiting for download...';

  // Llama model details
  final _modelName = 'Qwen2.5-0.5B-Instruct-Q5_K_S.gguf';
  final _downloader = HuggingFaceDownloader(
    modelUrl:
        'https://huggingface.co/bartowski/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/Qwen2.5-0.5B-Instruct-Q5_K_S.gguf?download=true',
    fileName: 'Qwen2.5-0.5B-Instruct-Q5_K_S.gguf',
  );

  // Generator and future for info
  late PokemonInfoGenerator _infoGenerator;
  Future<PokemonInfo>? _infoFuture;

  Future<Directory> get _finalModelDir async {
    final directory = await getApplicationDocumentsDirectory();
    final modelDir = Directory('${directory.path}/models');
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }
    return modelDir;
  }

  Future<void> _startDownload({required BuildContext context}) async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
      _status = 'Starting download...';
      _progress = 0;
    });

    try {
      await _downloader.downloadModel(
        onProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _progress = received / total;
              _status =
                  'Downloaded: ${(received / 1024 / 1024).toStringAsFixed(2)}MB of ${(total / 1024 / 1024).toStringAsFixed(2)}MB '

                  '(${(_progress * 100).toStringAsFixed(1)}%)';
            });
          }
        },
        onComplete: (filePath) async {
          setState(() {
            _status = 'Moving file to final location...';
          });

          try {
            final finalDir = await _finalModelDir;
            final finalPath = path.join(finalDir.path, _modelName);

            setState(() {
              _isDownloading = false;
              _modelPath = finalPath;
              _infoGenerator = PokemonInfoGenerator(modelPath: _modelPath);
              _infoFuture = _infoGenerator.generateInfo(
                widget.probabilities.getMostProbableClass(),
              );
            });
          } catch (e) {
            setState(() {
              _status = 'Error moving file: $e';
              _isDownloading = false;
            });
          }
        },
        onError: (error) {
          setState(() {
            _status = 'Error: $error';
            _isDownloading = false;
          });
        },
      );
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
        _isDownloading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Color.fromRGBO(17, 17, 17, 1)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: Center(
          child: _modelPath.isEmpty
              // Show download UI until model is ready
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_status, style: const TextStyle(color: Colors.white)),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: _isDownloading ? _progress : null,
                      backgroundColor: Colors.white24,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _startDownload(context: context),
                      child: const Text('Download Model'),
                    ),
                  ],
                )
              // Once model is downloaded, show info
              : FutureBuilder<PokemonInfo>(
                  future: _infoFuture,
                  builder: (context, asyncSnapshot) {
                    if (asyncSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (asyncSnapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error: ${asyncSnapshot.error}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      );
                    }
                    final PokemonInfo data = asyncSnapshot.data!;
                    return Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32),
                      ),
                      color: Colors.white.withValues(alpha: 0.05),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(80),
                              child: widget.image != null
                                  ? Image.file(
                                      widget.image,
                                      width: 160,
                                      height: 160,
                                      fit: BoxFit.fitHeight,
                                    )
                                  : Container(
                                      color: Colors.white,
                                      width: 160,
                                      height: 160,
                                    ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              widget.probabilities
                                  .getMostProbableClass()
                                  .toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFEF5350),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: data.types
                                  .map(
                                    (type) => Container(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      child: Text(
                                        type,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              data.description,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Confidence: ${(widget.probabilities.getProbability(widget.probabilities.getMostProbableClass()) * 100).toStringAsFixed(1)}%',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ExpansionTile(
                              title: const Text(
                                'Other Detections',
                                style: TextStyle(color: Colors.white),
                              ),
                              children: [
                                SizedBox(
                                  height: 200,
                                  child: Scrollbar(
                                    child: ListView(
                                      children: widget.probabilities
                                          .getProbabilitiesMap()
                                          .entries
                                          .where(
                                            (entry) =>
                                                entry.key != widget.probabilities.getMostProbableClass(),
                                          )
                                          .map(
                                            (entry) => ListTile(
                                              title: Text(
                                                '${entry.key}: ${(entry.value * 100).toStringAsFixed(1)}%',
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
