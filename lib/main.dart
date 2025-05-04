import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

import 'camera_screen.dart';

List<CameraDescription> cameras = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Memory Map',
      theme: ThemeData.dark(),
      home: CameraScreen(),
    );
  }
}
