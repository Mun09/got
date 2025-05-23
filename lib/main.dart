import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:got/main_page.dart';
import 'package:got/services/ad_service.dart';
import 'package:got/services/got_service.dart';
import 'package:got/services/location_service.dart';
import 'package:got/services/memory_service.dart';
import 'package:got/services/settings_service.dart';
import 'package:got/services/widget_service.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 테스트 모드 설정 (개발 중에만 사용)
  // MobileAds.instance.updateRequestConfiguration(
  //   RequestConfiguration(testDeviceIds: ['테스트_기기_ID']), // 실제 테스트 기기 ID로 교체
  // );
  MobileAds.instance.initialize();

  // 위치 서비스 초기화
  final locationService = LocationService();
  await locationService.initialize();

  // 위젯 서비스 초기화
  await WidgetService.initialize();

  final settingsService = SettingsService();
  await settingsService.loadSettings();

  // 광고 서비스 초기화
  final adService = AdService();
  await adService.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocationService()),
        ChangeNotifierProvider(create: (_) => MemoryService()),
        ChangeNotifierProvider(create: (_) => GOTService()),
        ChangeNotifierProvider(create: (_) => SettingsService()),
        ChangeNotifierProvider(create: (_) => AdService()), // 추가
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // SettingsService를 가져와서 테마 모드 등 설정값을 적용
    final settingsService = SettingsService();

    return MaterialApp(
      title: 'GOT 앱',
      debugShowCheckedModeBanner: false,

      // 테마 모드 설정 적용
      themeMode: settingsService.themeMode,

      // 라이트 테마 설정
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: Colors.white,
        colorScheme: ColorScheme.light(
          primary: Colors.black,
          secondary: Colors.black,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'dosSamemul',
        textTheme: TextTheme(
          bodyMedium: TextStyle(fontWeight: FontWeight.w800),
        ),
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
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[800],
            foregroundColor: Colors.white,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: Colors.grey[800]),
        ),

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

      // 다크 테마 설정 추가
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.grey[850],
        colorScheme: ColorScheme.dark(
          primary: Colors.white,
          secondary: Colors.white,
          surface: Colors.grey[850]!,
        ),
        scaffoldBackgroundColor: Colors.grey[900],
        fontFamily: 'dosSamemul',
        textTheme: TextTheme(
          bodyMedium: TextStyle(
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        appBarTheme: AppBarTheme(
          elevation: 0.5,
          backgroundColor: Colors.grey[850],
          foregroundColor: Colors.white,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontFamily: 'dosSamemul',
            fontWeight: FontWeight.w500,
            fontSize: 18,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueGrey[200],
            foregroundColor: Colors.grey[900],
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: Colors.blueGrey[200]),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.blueGrey[200],
          foregroundColor: Colors.grey[900],
        ),
        dialogTheme: DialogTheme(
          backgroundColor: Colors.grey[850],
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
          contentTextStyle: TextStyle(color: Colors.grey[300], fontSize: 16),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: Colors.grey[700],
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
