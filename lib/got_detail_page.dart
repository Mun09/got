import 'package:flutter/material.dart';
import 'package:got/models/got.dart';
import 'package:got/models/memory.dart';
import 'package:got/provider/got_provider.dart';
import 'package:got/services/memory_service.dart';
import 'package:got/util/util.dart';
import 'package:provider/provider.dart';

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

  GOTProvider? _gotProvider;

  @override
  void initState() {
    super.initState();
    _gotProvider = GOTProvider(widget.got);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      // GOTProvider를 생성하면서 초기 GOT 객체를 전달
      create: (_) => _gotProvider,
      child: Consumer<GOTProvider>(
        builder: (context, gotProvider, child) {
          return Consumer<MemoryService>(
            builder: (context, memoryService, child) {
              // 앱 바에 접근할 때 widget.got 대신 gotProvider.got 사용
              return Scaffold(
                backgroundColor: Colors.white,
                appBar: AppBar(
                  backgroundColor: Colors.white,
                  title: Text(gotProvider.got.getSimpleLocationString()),
                  actions: [
                    IconButton(
                      icon: Icon(
                        _sortDescending
                            ? Icons.arrow_downward
                            : Icons.arrow_upward,
                      ),
                      onPressed: () {
                        setState(() {
                          _sortDescending = !_sortDescending;
                        });
                      },
                      tooltip: _sortDescending ? '최신순 정렬' : '오래된순 정렬',
                    ),
                    // 새로고침 버튼 추가
                    IconButton(
                      icon: Icon(Icons.refresh),
                      onPressed: () async {
                        await gotProvider.refreshGOT();
                      },
                      tooltip: '메모리 목록 새로고침',
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
                                Icon(
                                  Icons.place,
                                  color: Colors.green,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    gotProvider.got.locationString ??
                                        '알 수 없는 위치',
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
                              '기억 개수: ${gotProvider.got.memories.length}',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),

                      // 메모리 목록 제목
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
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
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 메모리 목록
                      Expanded(
                        child: FutureBuilder<List<Memory>>(
                          future: gotProvider.getSortedMemories(
                            descending: _sortDescending,
                          ),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return Center(child: CircularProgressIndicator());
                            }

                            if (snapshot.hasError) {
                              return Center(child: Text('오류가 발생했습니다'));
                            }

                            final validMemories = snapshot.data ?? [];

                            if (validMemories.isEmpty) {
                              return Center(child: Text('기록이 없습니다'));
                            }

                            return ListView.builder(
                              itemCount: validMemories.length,
                              itemBuilder: (context, index) {
                                final memory = validMemories[index];
                                return _buildMemoryCard(context, memory);
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
        },
      ),
    );
  }

  // 메모리 카드 위젯
  Widget _buildMemoryCard(BuildContext context, Memory memory) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MemoryDetailPage(memory: memory),
          ),
        ).then((_) async {
          print("메모리 상세 페이지에서 돌아옴");
          // 페이지에서 돌아왔을 때 GOT 데이터 refresh
          await _gotProvider?.refreshGOT();
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
