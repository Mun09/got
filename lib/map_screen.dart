import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:got/memory_list_page.dart';
import 'package:got/memory_service.dart';

import 'memory.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  Set<Marker> _markers = {};
  bool _isLoading = true;
  final MemoryService _memoryService = MemoryService();
  int? _lastMemoryCount; // 이전 메모리 개수 저장

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initMap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkForMemoryChanges();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkForMemoryChanges();
  }

  // 메모리 변화 확인
  Future<void> _checkForMemoryChanges() async {
    try {
      final memories = await _memoryService.getMemories();

      // 메모리 개수가 변했거나 처음 로딩하는 경우에만 새로고침
      if (_lastMemoryCount == null || _lastMemoryCount != memories.length) {
        _lastMemoryCount = memories.length;
        await _loadMemoryMarkers();
      }
    } catch (e) {
      print('메모리 변화 확인 오류: $e');
    }
  }

  // 지도 초기화 및 위치 확인
  Future<void> _initMap() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 위치 권한 확인
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLoading = false;
          });
          _showErrorSnackbar('위치 권한이 거부되었습니다');
          await _loadMemoryMarkers();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackbar('위치 권한이 영구적으로 거부되었습니다');
        await _loadMemoryMarkers();
        return;
      }

      // 현재 위치 가져오기
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _isLoading = false;
      });

      // 맵 컨트롤러가 이미 초기화되어 있다면 현재 위치로 이동
      if (_mapController != null && _currentPosition != null) {
        _mapController!.animateCamera(
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

      // 메모리 마커 로드
      await _loadMemoryMarkers();
    } catch (e) {
      _showErrorSnackbar('위치 정보를 가져오는 중 오류가 발생했습니다');
      print('위치 오류: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMemoryMarkers() async {
    try {
      final memories = await _memoryService.getMemories();
      Set<Marker> markers = {};

      // 현재 위치 마커 추가
      if (_currentPosition != null) {
        markers.add(
          Marker(
            markerId: MarkerId('current_location'),
            position: LatLng(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueBlue,
            ),
            infoWindow: InfoWindow(title: '현재 위치'),
          ),
        );
      }

      // 메모리 마커 추가 작업을 병렬로 처리
      final List<Future<Marker?>> markerFutures = [];

      for (var memory in memories) {
        if (memory.latitude != null && memory.longitude != null) {
          markerFutures.add(_createMemoryMarker(memory));
        }
      }

      // 모든 마커 생성 작업이 완료될 때까지 대기
      final results = await Future.wait(markerFutures);

      // null이 아닌 마커만 추가
      markers.addAll(results.whereType<Marker>());

      if (mounted) {
        setState(() {
          _markers = markers;
          _isLoading = false;
          _lastMemoryCount = memories.length;
        });
      }
    } catch (e) {
      print('메모리 로드 오류: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 메모리별 마커 생성 함수 (비동기 처리)
  Future<Marker?> _createMemoryMarker(Memory memory) async {
    try {
      final locationString = await memory.getLocationString() ?? '위치 정보 없음';

      return Marker(
        markerId: MarkerId('memory_${memory.id}'),
        position: LatLng(memory.latitude!, memory.longitude!),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: [
            memory.videoPath != '' ? '비디오 있음' : '',
            memory.memo != '' ? '메모 있음' : '',
            (memory.longitude != null && memory.latitude != null)
                ? '위치 정보 있음'
                : '',
          ].where((item) => item.isNotEmpty).join(', '),
          snippet: locationString,
          onTap: () {
            // 마커 클릭 처리 - 추후 메모리 상세 보기 구현 가능
          },
        ),
      );
    } catch (e) {
      print('마커 생성 오류: $e');
      return null;
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;

    // 현재 위치로 카메라 이동
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

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // 메모리 리스트 이동 코드 수정
  void _navigateToMemoryList() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MemoryListPage()),
    );

    // 화면에서 돌아왔을 때 무조건 마커 다시 로드
    await _loadMemoryMarkers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('메모리 지도'),
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _initMap),
          IconButton(icon: Icon(Icons.list), onPressed: _navigateToMemoryList),
        ],
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : GoogleMap(
                onMapCreated: _onMapCreated,
                initialCameraPosition: CameraPosition(
                  target:
                      _currentPosition != null
                          ? LatLng(
                            _currentPosition!.latitude,
                            _currentPosition!.longitude,
                          )
                          : LatLng(37.566535, 126.9779692), // 서울시청 기본값
                  zoom: 15,
                ),
                markers: _markers,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                zoomControlsEnabled: true,
                mapType: MapType.normal,
              ),
    );
  }
}
