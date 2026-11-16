import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'progress.dart';

/// Ödüllü reklam birim kimliği. Şimdilik Google'ın resmi TEST kimliği;
/// AdMob hesabı açılınca kendi kimliğinle değiştir (AndroidManifest'teki
/// APPLICATION_ID ile birlikte).
const rewardedUnitId = 'ca-app-pub-3940256099942544/5224354917';

/// Geçiş reklamı birim kimliği (şimdilik Google TEST kimliği).
const interstitialUnitId = 'ca-app-pub-3940256099942544/1033173712';

/// Geçiş reklamı kuralları: oyuncuyu bıktırmamak için ölçülü.
const interstitialFromLevel = 10;
const interstitialEveryWins = 3;
const interstitialMinGap = Duration(seconds: 150);

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
      _loadInter();
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

  // ---------------- geçiş reklamı ----------------
  static InterstitialAd? _inter;
  static bool _interLoading = false;
  static DateTime _lastInter = DateTime.fromMillisecondsSinceEpoch(0);

  static void _loadInter() {
    if (!_started || _interLoading || _inter != null || Progress.noAds) return;
    _interLoading = true;
    InterstitialAd.load(
      adUnitId: interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _inter = ad;
          _interLoading = false;
        },
        onAdFailedToLoad: (e) {
          _interLoading = false;
          Timer(const Duration(seconds: 60), _loadInter);
        },
      ),
    );
  }

  /// Bölüm kazanıldıktan sonra sıradaki ekrana geçerken çağrılır. Kurallar
  /// uygunsa geçiş reklamı gösterir (reklam kapanınca döner).
  static Future<void> maybeInterstitial(int level) async {
    if (!shouldShowInterstitial(level, DateTime.now())) {
      _loadInter();
      return;
    }
    final ad = _inter;
    if (ad == null) {
      _loadInter();
      return;
    }
    _inter = null;
    _lastInter = DateTime.now();
    Progress.winsSinceAd = 0;
    Progress.save();
    final done = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        if (!done.isCompleted) done.complete();
        _loadInter();
      },
      onAdFailedToShowFullScreenContent: (a, e) {
        a.dispose();
        if (!done.isCompleted) done.complete();
        _loadInter();
      },
    );
    await ad.show();
    await done.future.timeout(const Duration(minutes: 2), onTimeout: () {});
  }

  /// Geçiş reklamı kuralı (test edilebilir olsun diye ayrı).
  static bool shouldShowInterstitial(int level, DateTime now) =>
      !Progress.noAds &&
      level >= interstitialFromLevel &&
      Progress.winsSinceAd >= interstitialEveryWins &&
      now.difference(_lastInter) >= interstitialMinGap;

  static int get adCoinsLeft =>
      dailyAdCoinLimit - Progress.stat('ad_coins').clamp(0, dailyAdCoinLimit);
}
