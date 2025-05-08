import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/memory.dart';

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

// bool isMediaExist(Memory memory) {
//   final bool hasFilePath = memory.hasMedia;
//   return hasFilePath && File(memory.filePaths).existsSync();
// }

String formatDate(DateTime dateTime) {
  return DateFormat('yyyy년 MM월 dd일 HH:mm').format(dateTime);
}

AlertDialog alertDialog(
  String text,
  IconData showIcon,
  Color? textColor,
  Color? iconColor,
) {
  return AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(showIcon, color: iconColor ?? Colors.green, size: 60),
        SizedBox(height: 16),
        Text(
          text,
          style: TextStyle(
            fontFamily: 'dosSamemul',
            fontWeight: FontWeight.w800,
            color: textColor ?? Colors.black,
          ),
        ),
      ],
    ),
  );
}
