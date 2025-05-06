import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationPickerDialog extends StatefulWidget {
  final Position? initialPosition;
  final Position? currentPosition;
  final Set<Marker> initialMarkers;
  final String? initialLocationAddress;
  final Function(Position position, Set<Marker> markers, String? address)
  onPositionSelected;

  const LocationPickerDialog({
    Key? key,
    this.initialPosition,
    this.currentPosition,
    required this.initialMarkers,
    this.initialLocationAddress,
    required this.onPositionSelected,
  }) : super(key: key);

  @override
  _LocationPickerDialogState createState() => _LocationPickerDialogState();
}

class _LocationPickerDialogState extends State<LocationPickerDialog> {
  late Set<Marker> markers;
  GoogleMapController? mapController;
  Position? selectedPosition;
  String? locationAddress;

  @override
  void initState() {
    super.initState();
    markers = Set<Marker>.from(widget.initialMarkers);
    selectedPosition = widget.initialPosition;
    locationAddress = widget.initialLocationAddress;
  }

  @override
  void dispose() {
    mapController?.dispose();
    super.dispose();
  }

  // 선택된 위치의 주소 가져오기
  Future<void> _updateLocationAddress(Position position) async {
    try {
      setState(() {
        locationAddress = "주소 정보를 가져오는 중...";
      });

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String address = [
          place.street,
          place.subLocality,
          place.locality,
          place.administrativeArea,
          place.country,
        ].where((item) => item != null && item.isNotEmpty).join(', ');

        if (mounted) {
          setState(() {
            locationAddress = address;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            locationAddress = "주소 정보 없음";
          });
        }
      }
    } catch (e) {
      print("주소 변환 오류: $e");
      if (mounted) {
        setState(() {
          locationAddress = "주소 정보를 가져올 수 없음";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(0),
      child: Container(
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
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('위치 선택', style: TextStyle(fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('취소'),
                      ),
                      SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          // 확인 시 선택한 위치 정보를 전달
                          if (selectedPosition != null) {
                            widget.onPositionSelected(
                              selectedPosition!,
                              Set<Marker>.from(markers),
                              locationAddress,
                            );
                          }
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
                      widget.initialPosition?.latitude ??
                          widget.currentPosition?.latitude ??
                          37.5665,
                      widget.initialPosition?.longitude ??
                          widget.currentPosition?.longitude ??
                          126.9780,
                    ),
                    zoom: 15,
                  ),
                  markers: markers,
                  mapType: MapType.normal,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: false,
                  compassEnabled: true,
                  onMapCreated: (GoogleMapController controller) {
                    mapController = controller;
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

                    setState(() {
                      markers.clear();
                      markers.add(marker);
                      selectedPosition = newPosition;
                    });

                    // 선택한 위치의 주소 업데이트
                    _updateLocationAddress(newPosition);

                    if (mapController != null) {
                      double currentZoom = await mapController!.getZoomLevel();
                      await mapController!.animateCamera(
                        CameraUpdate.newCameraPosition(
                          CameraPosition(target: position, zoom: currentZoom),
                        ),
                      );
                    }
                  },
                  gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                    Factory<OneSequenceGestureRecognizer>(
                      () => EagerGestureRecognizer(),
                    ),
                  },
                ),
              ),
            ),

            // 선택 위치 정보
            Container(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.location_on, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      locationAddress ??
                          (selectedPosition != null
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
      ),
    );
  }
}
