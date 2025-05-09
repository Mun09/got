import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:got/services/googlemap_service.dart';
import 'package:got/services/location_service.dart';
import 'package:got/services/memory_service.dart';
import 'package:got/services/settings_service.dart';

import 'package:got/util/util.dart';
import 'package:provider/provider.dart';

import 'got_detail_page.dart';
import 'memory_detail_page.dart';
import 'models/got.dart';
import 'models/memory.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  final _googleMapService = GoogleMapService();
  final locationService = LocationService();
  final memoryService = MemoryService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshMap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _googleMapService.disposeMapController();
    super.dispose();
  }

  @override
  Future<void> didChangeDependencies() async {
    super.didChangeDependencies();
    final memoryService = MemoryService();
    await _googleMapService.buildMarkers(memoryService.memories, (memory) {
      // 마커 인포윈도우 탭 시 메모리 상세 정보로 이동
      navigateToGOTDetail(memory);
    });
  }

  Future<void> _updateMarkers() async {
    final markers = await _googleMapService.buildMarkers(
      memoryService.memories,
      (memory) {
        navigateToGOTDetail(memory);
      },
    );

    setState(() {}); // 화면 갱신
  }

  // 지도 초기화
  void _onMapCreated(GoogleMapController controller) {
    _googleMapService.setMapController(controller);

    // GOT 기반 마커 생성
    _updateMarkers();

    // 약간의 지연을 주어 지도가 완전히 로드된 후 카메라를 이동시킴
    Future.delayed(Duration(milliseconds: 300), _updateCameraPosition);
  }

  // 카메라 위치 업데이트
  void _updateCameraPosition() {
    if (_googleMapService.mapController == null) return;

    final position = locationService.currentPosition;
    if (position != null) {
      _googleMapService.moveCameraToPosition(
        LatLng(position.latitude, position.longitude),
      );
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // 위치 재설정 및 마커 새로고침
  Future<void> _refreshMap() async {
    final locationService = LocationService();

    try {
      await locationService.getCurrentLocation();
      _updateCameraPosition();
      setState(() {});
    } catch (e) {
      _showErrorSnackbar('위치 정보를 새로고침하는 중 오류가 발생했습니다');
    }
  }

  // _refreshMap 및 _redrawMap 메서드는 다음과 같이 수정
  Future<void> _redrawMap() async {
    if (_googleMapService.mapController != null) {
      // 먼저 위치 정보 새로고침
      await _refreshMap();

      // 메모리 서비스에서 데이터 다시 불러오기
      await memoryService.loadMemories();

      // GOT 기반 마커를 다시 생성
      await _googleMapService.buildMarkers(memoryService.memories, (got) {
        // 마커 인포윈도우 탭 시 GOT 상세 정보로 이동
        navigateToGOTDetail(got);
      });

      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // final locationService = LocationService();
    return Consumer<MemoryService>(
      builder: (context, memoryService, child) {
        // 메모리 로딩 상태 및 위치 로딩 상태 확인
        final isLoading = locationService.isLoading || memoryService.isLoading;
        final position = locationService.currentPosition;

        print('drawing map...');

        // SettingsService에서 설정값 가져오기
        final settingsService = SettingsService();

        return Scaffold(
          appBar: AppBar(
            title: Text('나의 곳 지도'),
            centerTitle: true,
            actions: [
              IconButton(icon: Icon(Icons.refresh), onPressed: _redrawMap),
            ],
          ),
          body:
              (isLoading)
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
                          zoom: settingsService.defaultMapZoom,
                        ),
                        markers: _googleMapService.markers,
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
            heroTag: 'map_fab',
            onPressed: _refreshMap,
            tooltip: '내 위치로 이동',
            backgroundColor: Theme.of(context).colorScheme.surface,
            child: Icon(
              Icons.my_location,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
        );
      },
    );
  }

  void navigateToMemoryDetail(Memory memory) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // 메모 텍스트 및 날짜
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            memory.memo,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            formatDate(memory.createdAt),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                // 상세 페이지로 이동하는 버튼
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // 모달 닫기
                      // 상세 페이지로 이동
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => MemoryDetailPage(memory: memory),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text('상세 페이지로 이동'),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  void navigateToGOTDetail(GOT got) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // 위치 정보 및 기록 수
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            got.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            got.locationString ?? '알 수 없는 위치',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4),
                          Text(
                            '${got.memories.length}개의 기록',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                // 상세 페이지로 이동하는 버튼
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // 모달 닫기
                      // GOT 상세 페이지로 이동
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => GOTDetailPage(got: got),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text('상세 페이지로 이동'),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}
