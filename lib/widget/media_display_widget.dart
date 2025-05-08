import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../util/util.dart';
import '../models/memory.dart';

class MediaDisplayWidget extends StatefulWidget {
  final Memory memory;
  final bool autoPlay;
  final bool showControls;

  const MediaDisplayWidget({
    super.key,
    required this.memory,
    this.autoPlay = false,
    this.showControls = true,
  });

  @override
  State<MediaDisplayWidget> createState() => _MediaDisplayWidgetState();
}

class _MediaDisplayWidgetState extends State<MediaDisplayWidget> {
  VideoPlayerController? _controller;
  bool _isVideoInitialized = false;
  bool _isPlaying = false;
  bool _hasMediaContent = false;
  int _currentMediaIndex = 0; // 현재 표시 중인 미디어 인덱스

  // 현재 표시 중인 미디어가 이미지인지 여부
  bool get _isCurrentMediaImage {
    if (!_hasMediaContent || widget.memory.filePaths.isEmpty) return false;
    return !isVideoFile(widget.memory.filePaths[_currentMediaIndex]);
  }

  // 현재 선택된 미디어 경로
  String? get _currentMediaPath {
    if (!_hasMediaContent ||
        _currentMediaIndex >= widget.memory.filePaths.length)
      return null;
    return widget.memory.filePaths[_currentMediaIndex];
  }

  @override
  void initState() {
    super.initState();
    _checkMediaContent();
  }

  void _checkMediaContent() {
    final hasMedia = widget.memory.hasMedia;

    setState(() {
      _hasMediaContent = hasMedia;
      _currentMediaIndex = 0;
    });

    if (hasMedia && !_isCurrentMediaImage) {
      _initializeVideo();
    }
  }

  void _initializeVideo() {
    if (_currentMediaPath == null) return;

    _controller?.dispose();
    _isVideoInitialized = false;

    _controller = VideoPlayerController.file(File(_currentMediaPath!))
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

  void _showNextMedia() {
    if (!_hasMediaContent || widget.memory.filePaths.length <= 1) return;

    final nextIndex = (_currentMediaIndex + 1) % widget.memory.filePaths.length;
    _showMediaAtIndex(nextIndex);
  }

  void _showPreviousMedia() {
    if (!_hasMediaContent || widget.memory.filePaths.length <= 1) return;

    final prevIndex =
        _currentMediaIndex == 0
            ? widget.memory.filePaths.length - 1
            : _currentMediaIndex - 1;
    _showMediaAtIndex(prevIndex);
  }

  void _showMediaAtIndex(int index) {
    if (index < 0 || index >= widget.memory.filePaths.length) return;

    // 비디오 재생 중이면 중지
    if (_controller != null) {
      _controller!.pause();
      _isPlaying = false;
    }

    setState(() {
      _currentMediaIndex = index;
    });

    if (!_isCurrentMediaImage) {
      _initializeVideo();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasMediaContent || widget.memory.filePaths.isEmpty) {
      return _buildNoMediaUI();
    }

    return Column(
      children: [
        _buildMediaContent(),
        if (widget.showControls && widget.memory.filePaths.length > 1)
          _buildMediaSwitcher(),
        if (widget.showControls && !_isCurrentMediaImage) buildVideoControls(),
      ],
    );
  }

  Widget _buildMediaContent() {
    if (_isCurrentMediaImage) {
      // 이미지 표시
      return Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Image.file(
          File(_currentMediaPath!),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey[300],
              child: Icon(
                Icons.broken_image,
                size: 50,
                color: Colors.grey[600],
              ),
            );
          },
        ),
      );
    } else {
      // 비디오 표시
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

  Widget _buildMediaSwitcher() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left),
            onPressed: _showPreviousMedia,
          ),
          Text('${_currentMediaIndex + 1}/${widget.memory.filePaths.length}'),
          IconButton(
            icon: Icon(Icons.chevron_right),
            onPressed: _showNextMedia,
          ),
        ],
      ),
    );
  }

  Widget _buildNoMediaUI() {
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
  }

  Widget buildVideoControls() {
    if (!_hasMediaContent ||
        _isCurrentMediaImage ||
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
