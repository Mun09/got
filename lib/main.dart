import 'package:flutter/material.dart';
import 'package:got/main_page.dart';
import 'package:got/sevices/location_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 위치 서비스 초기화
  final locationService = LocationService();
  await locationService.initialize();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GOT 앱',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MainPage(), // 바텀 네비게이션이 포함된 메인 페이지로 시작
    );
  }
}
