import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class CameraScreen extends StatefulWidget {
  // 초기 모드 파라미터 제거
  const CameraScreen({Key? key}) : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraManager _cameraManager;
  bool isRecording = false;
  bool isPhotoMode = true; // 기본은 사진 모드

  @override
  void initState() {
    super.initState();
    _cameraManager = CameraManager();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    await _cameraManager.initialize();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _cameraManager.dispose();
    super.dispose();
  }

  void _toggleCameraMode() {
    if (isRecording) return; // 녹화 중에는 모드 전환 불가능
    setState(() {
      isPhotoMode = !isPhotoMode;
    });
  }

  // 미디어 캡처 처리
  Future<void> _handleMediaCapture() async {
    if (isPhotoMode) {
      // 사진 촬영
      final XFile? photoFile = await _capturePhoto();
      if (photoFile != null && mounted) {
        Navigator.pop(context, photoFile);
      }
    } else {
      // 동영상 녹화
      if (isRecording) {
        final XFile? videoFile = await _cameraManager.stopRecording();
        setState(() => isRecording = false);
        if (videoFile != null && mounted) {
          Navigator.pop(context, videoFile);
        }
      } else {
        await _cameraManager.startRecording();
        setState(() => isRecording = true);
      }
    }
  }

  // 사진 촬영
  Future<XFile?> _capturePhoto() async {
    try {
      if (_cameraManager.controller != null &&
          _cameraManager.controller!.value.isInitialized) {
        final XFile file = await _cameraManager.controller!.takePicture();
        return file;
      }
    } catch (e) {
      print('사진 촬영 오류: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraManager.controller == null ||
        !_cameraManager.controller!.value.isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // 카메라 미리보기
            Positioned.fill(
              child: AspectRatio(
                aspectRatio: _cameraManager.controller!.value.aspectRatio,
                child: CameraPreview(_cameraManager.controller!),
              ),
            ),

            // 상단 컨트롤 바
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.black54,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 나가기 버튼
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),

                    // 카메라 전환 버튼
                    IconButton(
                      icon: Icon(Icons.flip_camera_ios, color: Colors.white),
                      onPressed: () {
                        if (!isRecording) {
                          _cameraManager.toggleCamera();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),

            // 하단 컨트롤 바
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 왼쪽 빈 공간 (균형을 위해)
                  SizedBox(width: 70),

                  // 가운데 촬영 버튼
                  GestureDetector(
                    onTap: _handleMediaCapture,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        color: isRecording ? Colors.red : Colors.transparent,
                      ),
                      child:
                          isRecording
                              ? Icon(Icons.stop, color: Colors.white, size: 30)
                              : isPhotoMode
                              ? null
                              : Icon(
                                Icons.videocam,
                                color: Colors.white,
                                size: 30,
                              ),
                    ),
                  ),

                  // 오른쪽 모드 전환 버튼 (추가됨)
                  GestureDetector(
                    onTap: _toggleCameraMode,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black54,
                      ),
                      child: Icon(
                        isPhotoMode ? Icons.videocam : Icons.photo_camera,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 녹화 중 표시
            if (isRecording)
              Positioned(
                top: 60,
                right: 20,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.circle, color: Colors.white, size: 12),
                      SizedBox(width: 4),
                      Text('녹화 중', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ),

            // 현재 모드 표시 (하단에 추가)
            Positioned(
              bottom: 110,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isPhotoMode ? '사진 모드' : '동영상 모드',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 카메라 관리 클래스
class CameraManager {
  List<CameraDescription> cameras = [];
  CameraController? controller;
  int selectedCameraIndex = 0;

  Future<void> initialize() async {
    try {
      cameras = await availableCameras();
      if (cameras.isEmpty) return;

      await _initializeCameraController();
    } catch (e) {
      print('카메라 초기화 오류: $e');
    }
  }

  Future<void> _initializeCameraController() async {
    if (cameras.isEmpty) return;

    if (controller != null) {
      await controller!.dispose();
    }

    controller = CameraController(
      cameras[selectedCameraIndex],
      ResolutionPreset.high,
      enableAudio: true,
    );

    await controller!.initialize();
  }

  Future<void> toggleCamera() async {
    selectedCameraIndex = (selectedCameraIndex + 1) % cameras.length;
    await _initializeCameraController();
  }

  Future<void> startRecording() async {
    if (controller == null || !controller!.value.isInitialized) return;
    await controller!.startVideoRecording();
  }

  Future<XFile?> stopRecording() async {
    if (controller == null || !controller!.value.isInitialized) return null;
    return await controller!.stopVideoRecording();
  }

  void dispose() {
    controller?.dispose();
  }
}
