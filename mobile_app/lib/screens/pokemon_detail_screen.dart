import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PokemonDetailScreen extends StatelessWidget {
  static const routeName = '/pokemon_detail';
  final String speciesName;
  final double confidence;
  final dynamic image; // Will be File/Image type in real use

  const PokemonDetailScreen({
    super.key,
    required this.speciesName,
    required this.confidence,
    this.image,
  });

  @override
  Widget build(BuildContext context) {
    final spriteUrl =
        'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/25.png';
    final types = ['Electric'];
    final description =
        'Whenever Pikachu comes across something new, it blasts it with a jolt of electricity.';
    return Container(
      decoration: const BoxDecoration(color: Color.fromRGBO(17, 17, 17, 1)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: Center(
          child: Card(
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
                            fit: BoxFit.cover,
                          )
                        : Image.network(spriteUrl, width: 160, height: 160),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    speciesName,
                    style: GoogleFonts.inter(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFEF5350),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: types
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
                    description,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 18, color: Colors.white),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Confidence: ${(confidence * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
