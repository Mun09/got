import 'dart:io';
import 'package:flutter/material.dart';
import 'package:got/save_page.dart';
import 'package:got/util/util.dart';
import 'package:provider/provider.dart';

import 'memory_list_page/build_memory_item_widget.dart';
import 'memory_list_page/build_thumbnail.dart';
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
  int _gridColumnCount = 2;

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

  // 그리드 열 개수 변경 메소드
  void _changeGridColumnCount(int count) {
    setState(() {
      _gridColumnCount = count;
    });
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: Text('나의 곳', style: TextStyle(color: Colors.grey[800])),
      centerTitle: true,
      actions: [
        // 그리드 뷰 토글 버튼 추가
        PopupMenuButton<int>(
          icon: Icon(Icons.grid_view, color: Colors.grey[800]),
          onSelected: _changeGridColumnCount,
          itemBuilder:
              (context) => [
                PopupMenuItem(
                  value: 2,
                  child: Row(
                    children: [
                      Icon(
                        Icons.grid_view,
                        color:
                            _gridColumnCount == 2
                                ? Colors.blue
                                : Colors.grey[800],
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        '2열',
                        style: TextStyle(
                          fontWeight:
                              _gridColumnCount == 2
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 3,
                  child: Row(
                    children: [
                      Icon(
                        Icons.grid_3x3,
                        color:
                            _gridColumnCount == 3
                                ? Colors.blue
                                : Colors.grey[800],
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        '3열',
                        style: TextStyle(
                          fontWeight:
                              _gridColumnCount == 3
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 4,
                  child: Row(
                    children: [
                      Icon(
                        Icons.grid_4x4,
                        color:
                            _gridColumnCount == 4
                                ? Colors.blue
                                : Colors.grey[800],
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        '4열',
                        style: TextStyle(
                          fontWeight:
                              _gridColumnCount == 4
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _isSelectionMode ? _buildSelectionModeAppBar() : _buildAppBar(),
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
                  crossAxisCount: _gridColumnCount,
                  childAspectRatio: 1.0,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: memories.length,
                itemBuilder: (context, index) {
                  final memory = memories[index];
                  return buildMemoryItem(
                    memory,
                    _gridColumnCount,
                    _isSelectionMode,
                    _selectedMemories,
                    _toggleMemorySelection,
                    _toggleSelectionMode,
                    context,
                  );
                },
              ),
            ),
          );
        },
      ),
      floatingActionButton:
          !_isSelectionMode
              ? FloatingActionButton(
                heroTag: 'add_memory',
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
}
