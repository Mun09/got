import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'memory.dart';

class MemoryService {
  static const String _memoryFileName = 'memories.json';
  final _uuid = Uuid();

  // 메모리 저장
  // 메모리 저장 (위치 정보 포함)
  Future<Memory> saveMemory(
    String? videoPath,
    String memo,
    double? latitude,
    double? longitude,
  ) async {
    final memories = await getMemories();

    final newMemory = Memory(
      id: _uuid.v4(),
      videoPath: videoPath,
      memo: memo,
      createdAt: DateTime.now(),
      latitude: latitude,
      longitude: longitude,
    );

    memories.add(newMemory);
    await _saveMemoriesToFile(memories);
    return newMemory;
  }

  // 모든 메모리 가져오기
  Future<List<Memory>> getMemories() async {
    try {
      final file = await _getMemoryFile();
      if (!await file.exists()) {
        return [];
      }

      final content = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(content);
      return jsonList.map((json) => Memory.fromJson(json)).toList();
    } catch (e) {
      print('메모리 로드 오류: $e');
      return [];
    }
  }

  // 메모리 삭제
  Future<void> deleteMemory(String id) async {
    final memories = await getMemories();
    final memory = memories.firstWhere((mem) => mem.id == id);

    // 비디오 파일 삭제 (videoPath가 있을 경우에만)
    if (memory.videoPath != null && memory.videoPath!.isNotEmpty) {
      try {
        final videoFile = File(memory.videoPath!);
        if (await videoFile.exists()) {
          await videoFile.delete();
        }
      } catch (e) {
        print('미디어 파일 삭제 오류: $e');
      }
    }

    // 메모리 목록에서 제거
    memories.removeWhere((mem) => mem.id == id);
    await _saveMemoriesToFile(memories);
  }

  // 메모리 파일 경로 얻기
  Future<File> _getMemoryFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_memoryFileName');
  }

  // 메모리 목록 파일에 저장
  Future<void> _saveMemoriesToFile(List<Memory> memories) async {
    final file = await _getMemoryFile();
    final jsonList = memories.map((memory) => memory.toJson()).toList();
    await file.writeAsString(jsonEncode(jsonList));
  }
}
