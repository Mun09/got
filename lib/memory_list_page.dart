import 'package:flutter/material.dart';
import 'package:got/save_page.dart';
import 'package:got/services/memory_service.dart';
import 'package:got/services/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:got/models/got.dart';
import 'package:got/got_detail_page.dart';

import 'memory_list_page/build_thumbnail.dart';
import 'models/memory.dart';

class MemoryListPage extends StatefulWidget {
  const MemoryListPage({Key? key}) : super(key: key);

  @override
  State<MemoryListPage> createState() => _MemoryListPageState();
}

class _MemoryListPageState extends State<MemoryListPage> {
  // 선택 모드 관리를 위한 상태 변수
  bool _isSelectionMode = false;
  final Set<GOT> _selectedGOTs = {};
  late int _gridColumnCount;
  List<GOT> _gotList = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // initState에서 Provider를 통해 서비스 접근 및 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadGOTs();
    });

    final settingsService = Provider.of<SettingsService>(
      context,
      listen: false,
    );
    _gridColumnCount = settingsService.gridColumnCount;
  }

  // 메모리를 GOT로 로드하고 변환
  Future<void> _loadGOTs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final memoryService = Provider.of<MemoryService>(context, listen: false);
      await memoryService.loadMemories();

      // 메모리 리스트를 GOT 그룹으로 변환
      final gotService = GOTService();
      final gotGroups = await gotService.organizeMemories(
        memoryService.memories,
      );

      setState(() {
        _gotList = gotGroups;
        _isLoading = false;
      });
    } catch (e) {
      print('GOT 로딩 오류: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 선택한 GOT 삭제
  Future<void> _deleteSelectedGOTs() async {
    if (_selectedGOTs.isEmpty) return;

    final count = _selectedGOTs.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.white,
            title: Text('삭제 확인'),
            content: Text(
              '선택한 ${count}개의 장소를 삭제하시겠습니까?\n(해당 장소의 모든 기록이 삭제됩니다)',
            ),
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

    final memoryService = Provider.of<MemoryService>(context, listen: false);
    int successCount = 0;
    int failCount = 0;

    // 선택된 GOT에 속한 메모리들 삭제
    for (final got in _selectedGOTs) {
      for (final memory in got.memories) {
        try {
          await memoryService.deleteMemory(memory.id);
          successCount++;
        } catch (e) {
          failCount++;
          print('삭제 실패: ${memory.id}, 오류: $e');
        }
      }
    }

    // 선택 모드 종료 및 목록 새로고침
    setState(() {
      _isSelectionMode = false;
      _selectedGOTs.clear();
    });

    await _loadGOTs();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${successCount}개 항목 삭제 완료${failCount > 0 ? ', ${failCount}개 실패' : ''}',
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
      _selectedGOTs.clear();
    });
  }

  // GOT 선택 토글
  void _toggleGOTSelection(GOT got) {
    // 선택 상태만 변경하고 리빌드를 최소화합니다
    if (_selectedGOTs.contains(got)) {
      _selectedGOTs.remove(got);
      // 선택된 항목이 없으면 선택 모드 종료
      if (_selectedGOTs.isEmpty) {
        setState(() {
          _isSelectionMode = false;
        });
      } else {
        // 선택 모드는 유지하면서 AppBar의 카운트만 업데이트
        setState(() {});
      }
    } else {
      _selectedGOTs.add(got);
      setState(() {});
    }
  }

  // GOT 상세 페이지로 이동
  void _navigateToGOTDetailPage(GOT got) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => GOTDetailPage(got: got)),
    ).then((_) {
      // 저장 페이지에서 돌아왔을 때도 선택 모드 및 선택 아이템 초기화
      setState(() {
        _isSelectionMode = false;
        _selectedGOTs.clear();
      });

      // 상세 페이지에서 돌아왔을 때 목록 갱신
      _loadGOTs();
    });
  }

  // 새 기록 추가 화면으로 이동
  void _navigateToSavePage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => FileSavePage()),
    );

    // 저장 페이지에서 돌아왔을 때도 선택 모드 및 선택 아이템 초기화
    setState(() {
      _isSelectionMode = false;
      _selectedGOTs.clear();
    });

    _loadGOTs();
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: Text('나의 곳'),
      centerTitle: true,
      actions: [
        IconButton(
          icon:
              _gridColumnCount == 2
                  ? Icon(Icons.grid_view)
                  : _gridColumnCount == 3
                  ? Icon(Icons.grid_3x3)
                  : Icon(Icons.grid_4x4),
          onPressed: () {
            setState(() {
              // 2 -> 3 -> 4 -> 2 순환
              _gridColumnCount =
                  _gridColumnCount >= 4 ? 2 : _gridColumnCount + 1;
              Provider.of<SettingsService>(
                context,
                listen: false,
              ).setGridColumnCount(_gridColumnCount);
            });
          },
          tooltip: '${_gridColumnCount + 1}열로 보기',
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
      ],
    );
  }

  // 선택 모드 앱바
  AppBar _buildSelectionModeAppBar() {
    print(_selectedGOTs.length);

    return AppBar(
      elevation: 0.5,
      backgroundColor: Colors.white,
      leading: IconButton(
        icon: Icon(Icons.close, color: Colors.grey[800]),
        onPressed: _toggleSelectionMode,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      title: Text(
        '${_selectedGOTs.length}개 선택됨',
        style: TextStyle(color: Colors.grey[800]),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.delete, color: Colors.grey[800]),
          onPressed: _deleteSelectedGOTs,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
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
          Icon(Icons.place, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            '저장된 곳이 없습니다',
            style: TextStyle(fontSize: 18, color: Colors.grey[800]),
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: _navigateToSavePage,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[800],
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text('첫 기록 남기기', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // GOT 아이템 위젯
  Widget _buildGOTItem(GOT got) {
    final representativeMemory = got.getRepresentativeMemory();
    final isSelected = _selectedGOTs.contains(got);

    // 성능 개선을 위한 별도의 위젯으로 분리
    return _GOTItemWidget(
      key: ValueKey<String>('got_${got.id}'),
      got: got,
      memory: representativeMemory,
      isSelected: _selectedGOTs.contains(got),
      isSelectionMode: _isSelectionMode,
      onTap:
          _isSelectionMode
              ? () => _toggleGOTSelection(got)
              : () => _navigateToGOTDetailPage(got),
      onLongPress: () {
        if (!_isSelectionMode) {
          _toggleSelectionMode();
          _toggleGOTSelection(got);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsService>(
      builder: (context, settingsService, child) {
        _gridColumnCount = settingsService.gridColumnCount;
        return Scaffold(
          backgroundColor: Colors.white,
          appBar:
              _isSelectionMode ? _buildSelectionModeAppBar() : _buildAppBar(),
          body:
              _isLoading
                  ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.grey[800]!,
                      ),
                    ),
                  )
                  : _gotList.isEmpty
                  ? _buildEmptyContent()
                  : RefreshIndicator(
                    color: Colors.grey[800],
                    onRefresh: _loadGOTs,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: _gridColumnCount,
                          childAspectRatio: 1.0,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: _gotList.length,
                        itemBuilder: (context, index) {
                          final got = _gotList[index];
                          return _buildGOTItem(got);
                        },
                      ),
                    ),
                  ),
          floatingActionButton:
              !_isSelectionMode
                  ? FloatingActionButton(
                    heroTag: 'add_memory',
                    onPressed: _navigateToSavePage,
                    tooltip: '새 기록 추가',
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    child: Icon(
                      Icons.add,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  )
                  : null,
        );
      },
    );
  }
}

// GOT 아이템을 위한 별도의 위젯 클래스
class _GOTItemWidget extends StatelessWidget {
  final GOT got;
  final Memory memory;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _GOTItemWidget({
    Key? key,
    required this.got,
    required this.memory,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ThumbnailWidget 사용
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ThumbnailWidget(
                memory: memory,
                key: ValueKey<String>('thumbnail_${got.id}'),
              ),
            ),

            // 선택됐을 때 회색 오버레이 추가
            if (isSelected)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(color: Colors.black.withOpacity(0.3)),
                ),
              ),

            // 하단 정보 오버레이
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(8),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      got.name,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2),
                    Text(
                      '${got.memories.length}개의 기록',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// GOT 아이템 위젯
