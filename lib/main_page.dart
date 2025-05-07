import 'package:flutter/material.dart';
import 'package:got/map_page.dart';
import 'package:got/memory_list_page.dart';
import 'package:got/services/permission_service.dart';
import 'package:permission_handler/permission_handler.dart';

class MainPage extends StatefulWidget {
  const MainPage({Key? key}) : super(key: key);

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with TickerProviderStateMixin {
  final PermissionService _permissionService = PermissionService();
  late List<AnimationController> _animationControllers;

  @override
  void initState() {
    super.initState();
    // 권한 요청은 빌드 완료 후에 실행
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestPermissions();
    });

    // 각 네비게이션 아이템별 애니메이션 컨트롤러 초기화
    _animationControllers = List.generate(
      2,
      (index) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 300),
      ),
    );
  }

  @override
  void dispose() {
    // 컨트롤러 해제
    for (var controller in _animationControllers) {
      controller.dispose();
    }
    super.dispose();
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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens, // MapScreen과 MemoryListPage는 딱 한 번만 생성됨
      ),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          // 물결 효과에 영향을 주는 다른 속성들도 투명하게 설정
          splashFactory: NoSplash.splashFactory,
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            _animationControllers[index].reset();
            _animationControllers[index].forward();
            setState(() {
              _currentIndex = index;
            });
          },
          items: List.generate(2, (index) {
            return BottomNavigationBarItem(
              icon: AnimatedBuilder(
                animation: _animationControllers[index],
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.0 + (_animationControllers[index].value * 0.2),
                    child: Opacity(
                      opacity: 0.5 + (_animationControllers[index].value * 0.5),
                      child: index == 0 ? Icon(Icons.map) : Icon(Icons.add),
                    ),
                  );
                },
              ),
              label: index == 0 ? '곳 지도' : '새 곳',
            );
          }),
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
        ),
      ),
    );
  }
}
