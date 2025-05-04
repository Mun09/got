import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:got/save_page.dart';

import 'memory_list_page.dart';

enum MemoryMode { none, recording, writing }

// 카메라 관리 클래스
class CameraManager {
  CameraController? controller;

  Future<void> initialize(List<CameraDescription> cameras) async {
    controller = CameraController(cameras[0], ResolutionPreset.medium);
    await controller!.initialize();
  }

  Future<void> startRecording() async {
    if (controller == null || controller!.value.isRecordingVideo) return;
    await controller!.startVideoRecording();
  }

  Future<XFile?> stopRecording() async {
    if (controller == null || !controller!.value.isRecordingVideo) return null;
    return await controller!.stopVideoRecording();
  }

  void dispose() {
    controller?.dispose();
  }
}

// 메모 작성 오버레이 위젯
class MemoOverlay extends StatelessWidget {
  final TextEditingController memoController;
  final VoidCallback onClose;
  final VoidCallback onSave;

  const MemoOverlay({
    required this.memoController,
    required this.onClose,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black,
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.white),
                onPressed: onClose,
              ),
            ),
            Expanded(
              child: TextField(
                controller: memoController,
                style: TextStyle(color: Colors.white),
                maxLines: null,
                expands: true,
                decoration: InputDecoration(
                  hintText: '메모를 작성하세요',
                  hintStyle: TextStyle(color: Colors.white54),
                  border: OutlineInputBorder(borderSide: BorderSide.none),
                ),
              ),
            ),
            ElevatedButton(onPressed: onSave, child: Text('메모 저장')),
          ],
        ),
      ),
    );
  }
}

// 메모 옵션 선택 위젯
class MemoryOptions extends StatelessWidget {
  final VoidCallback onRecordSelect;
  final VoidCallback onWriteSelect;

  const MemoryOptions({
    required this.onRecordSelect,
    required this.onWriteSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      children: [
        ListTile(
          leading: Icon(Icons.videocam, color: Colors.red),
          title: Text('동영상으로 저장'),
          onTap: onRecordSelect,
        ),
        ListTile(
          leading: Icon(Icons.edit, color: Colors.blue),
          title: Text('글로 저장'),
          onTap: onWriteSelect,
        ),
      ],
    );
  }
}

// 메인 화면 위젯
class CameraScreen extends StatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final CameraManager _cameraManager = CameraManager();
  final TextEditingController _memoController = TextEditingController();
  MemoryMode currentMode = MemoryMode.none;
  bool isRecording = false;
  bool showOptions = false; // 옵션 표시 여부를 저장하는 변수 추가

  late List<CameraDescription> cameras;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    cameras = await availableCameras();
    await _cameraManager.initialize(cameras);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _cameraManager.dispose();
    _memoController.dispose();
    super.dispose();
  }

  // 옵션을 토글하는 메서드
  void _toggleOptions() {
    setState(() {
      showOptions = !showOptions;
    });
  }

  // 메모리 모드 선택 처리
  void _selectMemoryMode(MemoryMode mode) {
    setState(() {
      currentMode = mode;
      showOptions = false; // 옵션 선택 후 옵션 패널 닫기
    });
  }

  void _openMemoryOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return MemoryOptions(
          onRecordSelect: () {
            Navigator.pop(context);
            setState(() => currentMode = MemoryMode.recording);
          },
          onWriteSelect: () {
            Navigator.pop(context);
            setState(() => currentMode = MemoryMode.writing);
          },
        );
      },
    );
  }

  Widget _buildMainButton() {
    if (currentMode == MemoryMode.none) {
      return Center(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey,
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          onPressed: _toggleOptions, // 바텀시트 대신 토글 함수 호출
          child: Text('메모 남기기', style: TextStyle(fontSize: 16)),
        ),
      );
    } else if (currentMode == MemoryMode.recording) {
      return Center(
        child: IconButton(
          iconSize: 60,
          icon: Icon(
            isRecording ? Icons.stop_circle : Icons.fiber_manual_record,
            color: isRecording ? Colors.grey : Colors.red,
          ),
          onPressed: () async {
            if (isRecording) {
              final file = await _cameraManager.stopRecording();
              if (file != null) {
                // Navigator.push 대신 Navigator.push와 결과 처리를 함께 사용
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VideoSavePage(videoFile: file),
                  ),
                );
                // 녹화 페이지에서 돌아오면 항상 상태 초기화
                setState(() {
                  isRecording = false;
                  currentMode = MemoryMode.none;
                });
              }
              print('Video saved to: ${file?.path}');
            } else {
              await _cameraManager.startRecording();
              setState(() => isRecording = true);
            }
          },
        ),
      );
    } else {
      // 메모 작성 모드일 때는 전체 화면 오버레이 사용
      return Container(); // 이 경우 별도로 처리
    }
  }

  Widget _buildOptionsPanel() {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      height: showOptions ? 100 : 0, // 높이를 더 증가시켜 충분한 공간 확보
      color: Colors.black,
      child:
          showOptions
              ? SingleChildScrollView(
                // 스크롤 가능하게 만들기
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // 동영상 버튼
                      ConstrainedBox(
                        // 크기 제약 추가
                        constraints: BoxConstraints(maxHeight: 140),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.videocam,
                                color: Colors.red,
                                size: 36,
                              ),
                              onPressed:
                                  () => _selectMemoryMode(MemoryMode.recording),
                              padding: EdgeInsets.all(4),
                            ),
                            Container(
                              width: 100,
                              child: Text(
                                '동영상으로 저장',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1, // 텍스트 한 줄로 제한
                                overflow: TextOverflow.ellipsis, // 넘치면 생략 부호 표시
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 텍스트 버튼
                      ConstrainedBox(
                        // 크기 제약 추가
                        constraints: BoxConstraints(maxHeight: 140),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.edit,
                                color: Colors.blue,
                                size: 36,
                              ),
                              onPressed:
                                  () => _selectMemoryMode(MemoryMode.writing),
                              padding: EdgeInsets.all(4),
                            ),
                            Container(
                              width: 100,
                              child: Text(
                                '글로 저장',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1, // 텍스트 한 줄로 제한
                                overflow: TextOverflow.ellipsis, // 넘치면 생략 부호 표시
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
              : null,
    );
  }

  Widget _buildCameraPreview() {
    if (_cameraManager.controller == null ||
        !_cameraManager.controller!.value.isInitialized) {
      return Center(child: CircularProgressIndicator());
    }

    // 화면 전체를 덮는 컨테이너를 만들고 그 안에 카메라 프리뷰 배치
    return Container(
      width: double.infinity,
      height: double.infinity,
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _cameraManager.controller!.value.previewSize!.height,
          height: _cameraManager.controller!.value.previewSize!.width,
          child: CameraPreview(_cameraManager.controller!),
        ),
      ),
    );
  }

  @override
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: currentMode == MemoryMode.none,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          if (currentMode == MemoryMode.recording && isRecording) {
            await _cameraManager.stopRecording();
          }

          setState(() {
            currentMode = MemoryMode.none;
            isRecording = false;
            _memoController.clear();
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: Icon(Icons.menu, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => MemoryListPage()),
                );
              },
            ),
          ],
        ),
        extendBodyBehindAppBar: true, // 앱바 뒤로 본문 확장
        body: Stack(
          children: [
            // 기본 레이아웃
            Column(
              children: [
                Expanded(flex: 85, child: _buildCameraPreview()),
                Expanded(
                  flex: 15,
                  child: Container(
                    width: double.infinity,
                    color: Colors.black,
                    child: _buildMainButton(),
                  ),
                ),
              ],
            ),
            // 메모 오버레이 (메모 작성 모드일 때만 표시)
            if (currentMode == MemoryMode.writing)
              MemoOverlay(
                memoController: _memoController,
                onClose: () {
                  setState(() {
                    currentMode = MemoryMode.none;
                    _memoController.clear();
                  });
                },
                onSave: () {
                  print('Saved memo: ${_memoController.text}');
                  _memoController.clear();
                  setState(() => currentMode = MemoryMode.none);
                },
              ),
            // 옵션 패널을 하단에 배치
            Positioned(
              bottom: MediaQuery.of(context).size.height * 0.15,
              left: 0,
              right: 0,
              child: _buildOptionsPanel(),
            ),
          ],
        ),
      ),
    );
  }
}
