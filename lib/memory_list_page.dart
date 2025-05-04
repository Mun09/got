import 'dart:io';
import 'package:flutter/material.dart';
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
        backgroundColor: Colors.black,
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _loadMemories),
        ],
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : _memories.isEmpty
              ? Center(child: Text('저장된 메모리가 없습니다'))
              : ListView.builder(
                itemCount: _memories.length,
                itemBuilder: (context, index) {
                  final memory = _memories[index];
                  final File videoFile = File(memory.videoPath);
                  final bool videoExists = videoFile.existsSync();

                  return Card(
                    margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          leading: Icon(Icons.video_file, size: 36),
                          title: Text(_formatDate(memory.createdAt)),
                          subtitle:
                              videoExists
                                  ? Text(
                                    '${(videoFile.lengthSync() / 1024 / 1024).toStringAsFixed(2)} MB',
                                  )
                                  : Text(
                                    '비디오 파일 없음',
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
                          onTap:
                              videoExists
                                  ? () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) => MemoryDetailPage(
                                              memory: memory,
                                            ),
                                      ),
                                    );
                                  }
                                  : null,
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
                  );
                },
              ),
    );
  }
}

// 메모리 상세 페이지
class MemoryDetailPage extends StatefulWidget {
  final Memory memory;

  const MemoryDetailPage({Key? key, required this.memory}) : super(key: key);

  @override
  State<MemoryDetailPage> createState() => _MemoryDetailPageState();
}

class _MemoryDetailPageState extends State<MemoryDetailPage> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  void _initializeVideo() {
    final file = File(widget.memory.videoPath);
    if (file.existsSync()) {
      _controller = VideoPlayerController.file(file)
        ..initialize().then((_) {
          setState(() {
            _isInitialized = true;
          });
        });
    }
  }

  @override
  void dispose() {
    if (_isInitialized) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, title: Text('메모리 상세')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 비디오 플레이어
            if (_isInitialized)
              AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(_controller),
                    if (!_controller.value.isPlaying)
                      IconButton(
                        icon: Icon(
                          Icons.play_arrow,
                          size: 50,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          setState(() {
                            _controller.play();
                          });
                        },
                      ),
                  ],
                ),
              )
            else
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Center(child: CircularProgressIndicator()),
              ),

            // 컨트롤 바
            if (_isInitialized)
              Container(
                color: Colors.black,
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(
                        _controller.value.isPlaying
                            ? Icons.pause
                            : Icons.play_arrow,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        setState(() {
                          _controller.value.isPlaying
                              ? _controller.pause()
                              : _controller.play();
                        });
                      },
                    ),
                    Expanded(
                      child: VideoProgressIndicator(
                        _controller,
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
              ),

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
