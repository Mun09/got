import 'dart:io';
import 'package:flutter/material.dart';
import 'package:got/save_page.dart';
import 'package:got/util/util.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import 'models/memory.dart';
import 'memory_detail_page.dart';
import 'sevices/memory_service.dart';

class MemoryListPage extends StatefulWidget {
  const MemoryListPage({Key? key}) : super(key: key);

  @override
  State<MemoryListPage> createState() => _MemoryListPageState();
}

class _MemoryListPageState extends State<MemoryListPage> {
  // 선택 모드 관리를 위한 상태 변수
  bool _isSelectionMode = false;
  Set<Memory> _selectedMemories = {};

  @override
  void initState() {
    super.initState();
    // initState에서 Provider를 통해 서비스 접근 및 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<MemoryService>(context, listen: false).loadMemories();
    });
  }

  // 메모리 삭제 기능 - 이제 Provider를 통해 처리
  Future<void> _deleteMemory(Memory memory) async {
    try {
      await Provider.of<MemoryService>(
        context,
        listen: false,
      ).deleteMemory(memory.id);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('기록이 삭제되었습니다'),
          backgroundColor: Colors.grey[800],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('삭제 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.grey[800],
        ),
      );
    }
  }

  // 선택한 메모리 삭제
  Future<void> _deleteSelectedMemories() async {
    if (_selectedMemories.isEmpty) return;

    final count = _selectedMemories.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.white,
            title: Text('삭제 확인'),
            content: Text('선택한 ${count}개의 항목을 삭제하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('취소', style: TextStyle(color: Colors.grey[800])),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('삭제', style: TextStyle(color: Colors.grey[800])),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    int successCount = 0;
    int failCount = 0;
    final memoryService = Provider.of<MemoryService>(context, listen: false);

    // 선택된 메모리 복사본 생성
    final memoriesToDelete = Set<Memory>.from(_selectedMemories);

    // 선택 모드 종료
    setState(() {
      _isSelectionMode = false;
      _selectedMemories.clear();
    });

    // 삭제 작업 실행
    for (final memory in memoriesToDelete) {
      try {
        await memoryService.deleteMemory(memory.id);
        successCount++;
      } catch (e) {
        failCount++;
        print('삭제 실패: ${memory.id}, 오류: $e');
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${successCount}개 항목 삭제 완료' +
                (failCount > 0 ? ', ${failCount}개 실패' : ''),
          ),
          backgroundColor: Colors.grey[800],
        ),
      );
    }
  }

  // 선택 모드 토글
  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedMemories.clear();
      }
    });
  }

  // 항목 선택 토글
  void _toggleMemorySelection(Memory memory) {
    setState(() {
      if (_selectedMemories.contains(memory)) {
        _selectedMemories.remove(memory);
        // 선택된 항목이 없으면 선택 모드 종료
        if (_selectedMemories.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedMemories.add(memory);
      }
    });
  }

  // 새 기록 추가 화면으로 이동
  void _navigateToSavePage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => FileSavePage()),
    );

    if (result == true) {
      // 새 기록이 저장되었을 때 자동으로 업데이트됨 (Provider 사용으로 수동 갱신 불필요)
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar:
          _isSelectionMode
              ? _buildSelectionModeAppBar()
              : AppBar(
                title: Text('나의 곳', style: TextStyle(color: Colors.grey[800])),
                centerTitle: true,
              ),
      body: Consumer<MemoryService>(
        builder: (context, memoryService, child) {
          final memories = memoryService.memories;
          final isLoading = memoryService.isLoading;

          if (isLoading && memories.isEmpty) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[800]!),
              ),
            );
          }

          if (memories.isEmpty) {
            return _buildEmptyContent();
          }

          return RefreshIndicator(
            color: Colors.grey[800],
            onRefresh: () => memoryService.loadMemories(),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.0,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: memories.length,
                itemBuilder: (context, index) {
                  final memory = memories[index];
                  return _buildMemoryItem(memory);
                },
              ),
            ),
          );
        },
      ),
      floatingActionButton:
          !_isSelectionMode
              ? FloatingActionButton(
                onPressed: _navigateToSavePage,
                tooltip: '새 기록 추가',
                backgroundColor: Colors.grey[800],
                child: Icon(Icons.add, color: Colors.white),
              )
              : null,
    );
  }

  // 선택 모드 앱바
  AppBar _buildSelectionModeAppBar() {
    return AppBar(
      elevation: 0.5,
      backgroundColor: Colors.white,
      leading: IconButton(
        icon: Icon(Icons.close, color: Colors.grey[800]),
        onPressed: _toggleSelectionMode,
      ),
      title: Text(
        '${_selectedMemories.length}개 선택됨',
        style: TextStyle(color: Colors.grey[800]),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.delete, color: Colors.grey[800]),
          onPressed: _deleteSelectedMemories,
        ),
      ],
    );
  }

  // 빈 화면 위젯
  Widget _buildEmptyContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bookmark_border, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            '저장된 곳이 없습니다',
            style: TextStyle(fontSize: 18, color: Colors.grey[800]),
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: _navigateToSavePage,
            child: Text('첫 기록 남기기', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[800],
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  // 앨범 아이템 위젯 생성
  Widget _buildMemoryItem(Memory memory) {
    final isSelected = _selectedMemories.contains(memory);

    return GestureDetector(
      onTap: () {
        if (_isSelectionMode) {
          _toggleMemorySelection(memory);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MemoryDetailPage(memory: memory),
            ),
          );
        }
      },
      onLongPress: () {
        if (!_isSelectionMode) {
          _toggleSelectionMode();
          _toggleMemorySelection(memory);
        } else {
          _toggleMemorySelection(memory);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 5,
              spreadRadius: 1,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 배경 이미지/비디오
              _buildThumbnail(memory),

              // 그라데이션 오버레이
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                      stops: [0.6, 1.0],
                    ),
                  ),
                ),
              ),

              // 선택 시 어두운 오버레이 (체크 아이콘 대신)
              if (isSelected)
                Positioned.fill(
                  child: Container(color: Colors.black.withOpacity(0.4)),
                ),

              // 메모와 날짜 표시
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      memory.memo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: Colors.white70,
                        ),
                        SizedBox(width: 4),
                        Text(
                          formatDate(memory.createdAt),
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                    if (memory.latitude != null && memory.longitude != null)
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 12,
                            color: Colors.white70,
                          ),
                          SizedBox(width: 4),
                          Expanded(
                            child: FutureBuilder<String?>(
                              future: memory.getLocationString(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) return SizedBox();
                                final addressParts =
                                    snapshot.data?.split(',') ?? [];
                                final locationText =
                                    addressParts.length > 1
                                        ? '${addressParts[0]}, ${addressParts[1]}'
                                        : (addressParts.isNotEmpty
                                            ? addressParts[0]
                                            : '');
                                return Text(
                                  locationText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              // 비디오 표시기
              if (memory.filePath != null && isVideoFile(memory.filePath!))
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.play_circle_outline,
                          color: Colors.white,
                          size: 14,
                        ),
                        SizedBox(width: 2),
                        Text(
                          '비디오',
                          style: TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // 썸네일 위젯 생성
  Widget _buildThumbnail(Memory memory) {
    if (memory.filePath == null || memory.filePath!.isEmpty) {
      return Container(
        color: Colors.grey[200],
        child: Icon(
          Icons.image_not_supported,
          color: Colors.grey[500],
          size: 48,
        ),
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
}
