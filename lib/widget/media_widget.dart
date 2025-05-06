// 미디어 프리뷰 위젯
import 'dart:io';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../util/util.dart';

class MediaPreviewWidget extends StatelessWidget {
  final XFile? file;
  final bool isVideoInitialized;
  final VideoPlayerController? videoPlayerController;
  final bool isMuted;
  final VoidCallback onTap;
  final VoidCallback onMuteToggle;

  const MediaPreviewWidget({
    Key? key,
    required this.file,
    required this.isVideoInitialized,
    this.videoPlayerController,
    required this.isMuted,
    required this.onTap,
    required this.onMuteToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child:
              file != null
                  ? (isVideoInitialized &&
                          videoPlayerController != null &&
                          videoPlayerController!.value.isInitialized
                      ? _buildVideoPlayer()
                      : isImageFile(file!.path)
                      ? Image.file(File(file!.path), fit: BoxFit.cover)
                      : Center(child: CircularProgressIndicator()))
                  : _buildAddMediaPlaceholder(),
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    return Stack(
      alignment: Alignment.center,
      children: [
        AspectRatio(
          aspectRatio: videoPlayerController!.value.aspectRatio,
          child: VideoPlayer(videoPlayerController!),
        ),
        Positioned(
          bottom: 10,
          right: 10,
          child: GestureDetector(
            onTap: onMuteToggle,
            child: Container(
              padding: EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                isMuted ? Icons.volume_off : Icons.volume_up,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddMediaPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_a_photo, size: 48, color: Colors.grey),
          SizedBox(height: 8),
          Text('사진 또는 동영상 추가하기'),
        ],
      ),
    );
  }
}
