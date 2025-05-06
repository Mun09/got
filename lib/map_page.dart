import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:got/sevices/memory_service.dart';
import 'package:got/sevices/location_service.dart';
import 'package:got/util/util.dart';
import 'package:provider/provider.dart';

import 'memory.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  bool _isMapReady = false;
  bool _isFirstLoad = true;

  // AutomaticKeepAliveClientMixin 구현
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mapController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 앱이 재개될 때 지도 컨트롤러가 유효한지 확인
    if (state == AppLifecycleState.resumed) {
      if (_mapController != null && _isMapReady) {
        _updateCameraPosition();
      }
    }
  }

  // 지도 초기화
  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    setState(() {
      _isMapReady = true;
    });

    // 약간의 지연을 주어 지도가 완전히 로드된 후 카메라를 이동시킴
    Future.delayed(Duration(milliseconds: 300), _updateCameraPosition);
  }

  // 카메라 위치 업데이트
  void _updateCameraPosition() {
    if (_mapController == null) return;

    final locationService = Provider.of<LocationService>(
      context,
      listen: false,
    );
    final position = locationService.currentPosition;

    if (position != null && _isFirstLoad) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 15,
          ),
        ),
      );
      _isFirstLoad = false;
    }
  }

  // 메모리별 마커 생성 함수 (비동기 처리)
  Future<Marker?> _createMemoryMarker(Memory memory) async {
    try {
      if (memory.latitude == null || memory.longitude == null) return null;

      return Marker(
        markerId: MarkerId(memory.id),
        position: LatLng(memory.latitude!, memory.longitude!),
        infoWindow: InfoWindow(
          title:
              memory.memo.length > 20
                  ? '${memory.memo.substring(0, 20)}...'
                  : memory.memo,
          snippet: formatDate(memory.createdAt),
          onTap: () {
            // 마커 탭 시 상세 정보로 이동
            navigateToMemoryDetail(memory);
          },
        ),
        onTap: () {
          // 마커 탭 시 해당 위치로 카메라 이동
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(memory.latitude!, memory.longitude!),
              17.0,
            ),
          );
        },
      );
    } catch (e) {
      print('마커 생성 오류: $e');
      return null;
    }
  }

  void navigateToMemoryDetail(Memory memory) {
    // 메모리 상세 페이지로 이동하는 코드
    // Navigator.push(context, MaterialPageRoute(...));
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // 위치 재설정 및 마커 새로고침
  Future<void> _refreshMap() async {
    final locationService = Provider.of<LocationService>(
      context,
      listen: false,
    );

    try {
      await locationService.getCurrentLocation();
      _updateCameraPosition();
    } catch (e) {
      _showErrorSnackbar('위치 정보를 새로고침하는 중 오류가 발생했습니다');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Consumer2<LocationService, MemoryService>(
      builder: (context, locationService, memoryService, child) {
        // 메모리 로딩 상태 및 위치 로딩 상태 확인
        final isLoading = locationService.isLoading || memoryService.isLoading;
        final position = locationService.currentPosition;

        // 비동기로 마커 생성
        _buildMarkers(memoryService.memories);

        return Scaffold(
          appBar: AppBar(
            title: Text('나의 곳 지도'),
            centerTitle: true,
            actions: [
              IconButton(icon: Icon(Icons.refresh), onPressed: _refreshMap),
            ],
          ),
          body:
              (isLoading && !_isMapReady)
                  ? Center(child: CircularProgressIndicator())
                  : Stack(
                    children: [
                      GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target:
                              position != null
                                  ? LatLng(
                                    position.latitude,
                                    position.longitude,
                                  )
                                  : LatLng(37.5665, 126.9780), // 기본값: 서울
                          zoom: 15,
                        ),
                        markers: _markers,
                        myLocationEnabled: true,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false,
                        onMapCreated: _onMapCreated,
                      ),
                      if (isLoading)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: LinearProgressIndicator(),
                        ),
                    ],
                  ),
          floatingActionButton: FloatingActionButton(
            onPressed: _refreshMap,
            child: Icon(Icons.my_location),
            tooltip: '내 위치로 이동',
          ),
        );
      },
    );
  }

  // 메모리 목록에서 마커 생성
  Future<void> _buildMarkers(List<Memory> memories) async {
    // 이미 마커가 생성되었고 메모리 수가 같으면 다시 생성하지 않음
    if (_markers.length == memories.length && _markers.isNotEmpty) return;

    Set<Marker> newMarkers = {};
    List<Future<Marker?>> markerFutures = [];

    for (var memory in memories) {
      if (memory.latitude != null && memory.longitude != null) {
        markerFutures.add(_createMemoryMarker(memory));
      }
    }

    final results = await Future.wait(markerFutures);
    newMarkers.addAll(results.whereType<Marker>());

    if (mounted && newMarkers.isNotEmpty) {
      setState(() {
        _markers = newMarkers;
      });
    }
  }
}
