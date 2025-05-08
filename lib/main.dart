import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:got/main_page.dart';
import 'package:got/services/location_service.dart';
import 'package:got/services/memory_service.dart';
import 'package:got/services/widget_service.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 위치 서비스 초기화
  final locationService = LocationService();
  await locationService.initialize();

  // 위젯 서비스 초기화
  await WidgetService.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocationService()),
        ChangeNotifierProvider(create: (_) => MemoryService()),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GOT 앱',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // 기본 색상 설정
        primaryColor: Colors.white,
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'dosSamemul',
        textTheme: TextTheme(
          bodyMedium: TextStyle(fontWeight: FontWeight.w800),
        ),
        // 폰트 설정

        // AppBar 테마
        appBarTheme: AppBarTheme(
          elevation: 0.5,
          backgroundColor: Colors.white,
          foregroundColor: Colors.grey[800],
          iconTheme: IconThemeData(color: Colors.grey[800]),
          titleTextStyle: TextStyle(
            color: Colors.grey[800],
            fontFamily: 'dosSamemul',
            fontWeight: FontWeight.w500,
            fontSize: 18,
          ),
        ),

        // 버튼 테마
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[800],
            foregroundColor: Colors.white,
          ),
        ),

        // 텍스트 버튼 테마
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: Colors.grey[800]),
        ),

        // FloatingActionButton 테마
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.grey[800],
          foregroundColor: Colors.white,
        ),

        // 다이얼로그 테마
        dialogTheme: DialogTheme(
          backgroundColor: Colors.white,
          titleTextStyle: TextStyle(
            color: Colors.grey[800],
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
          contentTextStyle: TextStyle(color: Colors.grey[700], fontSize: 16),
        ),

        snackBarTheme: SnackBarThemeData(
          backgroundColor: Colors.grey[800],
          contentTextStyle: TextStyle(color: Colors.white),
          actionTextColor: Colors.white,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      home: MainPage(), // 바텀 네비게이션이 포함된 메인 페이지로 시작
    );
  }
}
