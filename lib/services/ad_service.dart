// lib/services/ad_service.dart
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class AdService extends ChangeNotifier {
  InterstitialAd? _interstitialAd;
  bool _isAdLoaded = false;
  static const String _lastAdShownDateKey = 'last_ad_shown_date';

  static bool isProduction = bool.fromEnvironment('dart.vm.product');

  // 테스트 광고 ID (실제 배포 시 실제 ID로 교체)
  static final String _interstitialAdUnitId =
      isProduction
          ? 'ca-app-pub-5829493135560636/7883048779' // 실제 광고 ID
          : 'ca-app-pub-3940256099942544/1033173712'; // 테스트 전면광고 ID

  bool get isAdLoaded => _isAdLoaded;

  // 전면 광고 로드
  void loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialAd = ad;
          _isAdLoaded = true;

          // 광고 닫힘 콜백 설정
          _interstitialAd!
              .fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _isAdLoaded = false;
              loadInterstitialAd(); // 다음을 위해 미리 로드
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _isAdLoaded = false;
              loadInterstitialAd(); // 실패 시 다시 로드
            },
          );

          notifyListeners();
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('전면광고 로드 실패: ${error.message}');
          _isAdLoaded = false;
          notifyListeners();
        },
      ),
    );
  }

  // 오늘 날짜에 광고를 이미 표시했는지 확인
  Future<bool> shouldShowAdToday() async {
    if (!isProduction) {
      return true; // 테스트 모드에서는 항상 광고를 보여줌
    }

    final prefs = await SharedPreferences.getInstance();
    final lastShownDate = prefs.getString(_lastAdShownDateKey);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // 저장된 날짜가 없거나 오늘 날짜와 다르면 광고를 보여줘야 함
    return lastShownDate == null || lastShownDate != today;
  }

  // 광고를 보여주고 날짜 업데이트
  Future<bool> showAdIfNeeded(BuildContext context) async {
    if (await shouldShowAdToday() && _isAdLoaded && _interstitialAd != null) {
      _interstitialAd!.show();

      // 오늘 날짜 저장
      final prefs = await SharedPreferences.getInstance();
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await prefs.setString(_lastAdShownDateKey, today);

      return true;
    }
    return false;
  }

  // 서비스 초기화
  Future<void> initialize() async {
    loadInterstitialAd();
  }

  @override
  void dispose() {
    _interstitialAd?.dispose();
    super.dispose();
  }
}
