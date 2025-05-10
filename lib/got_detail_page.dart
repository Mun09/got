import 'package:flutter/material.dart';
import 'package:got/models/got.dart';
import 'package:got/models/memory.dart';
import 'package:got/provider/got_provider.dart';
import 'package:got/services/got_service.dart';
import 'package:got/services/memory_service.dart';
import 'package:got/util/util.dart';
import 'package:provider/provider.dart';

import 'memory_detail_page.dart';
import 'memory_list_page/build_thumbnail.dart';

class GOTDetailPage extends StatefulWidget {
  final GOT got;

  const GOTDetailPage({super.key, required this.got});

  @override
  State<GOTDetailPage> createState() => _GOTDetailPageState();
}

class _GOTDetailPageState extends State<GOTDetailPage> {
  bool _sortDescending = true; // 기본적으로 최신순 정렬
  final GOTService _gotService = GOTService();

  @override
  void dispose() {
    // 페이지 이탈 시 스트림 구독 해제
    _gotService.disposeGOTStream(widget.got.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<GOT>(
      // GOT 스트림 구독
      stream: _gotService.getGOTUpdatesStream(widget.got.id),
      initialData: widget.got,
      builder: (context, gotSnapshot) {
        // 최신 GOT 데이터 (또는 초기 제공된 데이터)
        final got = gotSnapshot.data ?? widget.got;

        return Scaffold(
          appBar: AppBar(
            title: Text(got.getSimpleLocationString()),
            actions: [
              IconButton(
                icon: Icon(
                  _sortDescending ? Icons.arrow_downward : Icons.arrow_upward,
                ),
                onPressed: () {
                  setState(() {
                    _sortDescending = !_sortDescending;
                  });
                },
                tooltip: _sortDescending ? '최신순 정렬' : '오래된순 정렬',
              ),
              // 새로고침 버튼
              IconButton(
                icon: Icon(Icons.refresh),
                onPressed: () async {
                  await _gotService.notifyGOTUpdated(got.id);
                },
                tooltip: '기억 목록 새로고침',
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 위치 정보 표시
                Container(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.place, color: Colors.blue, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              got.locationString ?? '알 수 없는 위치',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        '기억 개수: ${got.memories.length}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),

                // 메모리 목록 제목
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '기억 목록',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _sortDescending ? '최신순' : '오래된순',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),

                // 메모리 목록
                Expanded(
                  child: FutureBuilder<List<Memory>>(
                    future: got.getSortedMemoriesByTime(
                      descending: _sortDescending,
                    ),
                    builder: (context, memorySnapshot) {
                      if (memorySnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      }

                      final validMemories = memorySnapshot.data ?? [];

                      if (validMemories.isEmpty) {
                        return Center(child: Text('기억이 없습니다'));
                      }

                      return ListView.builder(
                        itemCount: validMemories.length,
                        itemBuilder: (context, index) {
                          final memory = validMemories[index];
                          return _buildMemoryCard(context, memory, got.id);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 메모리 카드 위젯
  // 메모리 카드 위젯
  Widget _buildMemoryCard(BuildContext context, Memory memory, String gotId) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MemoryDetailPage(memory: memory),
          ),
        ).then((_) {
          // 상세 페이지에서 돌아온 후 GOT 정보 갱신
          _gotService.notifyGOTUpdated(gotId);
        });
      },
      child: Card(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 미디어 표시
            if (memory.filePaths.isNotEmpty)
              SizedBox(
                height: 200,
                child: ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                  child: ThumbnailWidget(memory: memory),
                ),
              ),

            // 메모 내용 및 날짜
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (memory.memoryName.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        memory.memoryName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  Text(
                    memory.memo,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8),
                  Text(
                    formatDate(memory.createdAt),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
