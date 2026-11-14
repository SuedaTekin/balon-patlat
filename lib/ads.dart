import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'progress.dart';

/// Ödüllü reklam birim kimliği. Şimdilik Google'ın resmi TEST kimliği;
/// AdMob hesabı açılınca kendi kimliğinle değiştir (AndroidManifest'teki
/// APPLICATION_ID ile birlikte).
const rewardedUnitId = 'ca-app-pub-3940256099942544/5224354917';

/// Günde izlenebilecek ödüllü reklam sınırı (altın için).
const dailyAdCoinLimit = 5;
const adCoinReward = 50;

class Ads {
  static RewardedAd? _ad;
  static bool _loading = false, _started = false;

  static bool get ready => _ad != null;

  static Future<void> init() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      _consent();
      await MobileAds.instance.initialize();
      _started = true;
      _load();
    } catch (e) {
      debugPrint('Reklam başlatılamadı: $e');
    }
  }

  /// AB/İngiltere kullanıcıları için Google UMP onay formu (gerekirse).
  static void _consent() {
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => ConsentForm.loadAndShowConsentFormIfRequired((_) {}),
      (_) {},
    );
  }

  static void _load() {
    if (!_started || _loading || _ad != null) return;
    _loading = true;
    RewardedAd.load(
      adUnitId: rewardedUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _loading = false;
        },
        onAdFailedToLoad: (e) {
          _loading = false;
          Timer(const Duration(seconds: 30), _load);
        },
      ),
    );
  }

  /// Ödüllü reklam gösterir; sonuna kadar izlendiyse true döner.
  static Future<bool> showRewarded() async {
    final ad = _ad;
    if (ad == null) {
      _load();
      return false;
    }
    _ad = null;
    final done = Completer<bool>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        if (!done.isCompleted) done.complete(earned);
        _load();
      },
      onAdFailedToShowFullScreenContent: (a, e) {
        a.dispose();
        if (!done.isCompleted) done.complete(false);
        _load();
      },
    );
    await ad.show(onUserEarnedReward: (_, _) => earned = true);
    return done.future;
  }

  static int get adCoinsLeft =>
      dailyAdCoinLimit - Progress.stat('ad_coins').clamp(0, dailyAdCoinLimit);
}
