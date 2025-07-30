import 'dart:async';
import 'dart:convert';
import 'package:fllama/fllama.dart';

class PokemonInfoGenerator {
  final String modelPath;

  PokemonInfoGenerator({required this.modelPath});

  Future<String> _runChat(OpenAiRequest request) async {
    final completer = Completer<String>();
    fllamaChat(request, (String _resp, String json, bool done) {
      if (done) completer.complete(json);
    });
    return completer.future;
  }

  Future<PokemonInfo> generateInfo(String name) async {
    final prompt = '''
You are an expert Pokemon info generator. Given the pokemon $name, generate a short description, types, and a glow color in hex format.
Please output EXACTLY a JSON object with three fields:
  {
    "description": "<short Pikachu-style description>",
    "types": ["Electric", ...],
    "glowColor": "#RRGGBB"
  }
Do not output any additional text.
''';

    final request = OpenAiRequest(
      modelPath: modelPath,
      maxTokens: 150,
      temperature: 0.8,
      topP: 1.0,
      messages: [Message(Role.user, prompt)],
    );

    final jsonString = await _runChat(request);
    final Map<String, dynamic> data = jsonDecode(jsonString);
    return PokemonInfo.fromJson(data);
  }
}

class PokemonInfo {
  final String description;
  final List<String> types;
  final String glowColor;

  PokemonInfo({required this.description, required this.types, required this.glowColor});

  factory PokemonInfo.fromJson(Map<String, dynamic> json) {
    return PokemonInfo(
      description: json['description'] as String,
      types: List<String>.from(json['types'] as List<dynamic>),
      glowColor: json['glowColor'] as String,
    );
  }
}