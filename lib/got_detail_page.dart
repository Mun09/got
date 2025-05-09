import 'package:flutter/material.dart';
import 'package:got/models/got.dart';
import 'package:got/models/memory.dart';
import 'package:got/util/util.dart';
import 'package:got/widget/media_display_widget.dart';

import 'memory_detail_page.dart';
import 'memory_list_page/build_thumbnail.dart';

class GOTDetailPage extends StatefulWidget {
  final GOT got;

  const GOTDetailPage({Key? key, required this.got}) : super(key: key);

  @override
  State<GOTDetailPage> createState() => _GOTDetailPageState();
}

class _GOTDetailPageState extends State<GOTDetailPage> {
  bool _sortDescending = true; // 기본적으로 최신순 정렬

  @override
  Widget build(BuildContext context) {
    // 정렬된 메모리 목록 가져오기
    final sortedMemories = widget.got.getSortedMemoriesByTime(
      descending: _sortDescending,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(widget.got.name),
        actions: [
          // 정렬 순서 변경 버튼
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
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 위치 정보 표시
            Container(
              padding: EdgeInsets.all(16),
              color: Colors.grey[100],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.place, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.got.locationString ?? '알 수 없는 위치',
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
                    '메모리 수: ${widget.got.memories.length}',
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
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
              child:
                  sortedMemories.isEmpty
                      ? Center(child: Text('기록이 없습니다'))
                      : ListView.builder(
                        itemCount: sortedMemories.length,
                        itemBuilder: (context, index) {
                          final memory = sortedMemories[index];
                          return _buildMemoryCard(memory);
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  // 메모리 카드 위젯
  // 메모리 카드 위젯
  Widget _buildMemoryCard(Memory memory) {
    return GestureDetector(
      onTap: () {
        // 메모리 상세 페이지로 이동
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MemoryDetailPage(memory: memory),
          ),
        );
      },
      child: Card(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 미디어 표시 (썸네일 위젯 사용)
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
                  if (memory.memoryName != null &&
                      memory.memoryName!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        memory.memoryName!,
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
