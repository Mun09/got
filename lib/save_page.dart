import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:video_player/video_player.dart';

import 'memory_service.dart';

class VideoSavePage extends StatefulWidget {
  final XFile videoFile;

  const VideoSavePage({Key? key, required this.videoFile}) : super(key: key);

  @override
  State<VideoSavePage> createState() => _VideoSavePageState();
}

class _VideoSavePageState extends State<VideoSavePage> {
  final TextEditingController _filenameController = TextEditingController();
  final TextEditingController _memoController =
      TextEditingController(); // 메모 컨트롤러 추가
  bool _isSaving = false;
  String? _savedPath;
  String? _currentLocation;
  bool _isLoadingLocation = true;

  // 지도 관련 변수
  Position? _currentPosition;
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};

  // 비디오 플레이어 관련 변수
  late VideoPlayerController _videoPlayerController;
  bool _isVideoInitialized = false;
  bool _isMuted = true;

  @override
  void initState() {
    super.initState();
    // 기본 파일명 설정 (현재 날짜와 시간)
    _filenameController.text =
        'Video_${DateTime.now().toString().replaceAll(' ', '_').replaceAll(':', '-').split('.')[0]}';

    // 위치 정보 가져오기
    _getCurrentLocation();

    // 비디오 플레이어 초기화
    _initializeVideoPlayer();
  }

  // 비디오 플레이어 초기화
  Future<void> _initializeVideoPlayer() async {
    _videoPlayerController = VideoPlayerController.file(
      File(widget.videoFile.path),
    );

    await _videoPlayerController.initialize();

    // 무한 루프 설정
    _videoPlayerController.setLooping(true);

    // 기본 음소거 설정
    _videoPlayerController.setVolume(0.0);

    // 비디오 자동 재생
    _videoPlayerController.play();

    if (mounted) {
      setState(() {
        _isVideoInitialized = true;
      });
    }
  }

  // 현재 위치 정보 가져오기
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      // 위치 권한 확인
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _currentLocation = "위치 권한이 거부되었습니다";
            _isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _currentLocation = "위치 권한이 영구적으로 거부되었습니다";
          _isLoadingLocation = false;
        });
        return;
      }

      // 현재 위치 가져오기
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 현재 위치 저장
      setState(() {
        _currentPosition = position;
      });

      // 마커 추가
      _addMarker(position);

      // 좌표를 주소로 변환
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _currentLocation =
              "${place.locality ?? ''} ${place.subLocality ?? ''} ${place.thoroughfare ?? ''}";
          _isLoadingLocation = false;
        });
      } else {
        setState(() {
          _currentLocation =
              "위도: ${position.latitude}, 경도: ${position.longitude}";
          _isLoadingLocation = false;
        });
      }
    } catch (e) {
      setState(() {
        _currentLocation = "위치를 가져올 수 없습니다";
        _isLoadingLocation = false;
      });
      print("위치 정보 오류: $e");
    }
  }

  // 지도에 마커 추가
  void _addMarker(Position position) {
    final marker = Marker(
      markerId: MarkerId('current_location'),
      position: LatLng(position.latitude, position.longitude),
      infoWindow: InfoWindow(
        title: '촬영 위치',
        snippet: _currentLocation ?? '현재 위치',
      ),
    );

    setState(() {
      _markers.clear();
      _markers.add(marker);
    });
  }

  // 지도 생성 완료 시 호출
  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;

    // 현재 위치가 있으면 지도 카메라 이동
    if (_currentPosition != null) {
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
            ),
            zoom: 15,
          ),
        ),
      );
    }
  }

  // 비디오 음소거/음소거 해제 토글
  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _videoPlayerController.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  @override
  void dispose() {
    _filenameController.dispose();
    _memoController.dispose(); // 메모 컨트롤러 dispose 추가
    _mapController?.dispose();
    _videoPlayerController.dispose();
    super.dispose();
  }

  // 비디오 저장 처리
  Future<void> _saveVideo() async {
    if (_filenameController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('파일 이름을 입력해주세요')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final directory = await getApplicationDocumentsDirectory();
      final String outputPath =
          '${directory.path}/${_filenameController.text}.mp4';

      final File sourceFile = File(widget.videoFile.path);
      final File savedFile = await sourceFile.copy(outputPath);

      final memoryService = MemoryService();
      await memoryService.saveMemory(
        outputPath,
        _memoController.text,
        _currentPosition?.latitude,
        _currentPosition?.longitude,
      );

      setState(() => _savedPath = outputPath);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_filenameController.text}.mp4 파일이 저장되었습니다'),
          backgroundColor: Colors.green,
        ),
      );

      Future.delayed(Duration(seconds: 2), () {
        if (mounted) Navigator.pop(context);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('저장 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('비디오 저장'), backgroundColor: Colors.black),
      body: Column(
        children: [
          // 스크롤 가능한 콘텐츠 영역
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 비디오 미리보기
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child:
                            _isVideoInitialized
                                ? Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    GestureDetector(
                                      onTap: _toggleMute,
                                      child: AspectRatio(
                                        aspectRatio:
                                            _videoPlayerController
                                                .value
                                                .aspectRatio,
                                        child: VideoPlayer(
                                          _videoPlayerController,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 10,
                                      right: 10,
                                      child: Container(
                                        padding: EdgeInsets.all(5),
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius: BorderRadius.circular(
                                            15,
                                          ),
                                        ),
                                        child: Icon(
                                          _isMuted
                                              ? Icons.volume_off
                                              : Icons.volume_up,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                                : Center(child: CircularProgressIndicator()),
                      ),
                    ),
                    SizedBox(height: 10),

                    // 지도 표시
                    Container(
                      height: 150,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child:
                          _currentPosition == null
                              ? Center(
                                child:
                                    _isLoadingLocation
                                        ? CircularProgressIndicator()
                                        : Text('위치 정보를 가져올 수 없습니다'),
                              )
                              : ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: GoogleMap(
                                  initialCameraPosition: CameraPosition(
                                    target: LatLng(
                                      _currentPosition!.latitude,
                                      _currentPosition!.longitude,
                                    ),
                                    zoom: 15,
                                  ),
                                  markers: _markers,
                                  mapType: MapType.normal,
                                  onMapCreated: _onMapCreated,
                                  myLocationEnabled: true,
                                  myLocationButtonEnabled: true,
                                  zoomControlsEnabled: false,
                                ),
                              ),
                    ),
                    SizedBox(height: 10),

                    // 위치 정보 표시
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 16, color: Colors.blue),
                        SizedBox(width: 8),
                        _isLoadingLocation
                            ? Text(
                              "위치 정보 로딩 중...",
                              style: TextStyle(fontStyle: FontStyle.italic),
                            )
                            : Expanded(
                              child: Text(_currentLocation ?? "위치 정보 없음"),
                            ),
                      ],
                    ),
                    SizedBox(height: 15),

                    // 파일명 입력 필드
                    TextField(
                      controller: _filenameController,
                      decoration: InputDecoration(
                        labelText: '저장할 파일 이름',
                        border: OutlineInputBorder(),
                        suffixText: '.mp4',
                      ),
                    ),

                    SizedBox(height: 15),

                    // 메모 입력 필드 추가
                    TextField(
                      controller: _memoController,
                      decoration: InputDecoration(
                        labelText: '메모',
                        border: OutlineInputBorder(),
                        hintText: '기억에 남기고 싶은 내용을 작성해보세요.',
                      ),
                      maxLines: 3, // 여러 줄 입력 가능하도록 설정
                    ),
                    SizedBox(height: 15),
                  ],
                ),
              ),
            ),
          ),

          // 하단에 고정된 버튼 영역
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: Offset(0, -1),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 저장 버튼
                ElevatedButton(
                  onPressed:
                      _savedPath != null
                          ? null
                          : (_isSaving ? null : _saveVideo),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue,
                  ),
                  child:
                      _isSaving
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text(
                            _savedPath != null ? '저장됨' : '저장하기',
                            style: TextStyle(fontSize: 16),
                          ),
                ),
                SizedBox(height: 10),

                // 취소 버튼
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text('돌아가기'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
