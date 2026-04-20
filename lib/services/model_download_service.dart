import 'dart:io';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;

import '../config/model_setup_constants.dart';
import '../models/voice_language.dart';
import 'model_file_service.dart';

class ModelDownloadService {
  ModelDownloadService({
    ModelFileService? modelFileService,
  }) : _modelFileService = modelFileService ?? ModelFileService();

  final ModelFileService _modelFileService;

  Future<int> checkAccess([String? accessToken]) async {
    try {
      final headers = <String, String>{};
      if (accessToken != null && accessToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $accessToken';
      }

      final response = await http.head(
        Uri.parse(ModelSetupConstants.modelUrl),
        headers: headers,
      );

      return response.statusCode;
    } catch (_) {
      return -1;
    }
  }

  Future<void> downloadVoskModel({
    required VoiceLanguage language,
    required void Function(double progress) onProgress,
  }) async {
    final archiveFile = await _modelFileService.getVoskArchiveFile(language.code);
    final targetDir = Directory(await _modelFileService.getModelDirectoryPath());

    IOSink? sink;

    try {
      final request = http.Request('GET', Uri.parse(language.voskModelUrl));
      final response = await request.send();

      if (response.statusCode != 200) {
        throw Exception(
          '${language.label} voice download failed with status ${response.statusCode}',
        );
      }

      final total = response.contentLength ?? 0;
      var received = 0;

      sink = archiveFile.openWrite();

      await for (final chunk in response.stream) {
        received += chunk.length;
        sink.add(chunk);

        if (total > 0) {
          onProgress(received / total);
        }
      }

      await sink.flush();
      await sink.close();
      sink = null;

      final size = await archiveFile.length();
      if (size < language.minimumArchiveBytes) {
        throw Exception('Downloaded ${language.label} voice archive is too small.');
      }

      final bytes = await archiveFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      for (final entry in archive) {
        final outputPath = '${targetDir.path}/${entry.name}';

        if (entry.isFile) {
          final outputFile = File(outputPath);
          await outputFile.parent.create(recursive: true);
          await outputFile.writeAsBytes(entry.content as List<int>);
        } else {
          await Directory(outputPath).create(recursive: true);
        }
      }

      final valid = await _modelFileService.hasValidVoskModel(language.code);
      if (!valid) {
        throw Exception(
          'Extracted ${language.label} voice model is invalid or incomplete.',
        );
      }

      try {
        await archiveFile.delete();
      } catch (_) {}
    } catch (e) {
      try {
        await sink?.flush();
      } catch (_) {}
      try {
        await sink?.close();
      } catch (_) {}

      await _modelFileService.deleteVoskIfExists(language.code);

      throw Exception(
        e is Exception
            ? e.toString().replaceFirst('Exception: ', '')
            : '${language.label} voice model download failed.',
      );
    }
  }
}
