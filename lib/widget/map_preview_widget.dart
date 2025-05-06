import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapPreviewWidget extends StatelessWidget {
  final Position? currentPosition;
  final Position? selectedPosition;
  final Set<Marker> markers;
  final Function(GoogleMapController) onMapCreated;
  final VoidCallback onTap;
  final bool isLoadingLocation;

  const MapPreviewWidget({
    Key? key,
    required this.currentPosition,
    required this.selectedPosition,
    required this.markers,
    required this.onMapCreated,
    required this.onTap,
    required this.isLoadingLocation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child:
          currentPosition == null
              ? Center(
                child:
                    isLoadingLocation
                        ? CircularProgressIndicator()
                        : Text('위치 정보를 가져올 수 없습니다'),
              )
              : GestureDetector(
                onTap: onTap,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: LatLng(
                            selectedPosition?.latitude ??
                                currentPosition!.latitude,
                            selectedPosition?.longitude ??
                                currentPosition!.longitude,
                          ),
                          zoom: 15,
                        ),
                        markers: markers,
                        mapType: MapType.normal,
                        onMapCreated: onMapCreated,
                        myLocationEnabled: true,
                        myLocationButtonEnabled: true,
                        zoomControlsEnabled: false,
                        zoomGesturesEnabled: true,
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
                            color: Colors.white.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(10),
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
                    Positioned.fill(
                      child: Container(color: Colors.transparent),
                    ),
                  ],
                ),
              ),
    );
  }
}
