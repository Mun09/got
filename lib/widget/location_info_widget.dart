import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class LocationInfoWidget extends StatelessWidget {
  final Position? selectedPosition;
  final String? selectedLocationAddress;
  final String? currentLocation;
  final bool isLoadingLocation;

  const LocationInfoWidget({
    Key? key,
    required this.selectedPosition,
    required this.selectedLocationAddress,
    required this.currentLocation,
    required this.isLoadingLocation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.location_on, size: 16, color: Colors.blue),
        SizedBox(width: 8),
        selectedPosition != null
            ? Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedLocationAddress ?? "선택한 위치 정보 로딩 중...",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (currentLocation != null && currentLocation!.isNotEmpty)
                    Text(
                      "현재 위치: $currentLocation",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
            )
            : isLoadingLocation
            ? Text(
              "위치 정보 로딩 중...",
              style: TextStyle(fontStyle: FontStyle.italic),
            )
            : Expanded(child: Text(currentLocation ?? "위치 정보 없음")),
      ],
    );
  }
}
