import 'dart:math';
import 'package:image/image.dart' as img;
import 'package:cross_file/cross_file.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class ImageClassifier {
  final Future<Interpreter> _interpreter;
  final List<String> _labels = [
    "charmander",
    "mew",
    "psyduck",
    "bulbosaur",
    "gengar",
    "magikarp",
    "pikachu",
    "squirtle",
  ];

  ImageClassifier(String modelPath)
    : _interpreter = Interpreter.fromAsset(modelPath);

  /// Reads [imageFile], resizes to 200×200, normalizes, and returns a List shaped [3,200,200] (CHW).
  Future<List<List<List<double>>>> _preprocessImage(XFile imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final rawImage = img.decodeImage(bytes);
    if (rawImage == null) {
      throw Exception('Could not decode image bytes');
    }

    final resized = img.copyResize(rawImage, width: 200, height: 200);

    const List<double> mean = [0.5191, 0.4885, 0.4491];
    const List<double> std = [0.2227, 0.2106, 0.1982];

    final List<List<List<double>>> imgData = List<List<List<double>>>.filled(
      3,
      List<List<double>>.filled(200, List<double>.filled(200, 0)),
    );

    for (int y = 0; y < 200; y++) {
      for (int x = 0; x < 200; x++) {
        final pixel = resized.getPixel(x, y);
        imgData[0][y][x] = ((pixel.r / 255.0) - mean[0]) / std[0];
        imgData[1][y][x] = ((pixel.g / 255.0) - mean[1]) / std[1];
        imgData[2][y][x] = ((pixel.b / 255.0) - mean[2]) / std[2];
      }
    }

    return imgData;
  }

  Future<Map<String, double>> classifyImage(XFile image) async {
    final input = await _preprocessImage(image);

    return classifyTensor(input);
  }

  // Input shape: [3, 200, 200]
  // Batch dimension is handled internally
  Future<Map<String, double>> classifyTensor(
    List<List<List<double>>> input,
  ) async {
    var output = List.filled(1 * 8, 0.0).reshape([1, 8]);

    final inputTensor = (await _interpreter).getInputTensor(0);
    print('shape: ${inputTensor.shape}, type: ${inputTensor.type}');

    (await _interpreter).run([input], output);

    print('Raw logits: ${output.toList()}');

    List<double> probabilities = _softmax(output[0]);

    return Map.fromIterables(_labels, probabilities);
  }

  List<double> _softmax(List<double> logits) {
    double sumExp = logits.map((logit) => exp(logit)).reduce((a, b) => a + b);
    return logits.map((logit) => exp(logit) / sumExp).toList();
  }

  void close() async {
    (await _interpreter).close();
  }
}
