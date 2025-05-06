import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../memory.dart';

class MemoryService extends ChangeNotifier {
  Database? _database;
  List<Memory> _memories = [];
  bool _isLoading = false;

  List<Memory> get memories => _memories;

  bool get isLoading => _isLoading;

  // 싱글톤 패턴 구현
  static final MemoryService _instance = MemoryService._internal();

  factory MemoryService() {
    return _instance;
  }

  MemoryService._internal() {
    // 초기화 시 메모리 로드
    initDatabase().then((_) => loadMemories());
  }

  // 데이터베이스 초기화
  Future<Database> initDatabase() async {
    if (_database != null) return _database!;

    // 데이터베이스 파일 위치 설정
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'memories.db');

    // 데이터베이스 생성 및 테이블 생성
    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE memories (
            id TEXT PRIMARY KEY,
            videoPath TEXT,
            memo TEXT NOT NULL, 
            createdAt TEXT NOT NULL,
            latitude REAL,
            longitude REAL
          )
        ''');
      },
    );

    return _database!;
  }

  // 메모리 로드
  Future<List<Memory>> loadMemories() async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await initDatabase();
      final List<Map<String, dynamic>> maps = await db.query('memories');

      _memories =
          maps.map((map) {
            return Memory(
              id: map['id'],
              filePath: map['videoPath'],
              memo: map['memo'],
              createdAt: DateTime.parse(map['createdAt']),
              latitude: map['latitude'],
              longitude: map['longitude'],
            );
          }).toList();

      // 최신 항목이 먼저 오도록 정렬
      _memories.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      notifyListeners();
      return _memories;
    } catch (e) {
      print('메모리 로드 오류: $e');
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 메모리 저장
  Future<Memory> saveMemory(
    String? videoPath,
    String memo,
    double? latitude,
    double? longitude,
  ) async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await initDatabase();

      // UUID 생성
      String id = DateTime.now().millisecondsSinceEpoch.toString();

      // 새로운 메모리 객체 생성
      final newMemory = Memory(
        id: id,
        filePath: videoPath,
        memo: memo,
        createdAt: DateTime.now(),
        latitude: latitude,
        longitude: longitude,
      );

      // DB에 저장
      await db.insert('memories', {
        'id': newMemory.id,
        'videoPath': newMemory.filePath,
        'memo': newMemory.memo,
        'createdAt': newMemory.createdAt.toIso8601String(),
        'latitude': newMemory.latitude,
        'longitude': newMemory.longitude,
      });

      // 메모리 목록에 추가
      _memories.insert(0, newMemory); // 최신 항목을 맨 앞에 추가
      notifyListeners();

      return newMemory;
    } catch (e) {
      print('메모리 저장 오류: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 메모리 삭제
  Future<void> deleteMemory(String id) async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await initDatabase();

      // 삭제할 메모리 찾기
      final memoryToDelete = _memories.firstWhere((mem) => mem.id == id);

      // 비디오 파일 삭제 (videoPath가 있을 경우에만)
      if (memoryToDelete.filePath != null &&
          memoryToDelete.filePath!.isNotEmpty) {
        try {
          final videoFile = File(memoryToDelete.filePath!);
          if (await videoFile.exists()) {
            await videoFile.delete();
          }
        } catch (e) {
          print('미디어 파일 삭제 오류: $e');
        }
      }

      // DB에서 삭제
      await db.delete('memories', where: 'id = ?', whereArgs: [id]);

      // 메모리 목록에서 제거
      _memories.removeWhere((mem) => mem.id == id);
      notifyListeners();
    } catch (e) {
      print('메모리 삭제 오류: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 메모리 업데이트
  Future<void> updateMemory(Memory memory) async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await initDatabase();

      // DB에서 업데이트
      await db.update(
        'memories',
        {
          'videoPath': memory.filePath,
          'memo': memory.memo,
          'latitude': memory.latitude,
          'longitude': memory.longitude,
        },
        where: 'id = ?',
        whereArgs: [memory.id],
      );

      // 메모리 목록 업데이트
      final index = _memories.indexWhere((mem) => mem.id == memory.id);
      if (index != -1) {
        _memories[index] = memory;
        notifyListeners();
      }
    } catch (e) {
      print('메모리 업데이트 오류: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 메모리 검색
  Future<List<Memory>> searchMemories(String query) async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await initDatabase();
      final List<Map<String, dynamic>> maps = await db.query(
        'memories',
        where: 'memo LIKE ?',
        whereArgs: ['%$query%'],
      );

      final results =
          maps.map((map) {
            return Memory(
              id: map['id'],
              filePath: map['videoPath'],
              memo: map['memo'],
              createdAt: DateTime.parse(map['createdAt']),
              latitude: map['latitude'],
              longitude: map['longitude'],
            );
          }).toList();

      // 최신 항목이 먼저 오도록 정렬
      results.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return results;
    } catch (e) {
      print('메모리 검색 오류: $e');
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ID로 특정 메모리 가져오기
  Future<Memory?> getMemoryById(String id) async {
    try {
      final db = await initDatabase();
      final List<Map<String, dynamic>> maps = await db.query(
        'memories',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (maps.isNotEmpty) {
        return Memory(
          id: maps[0]['id'],
          filePath: maps[0]['videoPath'],
          memo: maps[0]['memo'],
          createdAt: DateTime.parse(maps[0]['createdAt']),
          latitude: maps[0]['latitude'],
          longitude: maps[0]['longitude'],
        );
      }
      return null;
    } catch (e) {
      print('메모리 조회 오류: $e');
      return null;
    }
  }
}
