import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:got/sevices/location_service.dart';
import 'package:got/util.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:video_player/video_player.dart';

import 'camera_screen.dart';
import 'memory_service.dart';

class FileSavePage extends StatefulWidget {
  const FileSavePage({Key? key}) : super(key: key);

  @override
  State<FileSavePage> createState() => _FileSavePageState();
}

class _FileSavePageState extends State<FileSavePage> {
  final TextEditingController _filenameController = TextEditingController();
  final TextEditingController _memoController =
      TextEditingController(); // 메모 컨트롤러 추가
  bool _isSaving = false;
  String? _savedPath;
  String? _currentLocation;
  Position? _selectedPosition;
  String? _selectedLocationAddress;

  bool _isLoadingLocation = true;
  XFile? _currentFile;

  // 지도 관련 변수
  Position? _currentPosition;
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};

  // 비디오 플레이어 관련 변수
  late VideoPlayerController _videoPlayerController;
  bool _isVideoInitialized = false;
  bool _isMuted = true;

  final LocationService _locationService = LocationService();

  @override
  void initState() {
    super.initState();

    // 기본 파일명 설정 (현재 날짜와 시간)
    _filenameController.text =
        'Video_${DateTime.now().toString().replaceAll(' ', '_').replaceAll(':', '-').split('.')[0]}';

    // 위치 정보 가져오기
    _locationService.addListener(_updateLocationInfo);
    _updateLocationInfo();
  }

  // 위치 정보 업데이트 함수
  void _updateLocationInfo() {
    if (!mounted) return;
    final position = _locationService.currentPosition;
    final address = _locationService.currentAddress;

    setState(() {
      _currentPosition = position;
      _currentLocation = address ?? "주소 정보 없음";
      _isLoadingLocation = _locationService.isLoading;

      // 선택된 위치가 없을 경우에만 현재 위치를 선택 위치로 설정
      if (_selectedPosition == null) {
        _selectedPosition = position;
        _selectedLocationAddress = _currentLocation;

        // 현재 위치에 마커 추가
        if (_markers.isEmpty && position != null) {
          _addMarker(position, isUserSelection: false);
        }
      }
    });
  }

  // 비디오 플레이어 초기화 메서드
  Future<void> _initializeVideoPlayer() async {
    if (_currentFile == null) return;

    // 기존 컨트롤러가 있다면 해제
    if (_isVideoInitialized) {
      await _videoPlayerController.dispose();
    }

    _videoPlayerController = VideoPlayerController.file(
      File(_currentFile!.path),
    );

    try {
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
    } catch (e) {
      print('비디오 초기화 오류: $e');
      // 이미지일 경우 초기화 오류가 발생할 수 있음
      setState(() {
        _isVideoInitialized = false;
      });
    }
  }

  // 미디어 선택 옵션을 표시하는 메서드
  void _showMediaOptions() {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.photo_camera),
                  title: Text('직접 촬영하기'),
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToCamera();
                  },
                ),
                // 갤러리에서 이미지 선택 옵션 추가
                ListTile(
                  leading: Icon(Icons.photo_library),
                  title: Text('갤러리에서 이미지 선택'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromGallery();
                  },
                ),
                // 갤러리에서 동영상 선택 옵션 추가
                ListTile(
                  leading: Icon(Icons.video_library),
                  title: Text('갤러리에서 동영상 선택'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickVideoFromGallery();
                  },
                ),
              ],
            ),
          ),
    );
  }

  // 갤러리에서 이미지 선택 메서드 추가
  Future<void> _pickImageFromGallery() async {
    final picker = ImagePicker();
    final XFile? pickedImage = await picker.pickImage(
      source: ImageSource.gallery,
    );

    if (pickedImage != null) {
      setState(() {
        _currentFile = pickedImage;
        _isVideoInitialized = false;
      });
    }
  }

  // 갤러리에서 동영상 선택 메서드 추가
  Future<void> _pickVideoFromGallery() async {
    final picker = ImagePicker();
    final XFile? pickedVideo = await picker.pickVideo(
      source: ImageSource.gallery,
    );

    if (pickedVideo != null) {
      setState(() {
        _currentFile = pickedVideo;
        _isVideoInitialized = false;
      });
      _initializeVideoPlayer();
    }
  }

  // 카메라 화면으로 이동하는 메서드
  Future<void> _navigateToCamera() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CameraScreen()),
    );

    if (result != null && result is XFile) {
      setState(() {
        _currentFile = result;
        _isVideoInitialized = false;
      });

      if (isVideoFile(result.path)) {
        _initializeVideoPlayer();
      }
    }
  }

  // 비디오/미디어 영역 위젯
  Widget _buildMediaPreview() {
    return GestureDetector(
      onTap: _showMediaOptions,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child:
              _currentFile != null
                  ? (_isVideoInitialized &&
                          _videoPlayerController.value.isInitialized
                      ? Stack(
                        alignment: Alignment.center,
                        children: [
                          AspectRatio(
                            aspectRatio:
                                _videoPlayerController.value.aspectRatio,
                            child: VideoPlayer(_videoPlayerController),
                          ),
                          Positioned(
                            bottom: 10,
                            right: 10,
                            child: GestureDetector(
                              onTap: _toggleMute,
                              child: Container(
                                padding: EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Icon(
                                  _isMuted ? Icons.volume_off : Icons.volume_up,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                      : isImageFile(_currentFile!.path)
                      ? Image.file(File(_currentFile!.path), fit: BoxFit.cover)
                      : Center(child: CircularProgressIndicator()))
                  : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('사진 또는 동영상 추가하기'),
                      ],
                    ),
                  ),
        ),
      ),
    );
  }

  // 지도에 마커 추가
  void _addMarker(Position position, {bool isUserSelection = false}) {
    final marker = Marker(
      markerId: MarkerId('selected_location'),
      position: LatLng(position.latitude, position.longitude),
      infoWindow: InfoWindow(
        title: isUserSelection ? '선택한 위치' : '현재 위치',
        snippet: isUserSelection ? _selectedLocationAddress : _currentLocation,
      ),
    );

    setState(() {
      _markers.clear();
      _markers.add(marker);

      // 사용자 선택 위치인 경우 정보 업데이트
      if (isUserSelection) {
        _selectedPosition = position;
        _updateSelectedLocationAddress(position);
      }
    });

    // 지도 컨트롤러가 있으면 카메라 이동
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 15,
          ),
        ),
      );
    }
  }

  // 선택된 위치의 주소 가져오기
  Future<void> _updateSelectedLocationAddress(Position position) async {
    try {
      setState(() {
        _selectedLocationAddress = "주소 정보를 가져오는 중...";
      });

      print("위도: ${position.latitude}, 경도: ${position.longitude}");

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      print("Geocoding 결과: $placemarks");

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String locationAddress = [
          place.street,
          place.subLocality,
          place.locality,
          place.administrativeArea,
          place.country,
        ].where((item) => item != null && item.isNotEmpty).join(', ');

        print("최종 주소: $locationAddress"); // 디버깅용 로그

        // 상태 업데이트 - mounted 체크 추가
        if (mounted) {
          setState(() {
            _selectedLocationAddress = locationAddress;
            print("주소 정보 상태 업데이트 완료"); // 상태 업데이트 확인용 로그
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _selectedLocationAddress = "주소 정보 없음";
          });
        }
      }
    } catch (e) {
      print("주소 변환 오류: $e");
      if (mounted) {
        setState(() {
          _selectedLocationAddress = "주소 정보를 가져올 수 없음";
        });
      }
    }
  }

  // 지도 생성 완료 시 호출
  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;

    // 현재 위치가 있으면 지도 카메라 이동
    final targetPosition = _selectedPosition ?? _currentPosition;
    if (targetPosition != null) {
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(targetPosition.latitude, targetPosition.longitude),
            zoom: 15,
          ),
        ),
      );

      _addMarker(targetPosition, isUserSelection: _selectedPosition != null);
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
    if (_videoPlayerController != null) {
      _videoPlayerController.dispose();
    }
    // 리스너 제거
    _locationService.removeListener(_updateLocationInfo);
    _locationService.dispose();
    super.dispose();
  }

  // 비디오 저장 처리
  Future<void> _saveFile() async {
    if (_filenameController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('파일 이름을 입력해주세요')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final memoryService = MemoryService();
      String? outputPath;

      if (_currentFile != null) {
        final directory = await getApplicationDocumentsDirectory();
        String extension = isVideoFile(_currentFile!.path) ? '.mp4' : '.jpg';

        outputPath = '${directory.path}/${_filenameController.text}$extension';

        final File sourceFile = File(_currentFile!.path);
        await sourceFile.copy(outputPath);
      }

      // 선택된 위치가 있으면 해당 위치 사용, 없으면 현재 위치 사용
      final latitude =
          _selectedPosition?.latitude ??
          _locationService.currentPosition?.latitude;
      final longitude =
          _selectedPosition?.longitude ??
          _locationService.currentPosition?.longitude;

      await memoryService.saveMemory(
        outputPath, // 파일이 없으면 null
        _memoController.text,
        latitude,
        longitude,
      );

      setState(() => _savedPath = outputPath);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('메모리가 저장되었습니다'), backgroundColor: Colors.green),
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

  // 지도 모달 표시 함수
  void _showMapModal() {
    // 초기 마커 상태와 위치 정보 저장
    Set<Marker> initialMarkers = Set<Marker>.from(_markers);
    Position? tempSelectedPosition = _selectedPosition;
    GoogleMapController? modalMapController;
    String? modalLocationAddress = _selectedLocationAddress;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        Set<Marker> modalMarkers = Set<Marker>.from(_markers);

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.all(0),
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              return Container(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height * 0.9,
                margin: EdgeInsets.symmetric(horizontal: 8, vertical: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    // 헤더
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '위치 선택',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Row(
                            children: [
                              TextButton(
                                onPressed: () {
                                  // 변경사항 취소 시 원래 상태로 복원
                                  setState(() {
                                    _markers = initialMarkers;
                                    _selectedPosition = tempSelectedPosition;
                                  });
                                  Navigator.pop(context);
                                },
                                child: Text('취소'),
                              ),
                              SizedBox(width: 8),
                              TextButton(
                                onPressed: () {
                                  // 확인 시 모달의 상태를 부모에게 반영
                                  Navigator.pop(context);
                                },
                                child: Text('확인'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: LatLng(
                              _selectedPosition?.latitude ??
                                  _currentPosition?.latitude ??
                                  37.5665,
                              _selectedPosition?.longitude ??
                                  _currentPosition?.longitude ??
                                  126.9780,
                            ),
                            zoom: 15,
                          ),
                          markers: modalMarkers,
                          mapType: MapType.normal,
                          myLocationEnabled: true,
                          myLocationButtonEnabled: true,
                          zoomControlsEnabled: false,
                          compassEnabled: true,
                          onMapCreated: (GoogleMapController controller) {
                            modalMapController = controller;
                          },
                          onTap: (LatLng position) async {
                            // 위치 선택 처리
                            final newPosition = Position(
                              latitude: position.latitude,
                              longitude: position.longitude,
                              timestamp: DateTime.now(),
                              accuracy: 0,
                              altitude: 0,
                              heading: 0,
                              speed: 0,
                              speedAccuracy: 0,
                              altitudeAccuracy: 0,
                              headingAccuracy: 0,
                            );

                            // 마커 생성
                            final marker = Marker(
                              markerId: MarkerId('selected_location'),
                              position: position,
                              infoWindow: InfoWindow(title: '선택한 위치'),
                            );

                            // 모달 내 상태 즉시 업데이트 (로딩 표시)
                            setModalState(() {
                              modalMarkers.clear();
                              modalMarkers.add(marker);
                            });

                            // 부모 위젯 상태도 업데이트
                            if (mounted) {
                              setState(() {
                                _markers.clear();
                                _markers.add(marker);
                                _selectedPosition = newPosition;
                              });
                            }

                            // 선택한 위치의 주소 업데이트
                            _updateSelectedLocationAddress(newPosition).then((
                              value,
                            ) {
                              if (context.mounted) {
                                setModalState(() {
                                  modalLocationAddress =
                                      _selectedLocationAddress;
                                });
                              }
                            });

                            if (modalMapController != null) {
                              await modalMapController!.animateCamera(
                                CameraUpdate.newCameraPosition(
                                  CameraPosition(target: position, zoom: 15.0),
                                ),
                              );
                            }
                          },
                          gestureRecognizers:
                              <Factory<OneSequenceGestureRecognizer>>{
                                Factory<OneSequenceGestureRecognizer>(
                                  () => EagerGestureRecognizer(),
                                ),
                              },
                        ),
                      ),
                    ),

                    // 선택 위치 정보 (모달 내부 상태 변수 사용)
                    Container(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.blue),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              modalLocationAddress ??
                                  (_selectedPosition != null
                                      ? "위치 정보 로딩 중..."
                                      : "위치를 선택하세요"),
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    ).then((_) {
      // 모달 닫힌 후 컨트롤러 해제
      modalMapController?.dispose();
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(
                _selectedPosition!.latitude,
                _selectedPosition!.longitude,
              ),
              zoom: 15.0,
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('비디오 저장'), backgroundColor: Colors.white),
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
                    _buildMediaPreview(),
                    SizedBox(height: 10),

                    // 지도 표시
                    Container(
                      height: 250,
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
                              : GestureDetector(
                                onTap: _showMapModal, // 지도 클릭 시 모달 표시
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: GoogleMap(
                                        initialCameraPosition: CameraPosition(
                                          target: LatLng(
                                            _selectedPosition?.latitude ??
                                                _currentPosition!.latitude,
                                            _selectedPosition?.longitude ??
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
                                        zoomGesturesEnabled: true,
                                        // 모달에서만 탭 이벤트 처리하도록 onTap 제거
                                      ),
                                    ),
                                    Positioned(
                                      top: 5,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        alignment: Alignment.center,
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(
                                              0.8,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Text(
                                            '지도를 탭하여 위치를 선택하세요',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    // 전체 화면 지도를 위한 투명 오버레이 추가
                                    Positioned.fill(
                                      child: Container(
                                        color: Colors.transparent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                    ),

                    SizedBox(height: 10),

                    // 위치 정보 표시
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 16, color: Colors.blue),
                        SizedBox(width: 8),
                        _selectedPosition != null
                            ? Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedLocationAddress ??
                                        "선택한 위치 정보 로딩 중...",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (_currentLocation != null &&
                                      _currentLocation!.isNotEmpty)
                                    Text(
                                      "현재 위치: $_currentLocation",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                ],
                              ),
                            )
                            : _isLoadingLocation
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
                          : (_isSaving ? null : _saveFile),
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
