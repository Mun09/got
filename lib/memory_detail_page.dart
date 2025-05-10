import 'dart:io';

import 'package:flutter/material.dart';
import 'package:got/services/memory_service.dart';
import 'package:got/util/util.dart';
import 'package:got/widget/media_display_widget.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'models/memory.dart';

class MemoryDetailPage extends StatefulWidget {
  final Memory memory;

  const MemoryDetailPage({super.key, required this.memory});

  @override
  State<MemoryDetailPage> createState() => _MemoryDetailPageState();
}

class _MemoryDetailPageState extends State<MemoryDetailPage> {
  late MemoryService _memoryService;
  late Memory _memory;
  bool _isEditing = false;
  late TextEditingController _memoController;
  late TextEditingController _nameController; // 추가: 이름을 위한 컨트롤러
  late List<String> _editedFilePaths;
  double? _editedLatitude;
  double? _editedLongitude;

  @override
  void initState() {
    super.initState();
    _memoryService = Provider.of<MemoryService>(context, listen: false);

    // 초기값은 위젯에서 받은 메모리로 설정
    _memory = widget.memory;
    _nameController = TextEditingController(
      text: _memory.memoryName,
    ); // 추가: 이름 컨트롤러 초기화
    _memoController = TextEditingController(text: _memory.memo);
    _editedFilePaths = List.from(_memory.filePaths);
    _editedLatitude = _memory.latitude;
    _editedLongitude = _memory.longitude;

    // 서비스를 통해 최신 데이터 로드
    _loadMemoryData();
  }

  Future<void> _loadMemoryData() async {
    print('메모리 데이터 로드');
    try {
      final updatedMemory = await _memoryService.getMemoryById(
        widget.memory.id,
      );
      if (updatedMemory != null && mounted) {
        setState(() {
          _memory = updatedMemory;
          _nameController.text = updatedMemory.memoryName; // 추가: 이름 업데이트
          _memoController.text = updatedMemory.memo;
          _editedFilePaths = List.from(updatedMemory.filePaths);
          _editedLatitude = updatedMemory.latitude;
          _editedLongitude = updatedMemory.longitude;
        });
      }
    } catch (e) {
      print('메모리 데이터 로드 오류: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose(); // 추가: 컨트롤러 해제
    _memoController.dispose();

    super.dispose();
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
        Navigator.pop(context, true); // 상세 화면 닫기
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('삭제 중 오류가 발생했습니다: $e')));
      }
    }
  }

  Future<void> _saveChanges() async {
    try {
      // 수정된 메모리 객체 생성
      Memory updatedMemory = Memory(
        id: widget.memory.id,
        memoryName: _nameController.text,
        filePaths: _editedFilePaths,
        memo: _memoController.text,
        createdAt: _memory.createdAt,
        latitude: _editedLatitude,
        longitude: _editedLongitude,
      );

      await _memoryService.updateMemory(updatedMemory);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('변경사항이 저장되었습니다')));

      _loadMemoryData();
      setState(() {
        _isEditing = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('저장 중 오류가 발생했습니다: $e')));
    }
  }

  // 미디어 파일 추가
  Future<void> _addMedia() async {
    // 이 부분은 이미지/비디오 선택 로직 구현 필요
    // 예: 갤러리에서 파일 선택
    final result = await ImagePicker().pickImage(source: ImageSource.gallery);

    if (result != null) {
      setState(() {
        _editedFilePaths.add(result.path);
      });
    }
  }

  // 미디어 파일 삭제
  void _removeMedia(int index) {
    setState(() {
      _editedFilePaths.removeAt(index);
    });
  }

  // 위치 정보 수정
  Future<void> _updateLocation() async {
    // 위치 정보 수정 다이얼로그
    final result = await showDialog<Map<String, double>?>(
      context: context,
      builder:
          (context) => LocationEditDialog(
            initialLatitude: _editedLatitude,
            initialLongitude: _editedLongitude,
          ),
    );

    if (result != null) {
      setState(() {
        _editedLatitude = result['latitude'];
        _editedLongitude = result['longitude'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MemoryService>(
      builder: (context, memoryService, child) {
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            title: Text('곳 상세'),
            actions: [
              IconButton(
                icon: Icon(_isEditing ? Icons.save : Icons.edit),
                onPressed: () {
                  if (_isEditing) {
                    _saveChanges();
                  } else {
                    setState(() {
                      _isEditing = true;
                    });
                  }
                },
              ),
              if (_isEditing)
                IconButton(
                  icon: Icon(Icons.cancel),
                  onPressed: () {
                    // 편집 취소 및 원래 상태로 복원
                    setState(() {
                      _isEditing = false;
                      _memoController.text = _memory.memo;
                      _editedFilePaths = List.from(_memory.filePaths);
                      _editedLatitude = _memory.latitude;
                      _editedLongitude = _memory.longitude;
                    });
                  },
                ),
              if (!_isEditing)
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
                        // 미디어 영역
                        if (_isEditing) ...[
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: TextField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: '장소 이름',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),

                          // 미디어 편집 UI
                          Container(
                            height: 200,
                            padding: EdgeInsets.all(8),
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _editedFilePaths.length + 1,
                              // +1은 추가 버튼
                              itemBuilder: (context, index) {
                                if (index == _editedFilePaths.length) {
                                  // 미디어 추가 버튼
                                  return InkWell(
                                    onTap: _addMedia,
                                    child: Container(
                                      width: 120,
                                      margin: EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Center(
                                        child: Icon(
                                          Icons.add_photo_alternate,
                                          size: 40,
                                        ),
                                      ),
                                    ),
                                  );
                                } else {
                                  // 기존 미디어 파일 표시
                                  return Stack(
                                    children: [
                                      Container(
                                        width: 120,
                                        margin: EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          image: DecorationImage(
                                            image: FileImage(
                                              File(_editedFilePaths[index]),
                                            ),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 0,
                                        right: 0,
                                        child: IconButton(
                                          icon: Icon(
                                            Icons.remove_circle,
                                            color: Colors.red,
                                          ),
                                          onPressed: () => _removeMedia(index),
                                        ),
                                      ),
                                    ],
                                  );
                                }
                              },
                            ),
                          ),
                        ] else ...[
                          // 일반 미디어 표시
                          MediaDisplayWidget(
                            showControls: true,
                            memory: _memory,
                          ),
                        ],

                        // 메모 내용
                        Container(
                          padding: EdgeInsets.all(16),
                          color: Colors.white,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_isEditing) ...[
                                TextField(
                                  controller: _memoController,
                                  decoration: InputDecoration(
                                    labelText: '메모',
                                    border: OutlineInputBorder(),
                                  ),
                                  maxLines: 5,
                                ),
                              ] else ...[
                                Text(
                                  _memoController.text,
                                  style: TextStyle(fontSize: 18),
                                ),
                              ],
                              SizedBox(height: 12),
                              Text(
                                formatDate(widget.memory.createdAt),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(height: 8),

                              // 위치 정보 영역
                              if (_isEditing) ...[
                                // 위치 수정 UI
                                ElevatedButton(
                                  onPressed: _updateLocation,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.edit_location_alt),
                                      SizedBox(width: 8),
                                      Text('위치 정보 수정'),
                                    ],
                                  ),
                                ),
                                if (_editedLatitude != null &&
                                    _editedLongitude != null) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      '위도: ${_editedLatitude!.toStringAsFixed(6)}, '
                                      '경도: ${_editedLongitude!.toStringAsFixed(6)}',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ] else ...[
                                // 일반 위치 표시
                                if (_memory.latitude != null &&
                                    _memory.longitude != null) ...[
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
                                            future:
                                                widget.memory
                                                    .getLocationString(),
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
                                          '위도: ${_memory.latitude!.toStringAsFixed(6)}, '
                                          '경도: ${_memory.longitude!.toStringAsFixed(6)}',
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
      },
    );
  }
}

class LocationEditDialog extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;

  const LocationEditDialog({
    Key? key,
    this.initialLatitude,
    this.initialLongitude,
  }) : super(key: key);

  @override
  State<LocationEditDialog> createState() => _LocationEditDialogState();
}

class _LocationEditDialogState extends State<LocationEditDialog> {
  late TextEditingController _latController;
  late TextEditingController _lngController;

  @override
  void initState() {
    super.initState();
    _latController = TextEditingController(
      text: widget.initialLatitude?.toString() ?? '',
    );
    _lngController = TextEditingController(
      text: widget.initialLongitude?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('위치 정보 수정'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _latController,
            decoration: InputDecoration(labelText: '위도'),
            keyboardType: TextInputType.numberWithOptions(decimal: true),
          ),
          TextField(
            controller: _lngController,
            decoration: InputDecoration(labelText: '경도'),
            keyboardType: TextInputType.numberWithOptions(decimal: true),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('취소')),
        TextButton(
          onPressed: () {
            // 입력값 검증
            try {
              final lat =
                  _latController.text.isEmpty
                      ? null
                      : double.parse(_latController.text);
              final lng =
                  _lngController.text.isEmpty
                      ? null
                      : double.parse(_lngController.text);
              Navigator.pop(context, {'latitude': lat, 'longitude': lng});
            } catch (e) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('올바른 숫자 형식을 입력하세요')));
            }
          },
          child: Text('확인'),
        ),
      ],
    );
  }
}
