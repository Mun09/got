import 'dart:io';
import 'package:flutter/material.dart';
import 'package:got/save_page.dart';
import 'package:got/util.dart';
import 'package:video_player/video_player.dart';

import 'memory.dart';
import 'memory_service.dart';

class MemoryListPage extends StatefulWidget {
  const MemoryListPage({Key? key}) : super(key: key);

  @override
  State<MemoryListPage> createState() => _MemoryListPageState();
}

class _MemoryListPageState extends State<MemoryListPage> {
  List<Memory> _memories = [];
  bool _isLoading = true;
  final _memoryService = MemoryService();

  @override
  void initState() {
    super.initState();
    _loadMemories();
  }

  // 저장된 메모리 목록 불러오기
  Future<void> _loadMemories() async {
    setState(() => _isLoading = true);

    try {
      final memories = await _memoryService.getMemories();
      setState(() {
        _memories = memories;
        _isLoading = false;
      });
    } catch (e) {
      print('메모리 목록 불러오기 오류: $e');
      setState(() => _isLoading = false);
    }
  }

  // 메모리 삭제 기능
  Future<void> _deleteMemory(Memory memory) async {
    try {
      await _memoryService.deleteMemory(memory.id);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('메모리가 삭제되었습니다')));
      _loadMemories(); // 목록 새로고침
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('메모리 삭제 중 오류가 발생했습니다: $e')));
    }
  }

  // 날짜 형식화
  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('메모리 목록'),
        backgroundColor: Colors.white,
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _loadMemories),
        ],
      ),
      body: Stack(
        children: [
          // 스크롤 가능한 메모리 목록
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : _memories.isEmpty
              ? Center(child: Text('저장된 메모리가 없습니다'))
              : ListView.builder(
                // 하단 버튼 영역만큼 패딩 추가
                padding: EdgeInsets.only(bottom: 80),
                itemCount: _memories.length,
                itemBuilder: (context, index) {
                  final memory = _memories[index];
                  bool videoExists = isMediaExist(memory);
                  final bool hasVideoPath =
                      memory.videoPath != null && memory.videoPath!.isNotEmpty;

                  // 파일 크기 계산 (비디오가 존재할 경우에만)
                  final String fileSize =
                      videoExists
                          ? '${(File(memory.videoPath!).lengthSync() / 1024 / 1024).toStringAsFixed(2)} MB'
                          : '';

                  return InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => MemoryDetailPage(memory: memory),
                        ),
                      );
                    },
                    child: Card(
                      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            leading: Icon(
                              hasVideoPath
                                  ? memory.videoPath!.toLowerCase().endsWith(
                                        '.mp4',
                                      )
                                      ? Icons.video_file
                                      : Icons.image
                                  : Icons.videocam_off,
                              size: 36,
                            ),
                            title: Text(_formatDate(memory.createdAt)),
                            subtitle:
                                videoExists
                                    ? Text(fileSize)
                                    : Text(
                                      '미디어 파일 없음',
                                      style: TextStyle(color: Colors.red),
                                    ),
                            trailing: IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed:
                                  () => showDialog(
                                    context: context,
                                    builder:
                                        (context) => AlertDialog(
                                          title: Text('메모리 삭제'),
                                          content: Text('이 메모리를 삭제하시겠습니까?'),
                                          actions: [
                                            TextButton(
                                              onPressed:
                                                  () => Navigator.pop(context),
                                              child: Text('취소'),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                Navigator.pop(context);
                                                _deleteMemory(memory);
                                              },
                                              child: Text(
                                                '삭제',
                                                style: TextStyle(
                                                  color: Colors.red,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                  ),
                            ),
                          ),
                          if (memory.memo.isNotEmpty)
                            Padding(
                              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '메모',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    memory.memo,
                                    style: TextStyle(fontSize: 14),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),

          // 하단에 고정된 메모 생성 버튼
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 5,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => FileSavePage()),
                  ).then((_) {
                    // 저장 페이지에서 돌아올 때 메모리 목록 새로고침
                    _loadMemories();
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  '새 메모리 생성',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MemoryDetailPage extends StatefulWidget {
  final Memory memory; // Memory 객체 필드 추가

  const MemoryDetailPage({Key? key, required this.memory}) : super(key: key);

  @override
  State<MemoryDetailPage> createState() => _MemoryDetailPageState();
}

class _MemoryDetailPageState extends State<MemoryDetailPage> {
  VideoPlayerController? _controller;
  bool _isVideoInitialized = false;
  bool _isImageMemory = false;
  bool _hasMediaContent = false;

  @override
  void initState() {
    super.initState();
    _checkMediaType();
  }

  void _checkMediaType() {
    // videoPath가 null이 아닌지 먼저 확인
    if (widget.memory.videoPath == null || widget.memory.videoPath!.isEmpty) {
      _hasMediaContent = false;
      return;
    }

    final file = File(widget.memory.videoPath!);

    if (file.existsSync()) {
      _hasMediaContent = true;

      // 확장자로 파일 유형 확인
      final extension = widget.memory.videoPath!.split('.').last.toLowerCase();
      if (['mp4', 'mov', '3gp', 'avi'].contains(extension)) {
        _isImageMemory = false;
        _initializeVideo();
      } else if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension)) {
        _isImageMemory = true;
      }
    } else {
      _hasMediaContent = false;
    }
  }

  void _initializeVideo() {
    // null 체크 추가
    if (widget.memory.videoPath == null) return;

    _controller = VideoPlayerController.file(File(widget.memory.videoPath!))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isVideoInitialized = true;
          });
        }
      });
  }

  @override
  void dispose() {
    if (_isVideoInitialized) {
      _controller?.dispose();
    }
    super.dispose();
  }

  Widget _buildMediaPlayer() {
    if (!_hasMediaContent) {
      // 미디어 파일이 없는 경우
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          color: Colors.grey[900],
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.videocam_off, color: Colors.white54, size: 64),
                SizedBox(height: 16),
                Text(
                  '미디어 파일 없음',
                  style: TextStyle(color: Colors.white54, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      );
    } else if (_isImageMemory) {
      // 이미지인 경우
      return Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.5,
        ),
        child: Image.file(File(widget.memory.videoPath!), fit: BoxFit.contain),
      );
    } else {
      // 비디오인 경우
      if (_isVideoInitialized && _controller != null) {
        return AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(_controller!),
              if (!_controller!.value.isPlaying)
                IconButton(
                  icon: Icon(Icons.play_arrow, size: 50, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _controller!.play();
                    });
                  },
                ),
            ],
          ),
        );
      } else {
        return AspectRatio(
          aspectRatio: 16 / 9,
          child: Center(child: CircularProgressIndicator()),
        );
      }
    }
  }

  Widget _buildVideoControls() {
    if (!_hasMediaContent || _isImageMemory || _controller == null) {
      return SizedBox(); // 이미지나 미디어 없는 경우 컨트롤 표시 안함
    }

    if (_isVideoInitialized) {
      return Container(
        color: Colors.black,
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: Icon(
                _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  _controller!.value.isPlaying
                      ? _controller!.pause()
                      : _controller!.play();
                });
              },
            ),
            Expanded(
              child: VideoProgressIndicator(
                _controller!,
                allowScrubbing: true,
                colors: VideoProgressColors(
                  playedColor: Colors.white,
                  bufferedColor: Colors.grey.shade700,
                  backgroundColor: Colors.grey.shade900,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('메모리 상세'),
        actions: [
          if (_hasMediaContent)
            IconButton(
              icon: Icon(
                _isImageMemory ? Icons.image : Icons.videocam,
                color: Colors.white,
              ),
              onPressed: null, // 단순 표시용
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 미디어 플레이어 (비디오 또는 이미지)
            _buildMediaPlayer(),

            // 비디오 컨트롤러
            _buildVideoControls(),

            // 메모 표시
            if (widget.memory.memo.isNotEmpty)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '메모',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(widget.memory.memo, style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
