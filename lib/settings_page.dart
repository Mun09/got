// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:got/util/util.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // 컨트롤러에 현재 설정값 할당
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settingsService = Provider.of<SettingsService>(
        context,
        listen: false,
      );
      _nameController.text = settingsService.userName;
      _emailController.text = settingsService.userEmail;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('설정'), centerTitle: true),
      body: Consumer<SettingsService>(
        builder: (context, settings, child) {
          return ListView(
            padding: EdgeInsets.all(16.0),
            children: [
              // 앱 정보 섹션

              // 앱 테마 설정
              _buildSectionTitle('앱 테마'),
              RadioListTile<ThemeMode>(
                title: Text('시스템 설정 사용'),
                value: ThemeMode.system,
                groupValue: settings.themeMode,
                onChanged: (value) {
                  if (value != null) settings.setThemeMode(value);
                },
              ),
              RadioListTile<ThemeMode>(
                title: Text('라이트 모드'),
                value: ThemeMode.light,
                groupValue: settings.themeMode,
                onChanged: (value) {
                  if (value != null) settings.setThemeMode(value);
                },
              ),
              RadioListTile<ThemeMode>(
                title: Text('다크 모드'),
                value: ThemeMode.dark,
                groupValue: settings.themeMode,
                onChanged: (value) {
                  if (value != null) settings.setThemeMode(value);
                },
              ),
              Divider(),

              // 지도 설정
              _buildSectionTitle('지도 설정'),
              SwitchListTile(
                title: Text('현재 위치 자동 사용'),
                subtitle: Text('새 메모리 생성 시 현재 위치 자동 사용'),
                value: settings.useCurrentLocationByDefault,
                onChanged: (value) {
                  settings.setUseCurrentLocationByDefault(value);
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '기본 지도 확대 수준: ${settings.defaultMapZoom.toStringAsFixed(1)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    SizedBox(height: 8.0),
                    Slider(
                      min: 10.0,
                      max: 20.0,
                      divisions: 20,
                      value: settings.defaultMapZoom,
                      label: settings.defaultMapZoom.toStringAsFixed(1),
                      onChanged: (value) {
                        settings.setDefaultMapZoom(value);
                      },
                    ),
                  ],
                ),
              ),
              Divider(),

              // 미디어 품질 설정
              _buildSectionTitle('미디어 품질'),
              RadioListTile<MediaQuality>(
                title: Text('낮음'),
                subtitle: Text('저용량, 빠른 저장'),
                value: MediaQuality.low,
                groupValue: settings.mediaQuality,
                onChanged: (value) {
                  if (value != null) settings.setMediaQuality(value);
                },
              ),
              RadioListTile<MediaQuality>(
                title: Text('중간'),
                subtitle: Text('균형 잡힌 품질과 크기'),
                value: MediaQuality.medium,
                groupValue: settings.mediaQuality,
                onChanged: (value) {
                  if (value != null) settings.setMediaQuality(value);
                },
              ),
              RadioListTile<MediaQuality>(
                title: Text('높음'),
                subtitle: Text('최고 품질, 큰 파일 크기'),
                value: MediaQuality.high,
                groupValue: settings.mediaQuality,
                onChanged: (value) {
                  if (value != null) settings.setMediaQuality(value);
                },
              ),
              Divider(),

              _buildSectionTitle('앱 정보'),
              ListTile(title: Text('버전'), trailing: Text(settings.appVersion)),
              Divider(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
    );
  }
}
