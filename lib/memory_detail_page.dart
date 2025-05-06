import 'package:flutter/material.dart';
import 'package:got/sevices/memory_service.dart';
import 'package:got/util/util.dart';
import 'package:got/widget/media_display_widget.dart';
import 'package:provider/provider.dart';

import 'memory.dart';

class MemoryDetailPage extends StatefulWidget {
  final Memory memory;

  const MemoryDetailPage({Key? key, required this.memory}) : super(key: key);

  @override
  State<MemoryDetailPage> createState() => _MemoryDetailPageState();
}

class _MemoryDetailPageState extends State<MemoryDetailPage> {
  late MemoryService _memoryService;

  @override
  void initState() {
    super.initState();
    _memoryService = Provider.of<MemoryService>(context, listen: false);
  }

  Future<void> _deleteMemory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('삭제 확인'),
            content: Text('이 기록을 정말 삭제하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('삭제', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );

    if (confirmed == true && mounted) {
      try {
        await _memoryService.deleteMemory(widget.memory.id);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('기록이 삭제되었습니다')));
        Navigator.pop(context); // 상세 화면 닫기
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('삭제 중 오류가 발생했습니다: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text('곳 상세'),
        actions: [
          IconButton(
            icon: Icon(Icons.delete, color: Colors.red),
            onPressed: _deleteMemory,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 미디어 표시 위젯
                    MediaDisplayWidget(
                      showControls: true,
                      memory: widget.memory,
                    ),

                    // 메모 내용
                    Container(
                      padding: EdgeInsets.all(16),
                      color: Colors.white,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.memory.memo,
                            style: TextStyle(fontSize: 18),
                          ),
                          SizedBox(height: 12),
                          Text(
                            formatDate(widget.memory.createdAt),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          if (widget.memory.latitude != null &&
                              widget.memory.longitude != null) ...[
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.home,
                                    size: 16,
                                    color: Colors.green,
                                  ),
                                  SizedBox(width: 4),

                                  Expanded(
                                    child: FutureBuilder<String?>(
                                      future: widget.memory.getLocationString(),
                                      builder: (context, snapshot) {
                                        return Text(
                                          snapshot.data ?? '위치 정보 없음',
                                          style: TextStyle(
                                            color: Colors.grey[800],
                                            fontSize: 14,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 16,
                                    color: Colors.blue,
                                  ),

                                  SizedBox(width: 4),
                                  Text(
                                    '위도: ${widget.memory.latitude!.toStringAsFixed(6)}, '
                                    '경도: ${widget.memory.longitude!.toStringAsFixed(6)}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
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
