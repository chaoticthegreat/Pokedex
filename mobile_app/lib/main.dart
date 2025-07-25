import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/home_screen.dart';
import 'screens/pokemon_detail_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pokédex',
      theme: ThemeData(
        colorScheme: ColorScheme(
          brightness: Brightness.light,
          primary: const Color.fromRGBO(194, 45, 43, 1), // Pokeball red
          onPrimary: Colors.white,
          secondary: const Color(0xFF2A75BB), // Pokemon blue
          onSecondary: Colors.white,
          error: Colors.red,
          onError: Colors.white,
          surface: Colors.white,
          onSurface: Colors.black,
        ),
        textTheme: GoogleFonts.dmSansTextTheme(),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          centerTitle: true,
          iconTheme: IconThemeData(color: Colors.white),
          elevation: 0,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromRGBO(194, 45, 43, 1),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(32),
            ),
            textStyle: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            elevation: 4,
            shadowColor: Colors.black26,
          ),
        ),
      ),
      home: const HomeScreen(),
      onGenerateRoute: (settings) {
        if (settings.name == PokemonDetailScreen.routeName) {
          final args = settings.arguments as Map<String, dynamic>;
          return PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                PokemonDetailScreen(
                  speciesName: args['speciesName'],
                  confidence: args['confidence'],
                  image: args['image'],
                ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
          );
        }
        return null;
      },
    );
  }
}
