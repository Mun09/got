import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:got/memory_service.dart';
import 'package:got/sevices/location_service.dart';
import 'package:got/util.dart';

import 'memory.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  Set<Marker> _markers = {};
  bool _isLoading = true;
  final MemoryService _memoryService = MemoryService();
  final LocationService _locationService = LocationService(); // 위치 서비스 인스턴스

  int? _lastMemoryCount; // 이전 메모리 개수 저장

  // AutomaticKeepAliveClientMixin 구현
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 위치 서비스에 리스너 등록
    _locationService.addListener(_updateLocationFromService);

    _initMap();
  }

  @override
  void dispose() {
    // 리스너 제거
    _locationService.removeListener(_updateLocationFromService);
    _locationService.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 위치 서비스로부터 위치 업데이트 받기
  void _updateLocationFromService() {
    final position = _locationService.currentPosition;

    if (position != null && mounted) {
      setState(() {
        _currentPosition = position;
      });

      // 지도가 준비되었을 때만 카메라 이동 (선택적)
      if (_mapController != null && _isFirstLoad) {
        _isFirstLoad = false;
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
  }

  bool _isFirstLoad = true; // 첫 로드 여부 확인 (카메라 이동용)

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkForMemoryChanges();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_lastMemoryCount != null) {
      _checkForMemoryChanges();
    }
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
      // 현재 위치가 없는 경우에만 새로 가져오기 (이미 있으면 재사용)
      final position = _locationService.currentPosition;

      if (position != null) {
        setState(() {
          _currentPosition = position;
        });
      } else {
        // 위치 서비스에 위치 요청
        await _locationService.getCurrentLocation();
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
            isMediaExist(memory) ? '미디어 있음' : '',
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

    // 약간의 지연을 주어 지도가 완전히 로드된 후 카메라를 이동시킴
    if (_currentPosition != null) {
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
      print(
        '카메라 이동: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}',
      );
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // 빌드 메서드에 위치 추적 토글 버튼 추가
  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('메모리 지도'),
        actions: [IconButton(icon: Icon(Icons.refresh), onPressed: _initMap)],
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : GoogleMap(
                onMapCreated: _onMapCreated,
                initialCameraPosition: CameraPosition(
                  // _currentPosition이 있으면 현재 위치를 초기 위치로 설정
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
