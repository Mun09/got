// 앨범 아이템 위젯 생성
import 'package:flutter/material.dart';
import 'package:got/util/util.dart';

import '../memory_detail_page.dart';
import '../models/memory.dart';
import 'build_thumbnail.dart';

Widget buildMemoryItem(
  Memory memory,
  int gridColumnCount,
  bool isSelectionMode,
  Set<Memory> selectedMemories,
  Function(Memory) toggleMemorySelection,
  Function() toggleSelectionMode,
  BuildContext context,
) {
  final isSelected = selectedMemories.contains(memory);

  // 그리드 열 수에 따른 텍스트 크기 조정
  final double memoFontSize =
      gridColumnCount == 2
          ? 14.0
          : gridColumnCount == 3
          ? 12.0
          : 10.0;
  final double infoFontSize =
      gridColumnCount == 2
          ? 12.0
          : gridColumnCount == 3
          ? 10.0
          : 8.0;
  final double iconSize =
      gridColumnCount == 2
          ? 12.0
          : gridColumnCount == 3
          ? 10.0
          : 8.0;

  return GestureDetector(
    onTap: () {
      if (isSelectionMode) {
        toggleMemorySelection(memory);
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
      if (!isSelectionMode) {
        toggleSelectionMode();
        toggleMemorySelection(memory);
      } else {
        toggleMemorySelection(memory);
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
            ThumbnailWidget(memory: memory),

            // 그라데이션 오버레이
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
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
                    maxLines: gridColumnCount == 2 ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: memoFontSize,
                    ),
                  ),
                  SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: iconSize,
                        color: Colors.white70,
                      ),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          formatDate(memory.createdAt),
                          overflow: TextOverflow.ellipsis,

                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: infoFontSize,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (memory.latitude != null &&
                      memory.longitude != null &&
                      gridColumnCount <= 3) // 4열에서는 위치 표시 생략
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: iconSize,
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
                                  fontSize: infoFontSize,
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
            if (memory.filePaths.any((path) => isVideoFile(path)))
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: gridColumnCount == 4 ? 4 : 6,
                    vertical: gridColumnCount == 4 ? 1 : 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.play_circle_outline,
                        color: Colors.white,
                        size: gridColumnCount == 2 ? 14 : 12,
                      ),
                      SizedBox(width: 2),
                      Text(
                        '비디오',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: gridColumnCount == 2 ? 10 : 8,
                        ),
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
