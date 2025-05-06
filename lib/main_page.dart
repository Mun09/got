import 'package:flutter/material.dart';
import 'package:got/map_page.dart';
import 'package:got/memory_list_page.dart';
import 'package:got/sevices/permission_service.dart';
import 'package:permission_handler/permission_handler.dart';

class MainPage extends StatefulWidget {
  const MainPage({Key? key}) : super(key: key);

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final PermissionService _permissionService = PermissionService();

  @override
  void initState() {
    super.initState();
    // 권한 요청은 빌드 완료 후에 실행
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestPermissions();
    });
  }

  Future<void> _requestPermissions() async {
    final statuses = await _permissionService.requestAllPermissions(context);

    // 권한 결과 처리
    if (statuses[Permission.locationAlways] != PermissionStatus.granted) {
      // 백그라운드 위치 권한이 없는 경우 처리
      print('백그라운드 위치 권한이 거부되었습니다.');
    }

    // 다른 권한들도 필요에 따라 처리
  }

  int _currentIndex = 0; // 현재 선택된 탭 인덱스 (0: 지도, 1: 카메라)

  // 화면 목록
  final List<Widget> _screens = [MapScreen(), MemoryListPage()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex], // 현재 선택된 화면 표시
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: '곳 지도'),
          BottomNavigationBarItem(icon: Icon(Icons.add), label: '새 곳'),
        ],
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
      ),
    );
  }
}
