import 'package:flutter/foundation.dart';
import '../models/got.dart';
import '../models/memory.dart';
import '../services/got_service.dart';
import 'dart:async';

// AutoDisposeMixin 정의 (없는 경우)
mixin AutoDisposeMixin on ChangeNotifier {
  final List<StreamSubscription> _subscriptions = [];

  void listenToStream(Stream stream, {Function(dynamic)? onData}) {
    final subscription = stream.listen((data) {
      onData?.call(data) ?? handleStreamEvent(data);
    });
    _subscriptions.add(subscription);
  }

  void handleStreamEvent(dynamic event);

  @override
  void dispose() {
    // 모든 구독 취소
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    super.dispose();
  }
}

class GOTProvider extends ChangeNotifier with AutoDisposeMixin {
  final GOTService _gotService = GOTService();
  GOT _got; // final 제거

  GOTProvider(this._got) {
    _init();
  }

  void _init() {
    // GOT의 ID를 기반으로 메모리 변경 이벤트 구독
    listenToStream(_gotService.getGOTUpdatesStream(_got.id));
  }

  // 스트림 이벤트 발생 시 자동 갱신
  @override // 추가
  void handleStreamEvent(dynamic event) {
    if (event is GOT) {
      _got = event;
      notifyListeners();
    }
  }

  GOT get got => _got;

  // GOT 객체 갱신
  Future<void> refreshGOT() async {
    final updatedGOT = await _gotService.getGOT(_got.id, loadMemories: true);
    if (updatedGOT != null) {
      _got = updatedGOT;
      notifyListeners();
    } else {
      await _got.refreshMemories();
      notifyListeners();
    }
  }

  // 정렬된 메모리 목록 가져오기
  Future<List<Memory>> getSortedMemories({bool descending = true}) async {
    return _got.getSortedMemoriesByTime(descending: descending);
  }
}
