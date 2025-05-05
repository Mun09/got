import 'dart:io';

import 'memory.dart';

bool isImageFile(String path) {
  final lowerPath = path.toLowerCase();
  return lowerPath.endsWith('.jpg') ||
      lowerPath.endsWith('.jpeg') ||
      lowerPath.endsWith('.png') ||
      lowerPath.endsWith('.gif') ||
      lowerPath.endsWith('.webp');
}

bool isVideoFile(String path) {
  final lowerPath = path.toLowerCase();
  return lowerPath.endsWith('.mp4') ||
      lowerPath.endsWith('.mov') ||
      lowerPath.endsWith('.avi') ||
      lowerPath.endsWith('.wmv') ||
      lowerPath.endsWith('.flv') ||
      lowerPath.endsWith('.mkv') ||
      lowerPath.endsWith('.webm');
}

bool isMediaExist(Memory memory) {
  final bool hasVideoPath =
      memory.videoPath != null && memory.videoPath!.isNotEmpty;
  final bool videoExists = hasVideoPath && File(memory.videoPath!).existsSync();
  return videoExists;
}
