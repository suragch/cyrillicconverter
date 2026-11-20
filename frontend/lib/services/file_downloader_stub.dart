import 'dart:io';
import 'package:flutter/foundation.dart';

/// Desktop / Non-web implementation of file downloading.
/// Returns true if the file was written successfully, false otherwise.
bool downloadFileFromBytes(List<int> bytes, String filename, String mimeType) {
  try {
    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    Directory targetDir = Directory.current;
    if (home != null && home.isNotEmpty) {
      final downloadsDir = Directory('$home/Downloads');
      if (downloadsDir.existsSync()) {
        targetDir = downloadsDir;
      }
    }
    final file = File('${targetDir.path}/$filename');
    file.writeAsBytesSync(bytes);
    debugPrint('File saved to: ${file.path}');
    return true;
  } catch (e) {
    debugPrint('Failed to save file on desktop: $e');
    return false;
  }
}

void downloadFileFromUrl(String url, String filename) {
  // On desktop, downloading from URL can open in browser
  debugPrint('Download requested from URL: $url');
}
