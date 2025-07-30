import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/classification_probabilities.dart';
import '../services/pokemon_info_generator.dart';

class PokemonDetailScreen extends StatelessWidget {
  static const routeName = '/pokemon_detail';
  static PokemonInfoGenerator infoGenerator = PokemonInfoGenerator(modelPath: 'assets/models/Llama-3.2-1B-Instruct-Q4_0.gguf');
  final ClassificationProbabilities probabilities;
  final dynamic image;

  const PokemonDetailScreen({
    super.key,
    required this.probabilities,
    this.image,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Color.fromRGBO(17, 17, 17, 1)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: Center(
          child: FutureBuilder<PokemonInfo>(
            future: infoGenerator.generateInfo(probabilities.getMostProbableClass()),
            builder: (context, asyncSnapshot) {
              if (asyncSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              PokemonInfo data = asyncSnapshot.data ?? PokemonInfo(
                description: "Error Loading",
                types: ["Unknown"],
                glowColor: '#FFFF00', // Default glow color
              );
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
                        child: image != null
                            ? Image.file(
                                image,
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
                        probabilities.getMostProbableClass().toUpperCase(),
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
                                margin: const EdgeInsets.symmetric(horizontal: 6),
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
                        style: GoogleFonts.inter(fontSize: 18, color: Colors.white),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Confidence: ${(probabilities.getProbability(probabilities.getMostProbableClass()) * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(fontSize: 16, color: Colors.white70),
                      ),
                      const SizedBox(height: 24),
                      // have text button to view other possible detections as an ExpansionTile
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
                                children: probabilities
                                    .getProbabilitiesMap()
                                    .entries
                                    .where(
                                      (entry) =>
                                          entry.key !=
                                          probabilities.getMostProbableClass(),
                                    )
                                    .map(
                                      (entry) => ListTile(
                                        title: Text(
                                          '${entry.key}: ${(entry.value * 100).toStringAsFixed(1)}%',
                                          style: const TextStyle(color: Colors.white70),
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
            }
          ),
        ),
      ),
    );
  }
}
