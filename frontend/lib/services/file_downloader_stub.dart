import 'dart:io';
import 'package:flutter/foundation.dart';

/// Desktop / Non-web implementation of file downloading
void downloadFileFromBytes(List<int> bytes, String filename, String mimeType) {
  try {
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    final downloadsDir = Directory('$home/Downloads');
    final targetDir = downloadsDir.existsSync() ? downloadsDir : Directory.current;
    final file = File('${targetDir.path}/$filename');
    file.writeAsBytesSync(bytes);
    debugPrint('File saved to: ${file.path}');
  } catch (e) {
    debugPrint('Failed to save file on desktop: $e');
  }
}

void downloadFileFromUrl(String url, String filename) {
  // On desktop, downloading from URL can open in browser
  debugPrint('Download requested from URL: $url');
}
