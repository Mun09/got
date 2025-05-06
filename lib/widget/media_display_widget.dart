import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../util/util.dart';
import '../memory.dart';

class MediaDisplayWidget extends StatefulWidget {
  final Memory memory;
  final bool autoPlay;
  final bool showControls;

  const MediaDisplayWidget({
    Key? key,
    required this.memory,
    this.autoPlay = false,
    this.showControls = true,
  }) : super(key: key);

  @override
  State<MediaDisplayWidget> createState() => _MediaDisplayWidgetState();
}

class _MediaDisplayWidgetState extends State<MediaDisplayWidget> {
  VideoPlayerController? _controller;
  bool _isVideoInitialized = false;
  bool _isPlaying = false;
  bool _hasMediaContent = false;
  bool _isImageMemory = false;

  @override
  void initState() {
    super.initState();
    _checkMediaType();
  }

  void _checkMediaType() {
    if (!isMediaExist(widget.memory)) {
      setState(() => _hasMediaContent = false);
      return;
    }

    final isVideo = isVideoFile(widget.memory.filePath!);

    setState(() {
      _hasMediaContent = true;
      _isImageMemory = !isVideo;
    });

    if (isVideo) {
      _initializeVideo();
    }
  }

  void _initializeVideo() {
    if (widget.memory.filePath == null) return;

    _controller = VideoPlayerController.file(File(widget.memory.filePath!))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isVideoInitialized = true;
            _controller!.setLooping(true);

            if (widget.autoPlay) {
              _isPlaying = true;
              _controller!.play();
            }
          });
        }
      });
  }

  void _togglePlayPause() {
    if (_controller == null) return;

    setState(() {
      _isPlaying = !_isPlaying;
      _isPlaying ? _controller!.play() : _controller!.pause();
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasMediaContent) {
      // 미디어 파일이 없는 경우
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          color: Colors.grey[900],
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image_not_supported, size: 48, color: Colors.white54),
              SizedBox(height: 8),
              Text('미디어 파일 없음', style: TextStyle(color: Colors.white54)),
            ],
          ),
        ),
      );
    } else if (_isImageMemory) {
      // 이미지인 경우
      return Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Image.file(File(widget.memory.filePath!), fit: BoxFit.contain),
      );
    } else {
      // 비디오인 경우
      if (_isVideoInitialized && _controller != null) {
        return GestureDetector(
          onTap: _togglePlayPause,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
              if (!_isPlaying)
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.play_arrow, color: Colors.white, size: 40),
                ),
            ],
          ),
        );
      } else {
        return AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            color: Colors.black,
            child: Center(child: CircularProgressIndicator()),
          ),
        );
      }
    }
  }

  Widget buildVideoControls() {
    if (!_hasMediaContent ||
        _isImageMemory ||
        _controller == null ||
        !_isVideoInitialized) {
      return SizedBox();
    }

    return Container(
      color: Colors.black,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
            ),
            onPressed: _togglePlayPause,
          ),
          Expanded(
            child: VideoProgressIndicator(
              _controller!,
              allowScrubbing: true,
              colors: VideoProgressColors(
                playedColor: Colors.red,
                bufferedColor: Colors.grey.shade600,
                backgroundColor: Colors.grey.shade800,
              ),
              padding: EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ],
      ),
    );
  }
}
