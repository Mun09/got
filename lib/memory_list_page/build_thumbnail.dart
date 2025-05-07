import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/memory.dart';
import '../util/util.dart';

Widget buildThumbnail(Memory memory) {
  if (memory.filePath == null || memory.filePath!.isEmpty) {
    return Container(
      color: Colors.grey[200],
      child: Icon(Icons.image_not_supported, color: Colors.grey[500], size: 48),
    );
  }

  final file = File(memory.filePath!);
  if (!file.existsSync()) {
    return Container(
      color: Colors.grey[200],
      child: Icon(Icons.broken_image, color: Colors.grey[500], size: 48),
    );
  }

  final isVideo = isVideoFile(memory.filePath!);

  if (isVideo) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Icon(
          Icons.play_circle_outline,
          color: Colors.white.withOpacity(0.7),
          size: 48,
        ),
      ),
    );
  } else {
    return Image.file(file, fit: BoxFit.cover);
  }
}
