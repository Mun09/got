import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:got/services/location_service.dart';
import 'package:got/services/memory_service.dart';
import 'package:got/widget/location_picker_dialog_widget.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import 'camera_screen.dart';
import 'util/util.dart';
import 'widget/location_info_widget.dart';
import 'widget/map_preview_widget.dart';
import 'widget/media_widget.dart';
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
  String? _savedPath;

  // 위치 정보
  late LocationService _locationService;
  bool _isLoadingLocation = true;
  String? _currentLocation;
  Position? _selectedPosition;
  String? _selectedLocationAddress;
  Position? _currentPosition;

  // 지도 관련
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};

  // 미디어 관련
  XFile? _currentFile;
  late VideoPlayerController _videoPlayerController;
  bool _isVideoInitialized = false;
  bool _isMuted = true;

  @override
  void initState() {
    super.initState();
    _filenameController.text =
        'Video_${DateTime.now().toString().replaceAll(' ', '_').replaceAll(':', '-').split('.')[0]}';
    _locationService = Provider.of<LocationService>(context, listen: false);
    _locationService.addListener(_updateLocationInfo);
    _updateLocationInfo();
  }

  void _updateLocationInfo() {
    if (!mounted) return;
    final position = _locationService.currentPosition;
    final address = _locationService.currentAddress;

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

  Future<void> _initializeVideoPlayer() async {
    if (_currentFile == null) return;

    if (_isVideoInitialized) {
      await _videoPlayerController.dispose();
    }

    _videoPlayerController = VideoPlayerController.file(
      File(_currentFile!.path),
    );

    try {
      await _videoPlayerController.initialize();
      _videoPlayerController.setLooping(true);
      _videoPlayerController.setVolume(0.0);
      _videoPlayerController.play();

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
                  leading: Icon(Icons.photo_library),
                  title: Text('갤러리에서 이미지 선택'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromGallery();
                  },
                ),
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
    setState(() {
      _isMuted = !_isMuted;
      _videoPlayerController.setVolume(_isMuted ? 0.0 : 1.0);
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

  AlertDialog _alertDialog(
    String text,
    IconData showIcon,
    Color? textColor,
    Color? iconColor,
  ) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(showIcon, color: iconColor ?? Colors.green, size: 60),
          SizedBox(height: 16),
          Text(
            text,
            style: TextStyle(
              fontFamily: 'dosSamemul',
              fontWeight: FontWeight.w800,
              color: textColor ?? Colors.black,
            ),
          ),
        ],
      ),
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
          return _alertDialog(
            "파일 이름을 입력해주세요",
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
      String? outputPath;

      if (_currentFile != null) {
        final directory = await getApplicationDocumentsDirectory();
        String extension =
            path.extension(_currentFile!.path).toLowerCase().isNotEmpty
                ? path.extension(_currentFile!.path).toLowerCase()
                : (isVideoFile(_currentFile!.path) ? '.mp4' : '.jpg');
        // String extension = isVideoFile(_currentFile!.path) ? '.mp4' : '.jpg';

        outputPath = '${directory.path}/${_filenameController.text}$extension';

        final File sourceFile = File(_currentFile!.path);
        await sourceFile.copy(outputPath);
      }

      final latitude =
          _selectedPosition?.latitude ??
          _locationService.currentPosition?.latitude;
      final longitude =
          _selectedPosition?.longitude ??
          _locationService.currentPosition?.longitude;

      await memoryService.saveMemory(
        _currentFile?.path,
        _filenameController.text,
        _memoController.text,
        latitude,
        longitude,
      );

      setState(() => _savedPath = outputPath);

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
          return _alertDialog(
            "메모리가 저장되었습니다",
            Icons.check_circle,
            Colors.black,
            Colors.green,
          );
        },
      );
    } catch (e) {
      showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          // 1초 후에 다이얼로그를 자동으로 닫습니다
          Future.delayed(Duration(seconds: 1), () {
            if (mounted) Navigator.of(dialogContext).pop();
          });
          return _alertDialog(
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
    if (_isVideoInitialized) {
      _videoPlayerController.dispose();
    }
    _locationService.removeListener(_updateLocationInfo);
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
                        labelText: '저장할 파일 이름',
                        border: OutlineInputBorder(),
                        // suffixText: '',
                      ),
                    ),
                    SizedBox(height: 15),

                    // 메모 입력 필드
                    TextField(
                      controller: _memoController,
                      decoration: InputDecoration(
                        labelText: '메모',
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
