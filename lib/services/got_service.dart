// lib/services/got_service.dart
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:got/models/got.dart';
import 'package:got/models/memory.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'memory_service.dart';

class GOTService extends ChangeNotifier {
  static const String _gotsTable = 'gots';
  static const String _relationTable = 'got_memory';
  static Database? _database;

  // 싱글톤 패턴 구현
  static final GOTService _instance = GOTService._internal();

  factory GOTService() {
    return _instance;
  }

  GOTService._internal() {
    // 초기화 시 메모리 로드
    _initDatabase();
  }

  // 데이터베이스 초기화
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // 데이터베이스 초기화 함수
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'got_database.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // GOT 테이블 생성
        await db.execute('''
        CREATE TABLE gots (
          id TEXT PRIMARY KEY,
          name TEXT,
          latitude REAL,
          longitude REAL,
          locationString TEXT,
          createdAt TEXT,
          updatedAt TEXT
        )
      ''');

        // GOT-Memory 관계 테이블 생성
        await db.execute('''
        CREATE TABLE got_memory (
          gotId TEXT,
          memoryId TEXT,
          PRIMARY KEY (gotId, memoryId),
          FOREIGN KEY (gotId) REFERENCES gots (id) ON DELETE CASCADE
        )
      ''');
      },
    );
  }

  // GOT 저장
  Future<void> saveGOT(GOT got) async {
    final db = await database;
    got.updatedAt = DateTime.now();

    // 트랜잭션 시작
    await db.transaction((txn) async {
      // 1. GOT 정보 저장
      await txn.insert(_gotsTable, {
        'id': got.id,
        'name': got.name,
        'latitude': got.latitude,
        'longitude': got.longitude,
        'locationString': got.locationString,
        'createdAt': got.createdAt.toIso8601String(),
        'updatedAt': got.updatedAt.toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // 2. 기존 관계 삭제
      await txn.delete(_relationTable, where: 'gotId = ?', whereArgs: [got.id]);

      // 3. 새로운 메모리 관계 추가
      for (final memory in got.memories) {
        await txn.insert(_relationTable, {
          'gotId': got.id,
          'memoryId': memory.id,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }

  // GOT 조회
  Future<GOT?> getGOT(String id, {bool loadMemories = true}) async {
    final db = await database;
    final maps = await db.query(_gotsTable, where: 'id = ?', whereArgs: [id]);

    if (maps.isEmpty) return null;

    final got = GOT(
      id: maps.first['id'] as String,
      name: maps.first['name'] as String,
      latitude: maps.first['latitude'] as double,
      longitude: maps.first['longitude'] as double,
      locationString: maps.first['locationString'] as String?,
      createdAt: DateTime.parse(maps.first['createdAt'] as String),
      updatedAt: DateTime.parse(maps.first['updatedAt'] as String),
    );

    if (loadMemories) {
      await loadGOTMemories(got);
    }

    return got;
  }

  // 모든 GOT 조회
  Future<List<GOT>> getAllGOTs({bool loadMemories = true}) async {
    final db = await database;
    final maps = await db.query(_gotsTable);

    if (maps.isEmpty) return [];

    List<GOT> gotList =
        maps
            .map(
              (map) => GOT(
                id: map['id'] as String,
                name: map['name'] as String,
                latitude: map['latitude'] as double,
                longitude: map['longitude'] as double,
                locationString: map['locationString'] as String?,
                createdAt: DateTime.parse(map['createdAt'] as String),
                updatedAt: DateTime.parse(map['updatedAt'] as String),
              ),
            )
            .toList();

    if (loadMemories) {
      for (var got in gotList) {
        await loadGOTMemories(got);
      }
    }

    return gotList;
  }

  // 데이터베이스 맵에서 GOT 객체로 변환
  GOT _mapToGOT(Map<String, dynamic> map) {
    return GOT(
      id: map['id'],
      name: map['name'],
      latitude: map['latitude'],
      longitude: map['longitude'],
      locationString: map['locationString'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }

  // GOT와 연결된 모든 메모리 로드
  Future<void> loadGOTMemories(GOT got) async {
    final db = await database;
    got.memories.clear();

    // 관계 테이블에서 memoryId 목록 조회
    final results = await db.rawQuery(
      '''
      SELECT memoryId FROM $_relationTable
      WHERE gotId = ?
    ''',
      [got.id],
    );

    if (results.isEmpty) return;

    // MemoryService를 통해 메모리 로드
    final memoryService = MemoryService();

    for (final result in results) {
      final memoryId = result['memoryId'] as String;
      final memory = await memoryService.getMemoryById(memoryId);

      if (memory != null) {
        got.memories.add(memory);
      }
    }
  }

  // 특정 메모리가 포함된 GOT 찾기
  Future<GOT?> getGOTByMemoryId(String memoryId) async {
    final db = await database;
    final results = await db.rawQuery(
      '''
      SELECT g.* FROM $_gotsTable g
      INNER JOIN $_relationTable r ON g.id = r.gotId
      WHERE r.memoryId = ?
    ''',
      [memoryId],
    );

    if (results.isEmpty) return null;

    final got = GOT(
      id: results.first['id'] as String,
      name: results.first['name'] as String,
      latitude: results.first['latitude'] as double,
      longitude: results.first['longitude'] as double,
      locationString: results.first['locationString'] as String?,
      createdAt: DateTime.parse(results.first['createdAt'] as String),
      updatedAt: DateTime.parse(results.first['updatedAt'] as String),
    );

    await loadGOTMemories(got);
    return got;
  }

  // GOT 삭제 메소드
  Future<void> deleteGOT(String id) async {
    final db = await database;

    // 트랜잭션으로 GOT와 관계 모두 삭제
    await db.transaction((txn) async {
      await txn.delete(_relationTable, where: 'gotId = ?', whereArgs: [id]);

      await txn.delete(_gotsTable, where: 'id = ?', whereArgs: [id]);
    });
  }

  // 메모리에서 GOT 구성 메소드 개선
  Future<List<GOT>> organizeMemories(List<Memory> memories) async {
    Map<String, GOT> gotMap = {};

    // 기존 GOT 불러오기
    final savedGOTs = await getAllGOTs(loadMemories: false);
    for (var got in savedGOTs) {
      gotMap[got.id] = got;
    }

    // 메모리 처리
    for (final memory in memories) {
      if (memory.latitude == null || memory.longitude == null) continue;

      final gotId = GOT.generateIdFromCoordinates(
        memory.latitude!,
        memory.longitude!,
      );

      if (gotMap.containsKey(gotId)) {
        gotMap[gotId]!.memories.add(memory);
      } else {
        // 위치 문자열 가져오기
        final locationString = await memory.getLocationString();
        final name =
            locationString != null
                ? _generateGotNameFromLocation(locationString)
                : "위치 ${gotId.substring(0, 6)}";

        // 새 GOT 생성
        final newGOT = GOT(
          id: gotId,
          name: name,
          latitude: memory.latitude!,
          longitude: memory.longitude!,
          locationString: locationString,
        );
        newGOT.memories.add(memory);
        gotMap[gotId] = newGOT;
      }
    }

    // GOT 저장
    for (final got in gotMap.values) {
      await saveGOT(got);
    }

    // 결과 정렬
    final gotList = gotMap.values.toList();
    gotList.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return gotList;
  }

  // 위치 문자열에서 GOT 이름 생성
  String _generateGotNameFromLocation(String locationString) {
    final parts = locationString.split(', ');

    if (parts.length >= 3) {
      // 구/군과 동/읍/면 활용 (예: "강남구 삼성동")
      return "${parts[parts.length > 3 ? 2 : 1]} ${parts[parts.length > 3 ? 3 : 2]}";
    } else if (parts.length == 2) {
      return parts.join(' ');
    }

    return locationString.length > 15
        ? "${locationString.substring(0, 15)}..."
        : locationString;
  }

  // 메모리를 GOT에 추가하는 메소드
  Future<void> addMemoryToGOT(String gotId, String memoryId) async {
    final db = await database;
    await db.insert(_relationTable, {
      'gotId': gotId,
      'memoryId': memoryId,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  // 메모리를 GOT에서 제거하는 메소드
  Future<void> removeMemoryFromGOT(String gotId, String memoryId) async {
    final db = await database;
    await db.delete(
      _relationTable,
      where: 'gotId = ? AND memoryId = ?',
      whereArgs: [gotId, memoryId],
    );
  }

  // GOT 업데이트 스트림 컨트롤러 맵 (GOT ID별로 관리)
  final _gotStreamControllers = <String, StreamController<GOT>>{};

  // 특정 GOT ID에 대한 업데이트 스트림 제공
  Stream<GOT> getGOTUpdatesStream(String gotId) {
    if (!_gotStreamControllers.containsKey(gotId)) {
      _gotStreamControllers[gotId] = StreamController<GOT>.broadcast();

      // 초기 데이터 로드 및 제공
      getGOT(gotId).then((got) {
        if (got != null && _gotStreamControllers.containsKey(gotId)) {
          _gotStreamControllers[gotId]!.add(got);
        }
      });
    }

    return _gotStreamControllers[gotId]!.stream;
  }

  // 특정 GOT 업데이트 알림
  Future<void> notifyGOTUpdated(String gotId) async {
    final got = await getGOT(gotId);
    if (got != null) {
      got.markNeedsRefresh();
    }
    if (got != null && _gotStreamControllers.containsKey(gotId)) {
      _gotStreamControllers[gotId]!.add(got);
    }
  }

  // 리소스 해제를 위한 스트림 정리
  void disposeGOTStream(String gotId) {
    if (_gotStreamControllers.containsKey(gotId)) {
      _gotStreamControllers[gotId]!.close();
      _gotStreamControllers.remove(gotId);
    }
  }
}
