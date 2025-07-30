import 'dart:io';

import 'package:path_provider/path_provider.dart';

class HuggingFaceDownloader {
  final String modelUrl;
  final String fileName;

  HuggingFaceDownloader({required this.modelUrl, required this.fileName});

  Future<void> downloadModel({
    required Function(int, int) onProgress,
    required Function(String) onComplete,
    required Function(String) onError,
  }) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final modelDirectory = Directory('${directory.path}/models');
      if (!await modelDirectory.exists()) {
        await modelDirectory.create(recursive: true);
      }
      print('directory ${modelDirectory.listSync()}');

      final file = File('${modelDirectory.path}/$fileName');
      print('Downloading model to ${file.path}');

      if (await file.exists()) {
        onComplete(file.path);
        return;
      }

      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(modelUrl));
      final response = await request.close();

      final totalBytes = response.contentLength;
      int receivedBytes = 0;


      // Create a sink to write to the file
      final sink = file.openWrite();

      // Use await for to properly handle the stream
      await for (final chunk in response) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        onProgress(receivedBytes, totalBytes);
      }

      // Make sure to close the sink
      await sink.flush();
      await sink.close();

      onComplete(file.path);
    } catch (e) {
      onError(e.toString());
      rethrow; // Optional: rethrow if you want to handle it in the calling code
    }
  }
}
