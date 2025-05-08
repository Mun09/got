import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:got/services/location_service.dart';
import 'package:got/services/memory_service.dart';
import 'package:got/services/settings_service.dart';
import 'package:got/widget/location_picker_dialog_widget.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import 'camera_screen.dart';
import 'util/util.dart';
import 'widget/location_info_widget.dart';
import 'widget/map_preview_widget.dart';
import 'widget/media_preview_widget.dart';
import 'package:path/path.dart' as path;

class FileSavePage extends StatefulWidget {
  const FileSavePage({Key? key}) : super(key: key);

  @override
  State<FileSavePage> createState() => _FileSavePageState();
}

class _FileSavePageState extends State<FileSavePage> {
  // 컨트롤러
  final TextEditingController _filenameController = TextEditingController();
  final TextEditingController _memoController = TextEditingController();

  // 저장 관련 상태
  bool _isSaving = false;
  List<String> _savedPaths = [];

  // 위치 정보
  late LocationService _locationService;
  late SettingsService _settingsService;
  late bool _useCurrentLocation;
  bool _isLoadingLocation = true;
  String? _currentLocation;
  Position? _selectedPosition;
  String? _selectedLocationAddress;
  Position? _currentPosition;

  // 지도 관련
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};

  // 미디어 관련
  List<XFile> _selectedFiles = [];
  int _currentPreviewIndex = 0;
  VideoPlayerController? _videoPlayerController;
  bool _isVideoInitialized = false;
  bool _isMuted = true;

  @override
  void initState() {
    super.initState();
    _filenameController.text =
        'Memory_${DateTime.now().toString().replaceAll(' ', '_').replaceAll(':', '-').split('.')[0]}';
    _locationService = Provider.of<LocationService>(context, listen: false);
    _settingsService = Provider.of<SettingsService>(context, listen: false);
    // _locationService.addListener(_updateLocationInfo);
    _updateLocationInfo();
  }

  void _updateLocationInfo() {
    if (!mounted) return;

    Position? position;
    String? address;
    if (_settingsService.useCurrentLocationByDefault) {
      position = _locationService.currentPosition;
      address = _locationService.currentAddress;
    } else {
      position = Position(
        latitude: 37.5665,
        // 서울 중심부(시청) 위도
        longitude: 126.9780,
        // 서울 중심부(시청) 경도
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        // 추가된 필수 매개변수
        headingAccuracy: 0, // 추가된 필수 매개변수
      );
    }

    setState(() {
      _currentPosition = position;
      _currentLocation = address ?? "주소 정보 없음";
      _isLoadingLocation = _locationService.isLoading;

      if (_selectedPosition == null) {
        _selectedPosition = position;
        _selectedLocationAddress = _currentLocation;

        if (_markers.isEmpty && position != null) {
          _addMarker(position, isUserSelection: false);
        }
      }
    });
  }

  Future<void> _initializeVideoPlayer(String videoPath) async {
    if (_isVideoInitialized && _videoPlayerController != null) {
      await _videoPlayerController!.dispose();
    }

    _videoPlayerController = VideoPlayerController.file(File(videoPath));

    try {
      await _videoPlayerController!.initialize();
      _videoPlayerController!.setLooping(true);
      _videoPlayerController!.setVolume(0.0);
      _videoPlayerController!.play();

      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });
      }
    } catch (e) {
      print('비디오 초기화 오류: $e');
      if (mounted) {
        setState(() {
          _isVideoInitialized = false;
        });
      }
    }
  }

  void _previewFile(int index) {
    setState(() {
      _currentPreviewIndex = index;
      _isVideoInitialized = false;
    });

    final currentFile = _selectedFiles[index];
    if (isVideoFile(currentFile.path)) {
      _initializeVideoPlayer(currentFile.path);
    }
  }

  // 현재 선택된 파일 가져오기
  XFile? get _currentFile {
    if (_selectedFiles.isEmpty) return null;
    if (_currentPreviewIndex >= _selectedFiles.length) {
      _currentPreviewIndex = 0;
    }
    return _selectedFiles[_currentPreviewIndex];
  }

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
                ListTile(
                  leading: Icon(Icons.video_library),
                  title: Text('갤러리에서 미디어 선택'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickMultipleFilesFromGallery();
                  },
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _pickMultipleFilesFromGallery() async {
    final picker = ImagePicker();
    final List<XFile> pickedFiles = await picker.pickMultipleMedia();

    if (pickedFiles.isNotEmpty) {
      // 중복된 파일 경로 제거
      Set<String> existingPaths =
          _selectedFiles.map((file) => file.path).toSet();
      List<XFile> newFiles =
          pickedFiles
              .where((file) => !existingPaths.contains(file.path))
              .toList();

      List<XFile> allFiles = _selectedFiles + newFiles;

      setState(() {
        _selectedFiles = allFiles;
        _currentPreviewIndex = 0;
        _isVideoInitialized = false;
      });

      if (allFiles.isNotEmpty && isVideoFile(allFiles[0].path)) {
        _initializeVideoPlayer(allFiles[0].path);
      }
    }
  }

  Future<void> _navigateToCamera() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CameraScreen()),
    );

    Set<String> existingPaths = _selectedFiles.map((file) => file.path).toSet();
    List<XFile> newFiles =
        existingPaths.contains(result.path)
            ? _selectedFiles
            : _selectedFiles + [result];

    if (result != null && result is XFile) {
      setState(() {
        _selectedFiles = newFiles;
        _currentPreviewIndex = 0;
        _isVideoInitialized = false;
      });

      if (isVideoFile(_selectedFiles[0].path)) {
        _initializeVideoPlayer(_selectedFiles[0].path);
      }
    }
  }

  void _removeFile(int index) {
    setState(() {
      if (_selectedFiles.isNotEmpty) {
        // 현재 보고 있는 미디어를 삭제하는 경우
        bool wasCurrentFile = index == _currentPreviewIndex;

        _selectedFiles.removeAt(index);

        // 현재 인덱스 조정
        if (_selectedFiles.isEmpty) {
          _currentPreviewIndex = 0;
          _isVideoInitialized = false;
          if (_videoPlayerController != null) {
            _videoPlayerController!.dispose();
            _videoPlayerController = null;
          }
        } else if (wasCurrentFile ||
            _currentPreviewIndex >= _selectedFiles.length) {
          _currentPreviewIndex = 0;
          _isVideoInitialized = false;

          // 삭제 후 첫 번째 파일이 비디오인 경우 초기화
          if (_selectedFiles.isNotEmpty &&
              isVideoFile(_selectedFiles[0].path)) {
            _initializeVideoPlayer(_selectedFiles[0].path);
          } else if (_videoPlayerController != null) {
            _videoPlayerController!.dispose();
            _videoPlayerController = null;
          }
        }
      }
    });
  }

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

      if (isUserSelection) {
        _selectedPosition = position;
        _updateSelectedLocationAddress(position);
      }
    });

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

  Future<void> _updateSelectedLocationAddress(Position position) async {
    try {
      setState(() {
        _selectedLocationAddress = "주소 정보를 가져오는 중...";
      });

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String locationAddress = [
          place.street,
          place.subLocality,
          place.locality,
          place.administrativeArea,
          place.country,
        ].where((item) => item != null && item.isNotEmpty).join(', ');

        if (mounted) {
          setState(() {
            _selectedLocationAddress = locationAddress;
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

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;

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

  void _toggleMute() {
    if (_videoPlayerController == null) return;

    setState(() {
      _isMuted = !_isMuted;
      _videoPlayerController!.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  void _showMapModal() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return LocationPickerDialog(
          initialPosition: _selectedPosition,
          currentPosition: _currentPosition,
          initialMarkers: _markers,
          initialLocationAddress: _selectedLocationAddress,
          onPositionSelected: (position, markers, address) {
            setState(() {
              _selectedPosition = position;
              _markers = markers;
              _selectedLocationAddress = address;
            });

            if (_mapController != null) {
              _mapController!.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(
                    target: LatLng(position.latitude, position.longitude),
                    zoom: 15.0,
                  ),
                ),
              );
            }
          },
        );
      },
    );
  }

  Future<void> _saveFile() async {
    if (_filenameController.text.isEmpty) {
      showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          // 1초 후에 다이얼로그를 자동으로 닫습니다
          Future.delayed(Duration(seconds: 1), () {
            if (mounted) Navigator.of(dialogContext).pop();
          });
          return alertDialog(
            "이름을 입력해주세요",
            Icons.warning,
            Colors.black,
            Colors.red,
          );
        },
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final memoryService = MemoryService();
      List<String> filePaths = [];

      // 각 선택된 파일을 앱 디렉토리에 복사
      if (_selectedFiles.isNotEmpty) {
        for (int i = 0; i < _selectedFiles.length; i++) {
          XFile file = _selectedFiles[i];
          String fileExt = path.extension(file.path).toLowerCase();
          if (fileExt.isEmpty) {
            fileExt = isVideoFile(file.path) ? '.mp4' : '.jpg';
          }

          // final File sourceFile = File(file.path);
          filePaths.add(file.path);
        }
      }

      final latitude =
          _selectedPosition?.latitude ??
          _locationService.currentPosition?.latitude;
      final longitude =
          _selectedPosition?.longitude ??
          _locationService.currentPosition?.longitude;

      final settingsService = Provider.of<SettingsService>(
        context,
        listen: false,
      );

      // 여러 파일 저장
      await memoryService.saveMemory(
        settingsService.imageQuality,
        filePaths,
        _filenameController.text,
        _memoController.text,
        latitude,
        longitude,
      );

      setState(() => _savedPaths = filePaths);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          // 1초 후에 다이얼로그를 자동으로 닫습니다
          Future.delayed(Duration(seconds: 1), () {
            if (mounted) Navigator.of(dialogContext).pop();

            // 저장 성공 후 이전 화면으로 돌아갑니다
            Future.delayed(Duration(milliseconds: 300), () {
              if (mounted) Navigator.of(context).pop();
            });
          });
          return alertDialog(
            "메모리가 저장되었습니다",
            Icons.check_circle,
            Colors.black,
            Colors.green,
          );
        },
      );
    } catch (e) {
      print("저장 중 오류 발생: $e");
      showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          // 1초 후에 다이얼로그를 자동으로 닫습니다
          Future.delayed(Duration(seconds: 1), () {
            if (mounted) Navigator.of(dialogContext).pop();
          });
          return alertDialog(
            "저장 중 오류가 발생했습니다",
            Icons.warning,
            Colors.black,
            Colors.red,
          );
        },
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _filenameController.dispose();
    _memoController.dispose();
    _mapController?.dispose();
    if (_videoPlayerController != null) {
      _videoPlayerController!.dispose();
    }
    // _locationService.removeListener(_updateLocationInfo);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('새 곳 만들기'), centerTitle: true),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 미디어 프리뷰
                    MediaPreviewWidget(
                      key: ValueKey(_currentFile?.path),
                      file: _currentFile,
                      isVideoInitialized: _isVideoInitialized,
                      videoPlayerController:
                          _isVideoInitialized ? _videoPlayerController : null,
                      isMuted: _isMuted,
                      onTap: _showMediaOptions,
                      onMuteToggle: _toggleMute,
                    ),
                    SizedBox(height: 10),

                    // 선택된 미디어 파일 목록
                    if (_selectedFiles.isNotEmpty)
                      Container(
                        height: 80,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _selectedFiles.length,
                          itemBuilder: (context, index) {
                            final file = _selectedFiles[index];
                            final isSelected = index == _currentPreviewIndex;

                            return GestureDetector(
                              onTap: () => _previewFile(index),
                              child: Stack(
                                children: [
                                  Container(
                                    width: 80,
                                    height: 80,
                                    margin: EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color:
                                            isSelected
                                                ? Colors.blue
                                                : Colors.grey,
                                        width: isSelected ? 3 : 1,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child:
                                          isVideoFile(file.path)
                                              ? Stack(
                                                fit: StackFit.expand,
                                                children: [
                                                  Image.file(
                                                    File(file.path),
                                                    fit: BoxFit.cover,
                                                    errorBuilder:
                                                        (
                                                          context,
                                                          error,
                                                          stackTrace,
                                                        ) => Container(
                                                          color:
                                                              Colors.grey[900],
                                                          child: Icon(
                                                            Icons.video_file,
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                  ),
                                                  Center(
                                                    child: Icon(
                                                      Icons.play_circle_fill,
                                                      color: Colors.white
                                                          .withOpacity(0.7),
                                                      size: 30,
                                                    ),
                                                  ),
                                                ],
                                              )
                                              : Image.file(
                                                File(file.path),
                                                fit: BoxFit.cover,
                                              ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 2,
                                    right: 10,
                                    child: GestureDetector(
                                      onTap: () => _removeFile(index),
                                      child: Container(
                                        padding: EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.5),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    SizedBox(height: 10),

                    // 지도 프리뷰
                    MapPreviewWidget(
                      currentPosition: _currentPosition,
                      selectedPosition: _selectedPosition,
                      markers: _markers,
                      onMapCreated: _onMapCreated,
                      onTap: _showMapModal,
                      isLoadingLocation: _isLoadingLocation,
                    ),
                    SizedBox(height: 10),

                    // 위치 정보
                    LocationInfoWidget(
                      selectedPosition: _selectedPosition,
                      selectedLocationAddress: _selectedLocationAddress,
                      currentLocation: _currentLocation,
                      isLoadingLocation: _isLoadingLocation,
                    ),
                    SizedBox(height: 15),

                    // 파일명 입력 필드
                    TextField(
                      controller: _filenameController,
                      decoration: InputDecoration(
                        labelText: '이 곳은 이름이 뭔가요?',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 15),

                    // 메모 입력 필드
                    TextField(
                      controller: _memoController,
                      decoration: InputDecoration(
                        labelText: '기억에 남기고 싶은 내용을 작성해보세요.',
                        border: OutlineInputBorder(),
                        hintText: '기억에 남기고 싶은 내용을 작성해보세요.',
                      ),
                      maxLines: 3,
                    ),
                    SizedBox(height: 15),
                  ],
                ),
              ),
            ),
          ),

          // 하단 버튼 영역
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
                ElevatedButton(
                  onPressed:
                      _savedPaths.isNotEmpty
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
                            _savedPaths.isNotEmpty ? '저장됨' : '저장하기',
                            style: TextStyle(fontSize: 16),
                          ),
                ),
                SizedBox(height: 10),
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
