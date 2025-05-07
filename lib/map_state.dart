// 1. MapState 클래스 생성 (ChangeNotifier 사용)
import 'package:flutter/cupertino.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapState extends ChangeNotifier {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  bool _isMapReady = false;

  GoogleMapController? get mapController => _mapController;

  Set<Marker> get markers => _markers;

  bool get isMapReady => _isMapReady;

  void setMapController(GoogleMapController controller) {
    if (_mapController != null) return;
    _mapController = controller;
    _isMapReady = true;
    notifyListeners();
  }

  void updateMarkers(Set<Marker> markers) {
    _markers = markers;
    notifyListeners();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
