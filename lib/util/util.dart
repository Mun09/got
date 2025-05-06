import 'dart:io';

import 'package:intl/intl.dart';

import '../memory.dart';

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
  final bool hasFilePath =
      memory.filePath != null && memory.filePath!.isNotEmpty;
  return hasFilePath && File(memory.filePath!).existsSync();
}

String formatDate(DateTime dateTime) {
  return DateFormat('yyyy년 MM월 dd일 HH:mm').format(dateTime);
}
