import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../memory_list_page/video_player_item.dart';
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
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  final PageController _pageController = PageController();
  int _currentPage = 0;

  void _showFullScreenMedia(BuildContext context, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => FullScreenMediaViewer(
              mediaPaths: widget.memory.filePaths,
              initialIndex: initialIndex,
              showControls: widget.showControls,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 메모리에 저장된 미디어 파일들
    final mediaPaths = widget.memory.filePaths;

    if (mediaPaths.isEmpty) {
      return Container(
        height: 300,
        color: Colors.grey[300],
        child: Center(child: Text('미디어 없음')),
      );
    }

    return Column(
      children: [
        Container(
          height: 300, // 높이 조정
          child: PageView.builder(
            controller: _pageController,
            itemCount: mediaPaths.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              final path = mediaPaths[index];
              final isVideo = isVideoFile(path);
              if (isVideo) {
                // 비디오일 경우 VideoPlayerItem을 사용하되, 전체 화면 콜백 전달
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayerItem(
                      videoPath: path,
                      showControls: widget.showControls,
                    ),
                    // 투명한 오버레이로 전체화면 전환 제스처 캡처
                    Positioned(
                      top: 16,
                      right: 16,
                      child: GestureDetector(
                        onTap: () => _showFullScreenMedia(context, index),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.black38,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.fullscreen,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              } else {
                // 이미지일 경우 기존 방식대로 전체화면 전환
                return GestureDetector(
                  onTap: () => _showFullScreenMedia(context, index),
                  child: Image.file(File(path), fit: BoxFit.cover),
                );
              }
            },
          ),
        ),
        // 페이지 인디케이터 (선택사항)
        if (mediaPaths.length > 1)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                mediaPaths.length,
                (index) => Container(
                  margin: EdgeInsets.symmetric(horizontal: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        _currentPage == index ? Colors.blue : Colors.grey[300],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// 전체화면 미디어 뷰어 위젯
class FullScreenMediaViewer extends StatefulWidget {
  final List<String> mediaPaths;
  final int initialIndex;
  final bool showControls;

  const FullScreenMediaViewer({
    super.key,
    required this.mediaPaths,
    required this.initialIndex,
    this.showControls = true,
  });

  @override
  State<FullScreenMediaViewer> createState() => _FullScreenMediaViewerState();
}

class _FullScreenMediaViewerState extends State<FullScreenMediaViewer> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${_currentPage + 1}/${widget.mediaPaths.length}',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: PageView.builder(
          controller: _pageController,
          itemCount: widget.mediaPaths.length,
          onPageChanged: (index) {
            setState(() {
              _currentPage = index;
            });
          },
          itemBuilder: (context, index) {
            final path = widget.mediaPaths[index];
            final isVideo = isVideoFile(path);

            return isVideo ? _buildVideoViewer(path) : _buildImageViewer(path);
          },
        ),
      ),
    );
  }

  Widget _buildVideoViewer(String path) {
    return Center(
      child: AspectRatioVideoPlayer(
        videoPath: path,
        showControls: widget.showControls,
      ),
    );
  }

  Widget _buildImageViewer(String path) {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 3.0,
      child: Center(child: Image.file(File(path), fit: BoxFit.contain)),
    );
  }
}

class AspectRatioVideoPlayer extends StatefulWidget {
  final String videoPath;
  final bool showControls;

  const AspectRatioVideoPlayer({
    super.key,
    required this.videoPath,
    this.showControls = true,
  });

  @override
  State<AspectRatioVideoPlayer> createState() => _AspectRatioVideoPlayerState();
}

class _AspectRatioVideoPlayerState extends State<AspectRatioVideoPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isControlsVisible = false;
  Timer? _controlsTimer;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  void _initializeVideoPlayer() {
    _controller = VideoPlayerController.file(File(widget.videoPath))
      ..initialize()
          .then((_) {
            if (mounted) {
              setState(() {
                _isInitialized = true;
                // 자동 재생
                _controller.play();
                _isPlaying = true;
                _controller.setLooping(true);
              });
            }
          })
          .catchError((error) {
            print("비디오 초기화 오류: $error");
          });

    _controller.addListener(() {
      if (mounted) {
        setState(() {
          _isPlaying = _controller.value.isPlaying;
        });
      }
    });
  }

  void _togglePlayPause() {
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
    _showControls();
  }

  void _showControls() {
    setState(() {
      _isControlsVisible = true;
    });

    // 기존 타이머 취소
    _controlsTimer?.cancel();

    // 3초 후에 컨트롤 자동 숨김
    _controlsTimer = Timer(Duration(seconds: 3), () {
      if (mounted && _isPlaying) {
        setState(() {
          _isControlsVisible = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Container(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

    // 화면 크기를 가져옵니다
    final size = MediaQuery.of(context).size;
    final videoRatio = _controller.value.aspectRatio;

    // 화면에 맞는 최적의 비디오 크기 계산
    double width, height;
    if (size.width > size.height * videoRatio) {
      // 화면이 비디오보다 가로로 더 넓은 경우
      height = size.height;
      width = height * videoRatio;
    } else {
      // 화면이 비디오보다 세로로 더 높은 경우
      width = size.width;
      height = width / videoRatio;
    }

    return Center(
      child: GestureDetector(
        onTap: _togglePlayPause,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 비디오 플레이어
            SizedBox(
              width: width,
              height: height,
              child: VideoPlayer(_controller),
            ),

            // 반투명 컨트롤 레이어 (탭할 때만 표시)
            if (_isControlsVisible || !_isPlaying)
              Container(
                width: width,
                height: height,
                color: Colors.black.withOpacity(0.3),
              ),

            // 재생/일시정지 아이콘
            if (_isControlsVisible || !_isPlaying)
              GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              ),

            // 하단 컨트롤 바
            if (widget.showControls && _isControlsVisible)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  width: width,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  color: Colors.black38,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 비디오 진행 표시줄
                      VideoProgressIndicator(
                        _controller,
                        allowScrubbing: true,
                        colors: VideoProgressColors(
                          playedColor: Colors.red,
                          bufferedColor: Colors.grey.shade600,
                          backgroundColor: Colors.grey.shade800,
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 8,
                        ),
                      ),

                      // 컨트롤 버튼 및 시간 표시
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // 재생/일시정지 버튼
                          IconButton(
                            icon: Icon(
                              _isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.white,
                              size: 32,
                            ),
                            onPressed: _togglePlayPause,
                          ),

                          // 비디오 시간 정보
                          ValueListenableBuilder(
                            valueListenable: _controller,
                            builder: (context, VideoPlayerValue value, child) {
                              final position = value.position;
                              final duration = value.duration;
                              return Text(
                                '${_formatDuration(position)} / ${_formatDuration(duration)}',
                                style: TextStyle(color: Colors.white),
                              );
                            },
                          ),
                          // 우측 전체화면 버튼
                          IconButton(
                            icon: Icon(
                              Icons.fullscreen,
                              color: Colors.white,
                              size: 32,
                            ),
                            onPressed: () => _enterFullScreen(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            // 독립적인 전체화면 버튼 (항상 표시)
            // if (!_isControlsVisible)
            //   Positioned(
            //     top: 16,
            //     right: 16,
            //     child: GestureDetector(
            //       onTap: () => _enterFullScreen(context),
            //       child: Container(
            //         width: 40,
            //         height: 40,
            //         decoration: BoxDecoration(
            //           color: Colors.black38,
            //           shape: BoxShape.circle,
            //         ),
            //         child: Icon(
            //           Icons.fullscreen,
            //           color: Colors.white,
            //           size: 24,
            //         ),
            //       ),
            //     ),
            //   ),
          ],
        ),
      ),
    );
  }

  void _enterFullScreen(BuildContext context) {
    // 현재 위치를 저장하여 전체화면에서도 같은 위치부터 재생
    final position = _controller.value.position;
    final isPlaying = _controller.value.isPlaying;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => FullScreenVideoPlayer(
              videoPath: widget.videoPath,
              startPosition: position,
              autoPlay: isPlaying,
            ),
      ),
    );
  }

  // 시간 포맷팅 헬퍼 메서드
  String _formatDuration(Duration duration) {
    String minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    String seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class FullScreenVideoPlayer extends StatefulWidget {
  final String videoPath;
  final Duration startPosition;
  final bool autoPlay;

  const FullScreenVideoPlayer({
    Key? key,
    required this.videoPath,
    required this.startPosition,
    this.autoPlay = true,
  }) : super(key: key);

  @override
  State<FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<FullScreenVideoPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isControlsVisible = true;
  Timer? _controlsTimer;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
    // 가로 모드로 전환
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // 전체화면 모드 활성화
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _initializeVideoPlayer() {
    _controller = VideoPlayerController.file(File(widget.videoPath))
      ..initialize()
          .then((_) {
            if (mounted) {
              setState(() {
                _isInitialized = true;
                // 저장된 위치로 이동
                _controller.seekTo(widget.startPosition);
                // 자동 재생 설정에 따라 재생
                if (widget.autoPlay) {
                  _controller.play();
                  _isPlaying = true;
                }
                _controller.setLooping(true);
              });
            }
          })
          .catchError((error) {
            print("비디오 초기화 오류: $error");
          });

    _controller.addListener(() {
      if (mounted) {
        setState(() {
          _isPlaying = _controller.value.isPlaying;
        });
      }
    });

    // 컨트롤 자동 숨김 처리
    _startHideControlsTimer();
  }

  void _togglePlayPause() {
    if (_controller.value.isPlaying) {
      _controller.pause();
      print("비디오 일시정지");
    } else {
      _controller.play();
    }
    _showControls();
  }

  void _showControls() {
    setState(() {
      _isControlsVisible = true;
    });
    _startHideControlsTimer();
  }

  void _startHideControlsTimer() {
    _controlsTimer?.cancel();

    if (_isPlaying) {
      _controlsTimer = Timer(Duration(seconds: 3), () {
        if (mounted && _isPlaying) {
          setState(() {
            _isControlsVisible = false;
          });
        }
      });
    }
  }

  void _exitFullScreen() {
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _controller.dispose();
    _controlsTimer?.cancel();
    // 세로 모드 복원
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    // 시스템 UI 복원
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () {
          // 화면 터치 시 컨트롤 표시 및 재생/정지 토글
          _togglePlayPause();
          // _showControls();
        },
        child: Stack(
          children: [
            // 비디오 플레이어
            Center(
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
            ),

            // 반투명 컨트롤 레이어
            if (_isControlsVisible || !_isPlaying)
              Container(color: Colors.black.withOpacity(0.3)),

            // 컨트롤 바
            if (_isControlsVisible || !_isPlaying) ...[
              // 중앙 재생/일시정지 버튼
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              ),

              // 상단 컨트롤 바 (나가기 버튼)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.black26,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: _exitFullScreen,
                      ),
                      Text(
                        '전체화면',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      IconButton(
                        icon: Icon(Icons.fullscreen_exit, color: Colors.white),
                        onPressed: _exitFullScreen,
                      ),
                    ],
                  ),
                ),
              ),

              // 하단 컨트롤 바
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.all(16),
                  color: Colors.black26,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 비디오 진행 표시줄
                      VideoProgressIndicator(
                        _controller,
                        allowScrubbing: true,
                        colors: VideoProgressColors(
                          playedColor: Colors.red,
                          bufferedColor: Colors.grey.shade600,
                          backgroundColor: Colors.grey.shade800,
                        ),
                      ),
                      SizedBox(height: 8),

                      // 시간 및 컨트롤 버튼
                      Row(
                        children: [
                          // 재생/일시정지 버튼
                          IconButton(
                            icon: Icon(
                              _isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.white,
                            ),
                            onPressed: _togglePlayPause,
                          ),
                          SizedBox(width: 8),

                          // 시간 표시
                          ValueListenableBuilder(
                            valueListenable: _controller,
                            builder: (context, VideoPlayerValue value, child) {
                              return Text(
                                '${_formatDuration(value.position)} / ${_formatDuration(value.duration)}',
                                style: TextStyle(color: Colors.white),
                              );
                            },
                          ),

                          Spacer(),

                          // 전체화면 나가기 버튼
                          IconButton(
                            icon: Icon(
                              Icons.fullscreen_exit,
                              color: Colors.white,
                            ),
                            onPressed: _exitFullScreen,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 시간 포맷팅 헬퍼 메서드
  String _formatDuration(Duration duration) {
    String minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    String seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
