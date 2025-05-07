// lib/services/permission_service.dart
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();

  factory PermissionService() => _instance;

  PermissionService._internal();

  /// 안드로이드 13 이상 여부 확인
  Future<bool> _isAndroid13OrHigher() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      return androidInfo.version.sdkInt >= 33; // Android 13은 API 33
    }
    return false;
  }

  /// 앱에 필요한 모든 권한을 요청합니다.
  Future<Map<Permission, PermissionStatus>> requestAllPermissions(
    BuildContext context,
  ) async {
    final isAndroid13Plus = await _isAndroid13OrHigher();

    // 요청할 모든 권한 목록 (버전별 분기)
    final permissions = [
      Permission.camera,
      Permission.microphone,
      Permission.location,
      Permission.locationAlways,
    ];

    // Android 13 이상은 READ_MEDIA_IMAGES, READ_MEDIA_VIDEO 권한 사용
    if (isAndroid13Plus && Platform.isAndroid) {
      permissions.add(Permission.photos);
      permissions.add(Permission.videos);
    }
    // Android 12 이하는 storage 권한 사용
    else if (Platform.isAndroid) {
      permissions.add(Permission.storage);
    }
    // iOS는 photos 권한 사용
    else if (Platform.isIOS) {
      permissions.add(Permission.photos);
    }

    // 권한 상태 확인
    Map<Permission, PermissionStatus> statuses = {};
    for (var permission in permissions) {
      statuses[permission] = await permission.status;
    }

    // 권한이 부여되지 않은 항목만 필터링
    List<Permission> permissionsToRequest =
        permissions
            .where(
              (permission) => statuses[permission] != PermissionStatus.granted,
            )
            .toList();

    // 모든 권한이 이미 부여된 경우 즉시 반환
    if (permissionsToRequest.isEmpty) {
      print('모든 권한이 이미 부여되었습니다.');
      return statuses;
    } else {
      print('부여되지 않은 권한: $permissionsToRequest');
    }

    // 권한 요청 대화 상자 표시
    if (context.mounted) {
      bool shouldRequestPermissions =
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder:
                (context) => AlertDialog(
                  title: const Text('권한 요청'),
                  content: Text(
                    '이 앱은 최적의 기능을 위해 다음 권한이 필요합니다:\n'
                    '${permissionsToRequest.contains(Permission.camera) ? '• 카메라: 사진 및 동영상 촬영\n' : ''}'
                    '${permissionsToRequest.contains(Permission.microphone) ? '• 마이크: 오디오 녹음\n' : ''}'
                    '${permissionsToRequest.contains(Permission.location) || permissionsToRequest.contains(Permission.locationAlways) ? '• 위치: 백그라운드 포함 위치 정보\n' : ''}'
                    '${permissionsToRequest.contains(Permission.photos) ? '• 사진: 미디어 액세스\n' : ''}'
                    '${permissionsToRequest.contains(Permission.videos) ? '• 동영상: 미디어 액세스\n' : ''}'
                    '${permissionsToRequest.contains(Permission.storage) ? '• 저장소: 파일 접근\n' : ''}'
                    '계속하시겠습니까?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('취소'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('확인'),
                    ),
                  ],
                ),
          ) ??
          false;

      if (!shouldRequestPermissions) {
        return statuses; // 사용자가 취소함
      }
    }

    // 모든 권한 요청
    Map<Permission, PermissionStatus> results = {};

    // 일반 권한 먼저 요청
    for (var permission in permissionsToRequest) {
      if (permission != Permission.locationAlways) {
        results[permission] = await permission.request();
        print('${permission.toString()} 권한 요청 결과: ${results[permission]}');
      }
    }

    // 백그라운드 위치 권한은 특별 처리 필요
    if (permissionsToRequest.contains(Permission.locationAlways)) {
      // 일반 위치 권한이 부여된 경우에만 백그라운드 위치 권한 요청
      if (results[Permission.location] == PermissionStatus.granted ||
          statuses[Permission.location] == PermissionStatus.granted) {
        results[Permission.locationAlways] =
            await Permission.locationAlways.request();
      }
    }

    // 최종 상태 업데이트
    return {...statuses, ...results};
  }

  // 권한 상태 확인
  Future<bool> checkPermission(Permission permission) async {
    final status = await permission.status;
    return status == PermissionStatus.granted;
  }
}
