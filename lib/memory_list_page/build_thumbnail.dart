import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_compress/video_compress.dart';

import '../models/memory.dart';
import '../util/util.dart';

// 동영상에서 썸네일을 생성하고 캐시
final Map<String, String> _thumbnailCache = {};

Future<Widget> buildThumbnail(Memory memory) async {
  // 미디어가 없는 경우
  if (!memory.hasMedia) {
    return Container(
      color: Colors.grey[200],
      child: Icon(Icons.image_not_supported, color: Colors.grey[500], size: 48),
    );
  }

  // 이미지 파일 먼저 찾기
  String? thumbnailPath;
  bool isVideo = true;

  // 우선 이미지 파일을 찾아봄
  for (String filePath in memory.filePaths) {
    if (!isVideoFile(filePath)) {
      thumbnailPath = filePath;
      isVideo = false;
      break;
    }
  }

  // 이미지가 없으면 첫 번째 동영상 사용
  if (thumbnailPath == null && memory.filePaths.isNotEmpty) {
    thumbnailPath = memory.filePaths.first;

    // 캐시에 있는지 확인
    if (_thumbnailCache.containsKey(thumbnailPath)) {
      thumbnailPath = _thumbnailCache[thumbnailPath];
      isVideo = false; // 썸네일은 이미지로 취급
    } else {
      try {
        // 동영상에서 썸네일 생성
        final thumbnailFile = await VideoCompress.getFileThumbnail(
          thumbnailPath,
          quality: 50,
          position: -1, // -1은 자동으로 중간 지점에서 가져옴
        );

        if (thumbnailFile.path.isNotEmpty) {
          _thumbnailCache[thumbnailPath] = thumbnailFile.path;
          thumbnailPath = thumbnailFile.path;
          isVideo = false; // 썸네일은 이미지로 취급
        }
      } catch (e) {
        print('썸네일 생성 오류: $e');
        // 오류 발생 시 기본 비디오 아이콘으로 표시
      }
    }
  }

  // 파일이 존재하는지 확인
  final file = File(thumbnailPath!);
  if (!file.existsSync()) {
    return Container(
      color: Colors.grey[200],
      child: Icon(Icons.broken_image, color: Colors.grey[500], size: 48),
    );
  }

  // 썸네일 생성에 실패했거나 원본 비디오 사용 시 아이콘 표시
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
    // 이미지인 경우 그대로 표시
    return Image.file(file, fit: BoxFit.cover);
  }
}

// FutureBuilder를 사용하기 위한 래퍼 위젯
class ThumbnailWidget extends StatelessWidget {
  final Memory memory;

  const ThumbnailWidget({super.key, required this.memory});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: buildThumbnail(memory),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData) {
          return snapshot.data!;
        } else {
          return Container(
            color: Colors.grey[300],
            child: Center(child: CircularProgressIndicator()),
          );
        }
      },
    );
  }
}
