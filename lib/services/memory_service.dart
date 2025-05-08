import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/memory.dart';
import '../util/util.dart';
import 'package:path/path.dart' as path_dep;

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
    if (_database != null && (await _database!.getVersion() >= 2)) {
      return _database!;
    }
    // 데이터베이스 파일 위치 설정
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = path_dep.join(documentsDirectory.path, 'memories.db');

    // 데이터베이스 생성 및 테이블 생성
    _database = await openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE memories (
            id TEXT PRIMARY KEY,
            memoryName TEXT NOT NULL,
            filePaths TEXT NOT NULL,
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
            List<String> filePaths = [];

            // 여러 파일 경로 처리
            if (map['filePaths'] != null &&
                map['filePaths'].toString().isNotEmpty) {
              filePaths = List<String>.from(jsonDecode(map['filePaths']));
            }

            return Memory(
              id: map['id'],
              memoryName: map['memoryName'],
              filePaths: filePaths,
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
    List<String> filePaths,
    String memoryName,
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
      List<String> outputPaths = [];

      if (filePaths.isNotEmpty) {
        final directory = await getApplicationDocumentsDirectory();

        for (int i = 0; i < filePaths.length; i++) {
          String filePath = filePaths[i];
          String extension = path_dep.extension(filePath);
          final File sourceFile = File(filePath);
          String outputPath =
              '${directory.path}/${memoryName}-${id}-${i}$extension';
          await sourceFile.copy(outputPath);
          outputPaths.add(outputPath);
        }

        // final directory = await getApplicationDocumentsDirectory();
        // String extension = isVideoFile(filePath) ? '.mp4' : '.jpg';
        // final File sourceFile = File(filePath);
        // outputPath = '${directory.path}/${fileName}-${id}$extension';
        // await sourceFile.copy(outputPath);
      }

      // 새로운 메모리 객체 생성
      final newMemory = Memory(
        id: id,
        memoryName: memoryName,
        filePaths: outputPaths,
        memo: memo,
        createdAt: DateTime.now(),
        latitude: latitude,
        longitude: longitude,
      );

      // DB에 저장
      await db.insert('memories', {
        'id': newMemory.id,
        'memoryName': newMemory.memoryName,
        'filePaths': jsonEncode(newMemory.filePaths),
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

      // 모든 미디어 파일 삭제
      for (String filePath in memoryToDelete.filePaths) {
        try {
          final file = File(filePath);
          if (await file.exists()) {
            await file.delete();
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
          'memoryName': memory.memoryName,
          'filePaths': jsonEncode(memory.filePaths),
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

  // 파일 추가하기
  Future<void> addFilesToMemory(
    String memoryId,
    List<String> newFilePaths,
  ) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 메모리 찾기
      final memoryIndex = _memories.indexWhere((mem) => mem.id == memoryId);
      if (memoryIndex == -1) throw Exception('해당 메모리를 찾을 수 없습니다.');

      Memory memory = _memories[memoryIndex];
      List<String> updatedFilePaths = [...memory.filePaths];
      final directory = await getApplicationDocumentsDirectory();

      // 새 파일 복사 및 저장
      for (int i = 0; i < newFilePaths.length; i++) {
        String filePath = newFilePaths[i];
        String extension = path_dep.extension(filePath);
        final File sourceFile = File(filePath);
        String outputPath =
            '${directory.path}/${memory.memoryName}-${memory.id}-${memory.filePaths.length + i}$extension';
        await sourceFile.copy(outputPath);
        updatedFilePaths.add(outputPath);
      }

      // 업데이트된 메모리 생성
      Memory updatedMemory = Memory(
        id: memory.id,
        memoryName: memory.memoryName,
        filePaths: updatedFilePaths,
        memo: memory.memo,
        createdAt: memory.createdAt,
        latitude: memory.latitude,
        longitude: memory.longitude,
      );

      // DB 업데이트
      final db = await initDatabase();
      await db.update(
        'memories',
        {'filePaths': jsonEncode(updatedFilePaths)},
        where: 'id = ?',
        whereArgs: [memory.id],
      );

      // 메모리 목록 업데이트
      _memories[memoryIndex] = updatedMemory;
      notifyListeners();
    } catch (e) {
      print('파일 추가 오류: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 특정 파일 삭제하기
  Future<void> removeFileFromMemory(String memoryId, String filePath) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 메모리 찾기
      final memoryIndex = _memories.indexWhere((mem) => mem.id == memoryId);
      if (memoryIndex == -1) throw Exception('해당 메모리를 찾을 수 없습니다.');

      Memory memory = _memories[memoryIndex];

      // 파일 삭제
      try {
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        print('파일 삭제 오류: $e');
      }

      // 파일 경로 목록에서 제거
      List<String> updatedFilePaths = [...memory.filePaths];
      updatedFilePaths.remove(filePath);

      // 업데이트된 메모리 생성
      Memory updatedMemory = Memory(
        id: memory.id,
        memoryName: memory.memoryName,
        filePaths: updatedFilePaths,
        memo: memory.memo,
        createdAt: memory.createdAt,
        latitude: memory.latitude,
        longitude: memory.longitude,
      );

      // DB 업데이트
      final db = await initDatabase();
      await db.update(
        'memories',
        {'filePaths': jsonEncode(updatedFilePaths)},
        where: 'id = ?',
        whereArgs: [memory.id],
      );

      // 메모리 목록 업데이트
      _memories[memoryIndex] = updatedMemory;
      notifyListeners();
    } catch (e) {
      print('파일 제거 오류: $e');
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
            List<String> filePaths = [];
            if (map['filePaths'] != null &&
                map['filePaths'].toString().isNotEmpty) {
              filePaths = List<String>.from(jsonDecode(map['filePaths']));
            }

            return Memory(
              id: map['id'],
              memoryName: map['memoryName'],
              filePaths: filePaths,
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
        List<String> filePaths = [];

        if (maps[0]['filePaths'] != null &&
            maps[0]['filePaths'].toString().isNotEmpty) {
          filePaths = List<String>.from(jsonDecode(maps[0]['filePaths']));
        }

        return Memory(
          id: maps[0]['id'],
          memoryName: maps[0]['memoryName'],
          filePaths: filePaths,
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
