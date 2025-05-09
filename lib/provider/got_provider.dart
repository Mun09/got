import 'package:flutter/cupertino.dart';

import '../models/got.dart';
import '../models/memory.dart';

class GOTProvider extends ChangeNotifier {
  GOT _got;

  GOTProvider(this._got);

  GOT get got => _got;

  // GOT 객체 갱신
  Future<void> refreshGOT() async {
    await _got.refreshMemories();
    notifyListeners();
  }

  // 정렬된 메모리 가져오기
  Future<List<Memory>> getSortedMemories({bool descending = true}) async {
    final memories = await _got.getSortedMemoriesByTime(descending: descending);
    return memories;
  }
}
