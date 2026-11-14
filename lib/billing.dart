import 'dart:async';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'game.dart';
import 'progress.dart';
import 'widgets.dart';

/// Gerçek para ile satılan ürünler (Play Console → Uygulama içi ürünler
/// bölümünde aynı kimliklerle "tüketilebilir" olarak tanımlanmalı).
class StoreItem {
  const StoreItem(this.id, this.title, this.fallbackPrice, this.reward);
  final String id, title, fallbackPrice;
  final Reward reward;
}

const starterReward = Reward(
  coins: 5000,
  infiniteMinutes: 120,
  boosters: {
    Booster.moves: 3,
    Booster.rainbow: 3,
    Booster.fire: 3,
    Booster.laser: 3,
  },
);

const storeItems = <String, StoreItem>{
  'starter_pack': StoreItem(
    'starter_pack',
    'Başlangıç Paketi',
    '₺49,99',
    starterReward,
  ),
  'coins_1000': StoreItem(
    'coins_1000',
    'Avuç Dolusu — 1.000 Altın',
    '₺29,99',
    Reward(coins: 1000),
  ),
  'coins_6000': StoreItem(
    'coins_6000',
    'Hazine Sandığı — 6.000 Altın',
    '₺149,99',
    Reward(coins: 6000),
  ),
  'coins_15000': StoreItem(
    'coins_15000',
    'Kraliyet Kasası — 15.000 Altın',
    '₺299,99',
    Reward(coins: 15000),
  ),
  'gold_pass': StoreItem(
    'gold_pass',
    'Altın Bilet (bu sezon)',
    '₺149,99',
    Reward(),
  ),
  'infinite_6h': StoreItem(
    'infinite_6h',
    '6 Saat Sonsuz Can',
    '₺39,99',
    Reward(infiniteMinutes: 360),
  ),
};

/// Google Play Billing. Ürünler mağazadan yüklenemezse (Play Console'da
/// henüz tanımlı değilse, emülatör vb.) test moduna düşer: satın alma
/// onay penceresiyle simüle edilir.
class Billing {
  static final _iap = InAppPurchase.instance;
  static final Map<String, ProductDetails> _details = {};
  static final Map<String, Completer<bool>> _waiting = {};
  static StreamSubscription<List<PurchaseDetails>>? _sub;

  /// Gerçek mağaza bağlı mı?
  static bool get live => _details.isNotEmpty;

  static String price(String id) =>
      _details[id]?.price ?? storeItems[id]!.fallbackPrice;

  static Future<void> init() async {
    try {
      if (!await _iap.isAvailable()) return;
      _sub ??= _iap.purchaseStream.listen(_onPurchases, onError: (_) {});
      final r = await _iap.queryProductDetails(storeItems.keys.toSet());
      for (final d in r.productDetails) {
        _details[d.id] = d;
      }
    } catch (e) {
      debugPrint('Mağaza başlatılamadı: $e');
    }
  }

  static void _grant(String id) {
    final item = storeItems[id];
    if (item == null) return;
    Progress.grant(item.reward);
    if (id == 'starter_pack') Progress.starterBought = true;
    if (id == 'gold_pass') Progress.activateGoldPass();
    Progress.save();
  }

  static Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      switch (p.status) {
        case PurchaseStatus.purchased || PurchaseStatus.restored:
          _grant(p.productID);
          _waiting.remove(p.productID)?.complete(true);
        case PurchaseStatus.error || PurchaseStatus.canceled:
          _waiting.remove(p.productID)?.complete(false);
        case PurchaseStatus.pending:
          break;
      }
      if (p.pendingCompletePurchase) await _iap.completePurchase(p);
    }
  }

  /// Satın alır; ödül verildiyse true döner.
  static Future<bool> buy(BuildContext context, String id) async {
    final item = storeItems[id]!;
    final d = _details[id];
    if (d == null) {
      // test modu
      if (!await confirmPurchase(context, item.title, item.fallbackPrice)) {
        return false;
      }
      _grant(id);
      return true;
    }
    final c = Completer<bool>();
    _waiting[id] = c;
    try {
      final ok = await _iap.buyConsumable(
        purchaseParam: PurchaseParam(productDetails: d),
      );
      if (!ok) _waiting.remove(id)?.complete(false);
    } catch (_) {
      _waiting.remove(id)?.complete(false);
    }
    return c.future.timeout(const Duration(minutes: 5), onTimeout: () => false);
  }

  /// Tamamlanmamış alımları yeniden ister (ayarlar → satın alımları geri yükle).
  static Future<void> restore() async {
    if (!live) return;
    await _iap.restorePurchases();
  }
}
