// 비디오 저장 페이지
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'memory_service.dart';

class VideoSavePage extends StatefulWidget {
  final XFile videoFile;

  const VideoSavePage({Key? key, required this.videoFile}) : super(key: key);

  @override
  State<VideoSavePage> createState() => _VideoSavePageState();
}

class _VideoSavePageState extends State<VideoSavePage> {
  final TextEditingController _filenameController = TextEditingController();
  bool _isSaving = false;
  String? _savedPath;

  @override
  void initState() {
    super.initState();
    // 기본 파일명 설정 (현재 날짜와 시간)
    _filenameController.text =
        'Video_${DateTime.now().toString().replaceAll(' ', '_').replaceAll(':', '-').split('.')[0]}';
  }

  @override
  void dispose() {
    _filenameController.dispose();
    super.dispose();
  }

  // 비디오 저장 처리
  Future<void> _saveVideo() async {
    if (_filenameController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('파일 이름을 입력해주세요')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      // 앱 내부 저장소 경로 가져오기
      final directory = await getApplicationDocumentsDirectory();
      final String outputPath =
          '${directory.path}/${_filenameController.text}.mp4';

      // 임시 파일에서 앱 내부 저장소로 복사
      final File sourceFile = File(widget.videoFile.path);
      final File savedFile = await sourceFile.copy(outputPath);

      final memoryService = MemoryService();
      await memoryService.saveMemory(outputPath, '');

      // 저장된 경로 저장
      setState(() {
        _savedPath = outputPath;
      });

      // 저장 완료 후 처리
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_filenameController.text}.mp4 파일이 저장되었습니다'),
          backgroundColor: Colors.green,
        ),
      );

      // 잠시 후 이전 화면으로 돌아가기
      Future.delayed(Duration(seconds: 2), () {
        if (mounted) Navigator.pop(context);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('저장 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('비디오 저장'), backgroundColor: Colors.black),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 비디오 미리보기 (추후 구현 가능)
            Container(
              height: 200,
              color: Colors.black54,
              child: Center(
                child: Icon(Icons.video_file, size: 64, color: Colors.white70),
              ),
            ),
            SizedBox(height: 20),

            // 파일 정보
            Text(
              '파일 정보',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 8),
            if (_savedPath != null)
              Text('저장 경로: $_savedPath')
            else
              Text('임시 저장 경로: ${widget.videoFile.path}'),
            SizedBox(height: 20),

            // 파일명 입력 필드
            TextField(
              controller: _filenameController,
              decoration: InputDecoration(
                labelText: '저장할 파일 이름',
                border: OutlineInputBorder(),
                suffixText: '.mp4',
              ),
            ),
            SizedBox(height: 20),

            // 저장 버튼
            ElevatedButton(
              onPressed:
                  _savedPath != null ? null : (_isSaving ? null : _saveVideo),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue,
              ),
              child:
                  _isSaving
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text(
                        _savedPath != null ? '저장됨' : '저장하기',
                        style: TextStyle(fontSize: 16),
                      ),
            ),

            SizedBox(height: 12),

            // 취소 버튼
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text('돌아가기'),
            ),
          ],
        ),
      ),
    );
  }
}
