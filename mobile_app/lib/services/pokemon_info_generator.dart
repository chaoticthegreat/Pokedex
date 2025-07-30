import 'dart:async';
import 'dart:convert';

import 'package:fllama/fllama.dart';

class PokemonInfoGenerator {
  final String modelPath;

  PokemonInfoGenerator({required this.modelPath});

  Future<String> _runChat(OpenAiRequest request) async {
    print('Running chat with model: $modelPath');
    final completer = Completer<String>();
    fllamaChat(request, (String resp, String json, bool done) {
      if (done) completer.complete(resp);
    });
    return await completer.future;
  }

  Future<PokemonInfo> generateInfo(String name) async {
    if (name.isEmpty) {
      throw ArgumentError('Pokemon name cannot be empty');
    }
    print('Generating info for Pokemon: $name');
    final prompt =
        '''Given the pokemon $name, output EXACTLY a JSON object with three fields. The fields should be filled in with relevant data about the pokemon:
{
  "description": "<short Pikachu-style description>",
  "types": ["Electric", ...],
  "glowColor": "#RRGGBB"
}
Do not output any additional text.
''';

    final request = OpenAiRequest(
      modelPath: modelPath,
      maxTokens: 512,
      temperature: 0.1,
      topP: 1.0,
      presencePenalty: 1.1,
      logger: (log) {
        // ignore: avoid_print
        print('[llama.cpp] $log');
      },
      messages: [Message(Role.user, prompt)],
    );

    final jsonString = await _runChat(request);
    print('Received JSON response: $jsonString');

    final Map<String, dynamic> data = jsonDecode(
      jsonString.substring(
        jsonString.indexOf('{'),
        jsonString.lastIndexOf('}') + 1,
      ),
    );
    return PokemonInfo.fromJson(data);
  }
}

class PokemonInfo {
  final String description;
  final List<String> types;
  final String glowColor;

  PokemonInfo({
    required this.description,
    required this.types,
    required this.glowColor,
  });

  factory PokemonInfo.fromJson(Map<String, dynamic> json) {
    return PokemonInfo(
      description: json['description'] as String,
      types: List<String>.from(json['types'] as List<dynamic>),
      glowColor: json['glowColor'] as String,
    );
  }
}
