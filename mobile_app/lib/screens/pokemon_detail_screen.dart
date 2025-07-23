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

  Color _typeColor(String type) {
    switch (type.toLowerCase()) {
      case 'electric':
        return const Color(0xFFFFCB05);
      case 'water':
        return const Color(0xFF6390F0);
      case 'fire':
        return const Color(0xFFEE8130);
      case 'grass':
        return const Color(0xFF7AC74C);
      case 'psychic':
        return const Color(0xFFF95587);
      case 'ice':
        return const Color(0xFF96D9D6);
      case 'dragon':
        return const Color(0xFF6F35FC);
      case 'dark':
        return const Color(0xFF705746);
      case 'fairy':
        return const Color(0xFFD685AD);
      default:
        return const Color(0xFFB7B7CE);
    }
  }

  @override
  Widget build(BuildContext context) {
    final spriteUrl =
        'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/25.png';
    final types = ['Electric'];
    final description =
        'Whenever Pikachu comes across something new, it blasts it with a jolt of electricity.';
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFEF5350), Color(0xFF2A75BB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              speciesName,
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Icon(Icons.catching_pokemon, color: Colors.white),
          ],
        ),
      ),
      body: Center(
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
          ),
          color: Colors.white.withValues(alpha: 0.97),
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
                          decoration: BoxDecoration(
                            color: _typeColor(type),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: _typeColor(type).withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Text(
                            type,
                            style: const TextStyle(
                              color: Colors.black,
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
                  style: GoogleFonts.inter(fontSize: 18),
                ),
                const SizedBox(height: 24),
                Text(
                  'Confidence: ${(confidence * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
