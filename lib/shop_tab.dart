import 'dart:math';

import 'package:flutter/material.dart';

import 'ads.dart';
import 'audio.dart';
import 'billing.dart';
import 'game.dart';
import 'progress.dart';
import 'level_intro.dart';
import 'skins.dart';
import 'theme.dart';
import 'widgets.dart';

class CoinPack {
  const CoinPack(this.id, this.name, this.coins, this.bonus, this.tag);
  final String id, name;
  final int coins;
  final String? bonus, tag;
  String get price => Billing.price(id);
}

const coinPacks = [
  CoinPack('coins_1000', 'Avuç Dolusu', 1000, null, null),
  CoinPack('coins_6000', 'Hazine Sandığı', 6000, '+%20', 'EN POPÜLER'),
  CoinPack('coins_15000', 'Kraliyet Kasası', 15000, '+%50', 'EN İYİ DEĞER'),
];

const boosterPackPrice = {
  Booster.moves: 450,
  Booster.rainbow: 550,
  Booster.fire: 500,
  Booster.laser: 400,
};

class ShopTab extends StatefulWidget {
  const ShopTab({super.key, required this.onChanged});
  final VoidCallback onChanged;

  @override
  State<ShopTab> createState() => _ShopTabState();
}

class _ShopTabState extends State<ShopTab> {
  void _done() {
    widget.onChanged();
    setState(() {});
    Sfx.haptic(2);
  }

  Future<void> _buyReal(String id) async {
    if (!await Billing.buy(context, id)) return;
    _done();
    Sfx.play('coin');
    if (mounted) {
      await showRewardDialog(context, 'SATIN ALINDI!', storeItems[id]!.reward);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      children: [
        if (!Progress.starterBought) ...[
          _starterCard(),
          const SizedBox(height: 20),
        ],
        _piggyCard(),
        const SizedBox(height: 12),
        if (!Progress.noAds) ...[_noAdsCard(), const SizedBox(height: 12)],
        _freeGift(),
        const SizedBox(height: 12),
        _adCoins(),
        const SizedBox(height: 12),
        _dailyDeal(),
        const SizedBox(height: 20),
        _title(Icons.monetization_on_rounded, 'Altın Paketleri', LP.gold),
        for (final p in coinPacks) ...[
          _coinPack(p),
          const SizedBox(height: 14),
        ],
        const SizedBox(height: 6),
        _title(Icons.favorite_rounded, 'Can Deposu', LP.ruby),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _infiniteCard()),
            const SizedBox(width: 12),
            Expanded(child: _refillCard()),
          ],
        ),
        const SizedBox(height: 20),
        _title(Icons.rocket_launch_rounded, 'Güçlendirici Pazarı', LP.cyan),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.92,
          children: [for (final b in Booster.values) _boosterCard(b)],
        ),
        const SizedBox(height: 20),
        _title(
          Icons.palette_rounded,
          'Atıcı Temaları',
          const Color(0xFFB45CFF),
        ),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.72,
          children: [for (final s in launcherSkins) _skinCard(s)],
        ),
        const SizedBox(height: 20),
        if (!Billing.live)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.science_rounded, color: LP.muted, size: 16),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Test modu: Gerçek para ile satın almalar simülasyondur.',
                  textAlign: TextAlign.center,
                  style: jakarta(12, color: LP.muted),
                ),
              ),
            ],
          ),
      ],
    );
  }

  /// Kumbara: her galibiyette altın birikir; satın alınca hepsi senin.
  Widget _piggyCard() {
    final p = Progress.piggy;
    final ready = Progress.piggyReady;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF8FB8), Color(0xFFE0457B)],
        ),
        boxShadow: const [
          BoxShadow(color: Color(0xFF8C1F48), offset: Offset(0, 5)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.25),
            ),
            child: const Icon(
              Icons.savings_rounded,
              color: Colors.white,
              size: 42,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Progress.piggyFull ? 'KUMBARA DOLU!' : 'KUMBARA',
                  style: outfit(18, w: FontWeight.w900, color: Colors.white),
                ),
                Text(
                  ready
                      ? 'Her galibiyette dolar. Kır, hepsi senin!'
                      : 'Bölüm kazandıkça altın birikir '
                          '(en az ${Progress.piggyMin})',
                  style: jakarta(11, color: Colors.white),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    height: 14,
                    color: const Color(0x55000000),
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: max(0.03, p / Progress.piggyMax),
                      child: Container(color: LP.gold),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const CoinIcon(size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${formatNum(p)} / ${formatNum(Progress.piggyMax)}',
                      style: outfit(13, color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 92,
            child: Opacity(
              opacity: ready ? 1 : 0.5,
              child: JuicyButton.gold(
                height: 44,
                padding: EdgeInsets.zero,
                onTap: () async {
                  if (!ready) {
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                      SnackBar(
                        content: Text(
                          'Kumbarada en az ${Progress.piggyMin} altın birikmeli.',
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                    return;
                  }
                  final n = Progress.piggy;
                  if (!await Billing.buy(context, 'piggy_bank')) return;
                  _done();
                  Sfx.play('coin');
                  if (mounted) {
                    await showRewardDialog(
                      context,
                      'KUMBARA KIRILDI!',
                      Reward(coins: n),
                    );
                  }
                },
                child: FittedBox(
                  child: MoneyText(
                    Billing.price('piggy_bank'),
                    style: outfit(
                      16,
                      w: FontWeight.w900,
                      color: const Color(0xFF3D2400),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Reklamları kaldır (tek seferlik) + 1.000 altın hediye.
  Widget _noAdsCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: glassCard(),
      child: Row(
        children: [
          const Icon(Icons.block_rounded, color: LP.cyan, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reklamları Kaldır',
                  style: outfit(17, w: FontWeight.w900),
                ),
                Text(
                  'Bölüm arası reklamlar bir daha çıkmaz · +1.000 altın hediye',
                  style: jakarta(11, color: LP.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 92,
            child: JuicyButton.cyan(
              height: 44,
              padding: EdgeInsets.zero,
              onTap: () => _buyReal('no_ads'),
              child: FittedBox(
                child: MoneyText(
                  Billing.price('no_ads'),
                  style: outfit(
                    16,
                    w: FontWeight.w900,
                    color: const Color(0xFF00363D),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _title(IconData icon, String text, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(text, style: outfit(22, w: FontWeight.w900)),
          ),
        ),
      ],
    ),
  );

  Widget _starterCard() {
    Widget line(Widget icon, String text) => Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: LP.bgDeep.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: outfit(16, color: LP.gold))),
        ],
      ),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 30, 16, 16),
          decoration: glassCard(border: LP.gold.withValues(alpha: 0.7)),
          child: Column(
            children: [
              line(const CoinIcon(size: 28), '5.000 Altın'),
              line(
                const HeartIcon(size: 28, infinite: true),
                '2 Saat Sonsuz Can',
              ),
              line(
                const BoosterIcon(Booster.rainbow, size: 28),
                '3x her güçlendirici',
              ),
              const SizedBox(height: 6),
              JuicyButton.gold(
                height: 64,
                onTap: () => _buyReal('starter_pack'),

                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.shopping_bag_rounded,
                        color: Color(0xFF3D2400),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'FIRSATI KAP',
                        style: outfit(
                          22,
                          w: FontWeight.w900,
                          color: const Color(0xFF3D2400),
                        ),
                      ),
                      const SizedBox(width: 12),
                      MoneyText(
                        '₺149,99',
                        style: outfit(
                          14,
                          color: const Color(0xFF6B4A00),
                        ).copyWith(decoration: TextDecoration.lineThrough),
                      ),
                      const SizedBox(width: 6),
                      MoneyText(
                        Billing.price('starter_pack'),
                        style: outfit(
                          22,
                          w: FontWeight.w900,
                          color: const Color(0xFF3D2400),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text('Tek seferlik teklif', style: jakarta(11, color: LP.muted)),
            ],
          ),
        ),
        Positioned(
          top: -14,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: LP.gold,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '★ BAŞLANGIÇ ÇILGINLIĞI ★',
                style: outfit(
                  13,
                  w: FontWeight.w900,
                  color: const Color(0xFF3D2400),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: -10,
          right: -4,
          child: Transform.rotate(
            angle: 0.25,
            child: Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: LP.ruby,
              ),
              child: Text(
                '%67\nİNDİRİM',
                textAlign: TextAlign.center,
                style: outfit(10, w: FontWeight.w900, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Günün fırsatı: her gün değişen indirimli güçlendirici paketi.
  static const _deals = [
    ('Ateş + Lazer Paketi', {Booster.fire: 3, Booster.laser: 3}, 1100, 700),
    ('Gökkuşağı Paketi', {Booster.rainbow: 4}, 900, 550),
    ('Hamle Paketi', {Booster.moves: 4}, 800, 500),
    (
      'Karışık Paket',
      {Booster.rainbow: 1, Booster.fire: 1, Booster.laser: 1, Booster.moves: 1},
      800,
      450,
    ),
  ];

  Widget _dailyDeal() {
    final day = DateTime.now().difference(DateTime(2026)).inDays;
    final (name, boosters, oldPrice, price) = _deals[day % _deals.length];
    final bought = Progress.dealDay == todayKey;
    final can = !bought && Progress.coins >= price;
    final now = DateTime.now();
    final left = DateTime(now.year, now.month, now.day + 1).difference(now);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: glassCard(border: LP.pink.withValues(alpha: 0.7)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: LP.pink,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'GÜNÜN FIRSATI',
                  style: outfit(12, color: Colors.white),
                ),
              ),
              const Spacer(),
              const Icon(Icons.timer_outlined, size: 14, color: LP.muted),
              Text(
                ' ${left.inHours}s ${left.inMinutes % 60}dk',
                style: outfit(12, color: LP.muted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(name, style: outfit(18, w: FontWeight.w900)),
          const SizedBox(height: 6),
          RewardChips(Reward(boosters: boosters)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Text(
                        formatNum(oldPrice),
                        style: outfit(
                          15,
                          color: LP.muted,
                        ).copyWith(decoration: TextDecoration.lineThrough),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: LP.surfaceHighest,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '%${((1 - price / oldPrice) * 100).round()} İNDİRİM',
                          style: outfit(11, color: LP.gold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 120,
                child: JuicyButton.gold(
                  height: 46,
                  padding: EdgeInsets.zero,
                  onTap:
                      can
                          ? () async {
                            Progress.spend(price);
                            Progress.grant(Reward(boosters: boosters));
                            Progress.dealDay = todayKey;
                            Progress.save();
                            _done();
                            await showRewardDialog(
                              context,
                              'FIRSAT SENİN!',
                              Reward(boosters: boosters),
                            );
                          }
                          : null,
                  child: FittedBox(
                    child:
                        bought
                            ? Text(
                              'ALINDI',
                              style: outfit(
                                16,
                                w: FontWeight.w900,
                                color: const Color(0xFF3D2400),
                              ),
                            )
                            : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CoinIcon(size: 20),
                                Text(
                                  ' ${formatNum(price)}',
                                  style: outfit(
                                    16,
                                    w: FontWeight.w900,
                                    color: const Color(0xFF3D2400),
                                  ),
                                ),
                              ],
                            ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _skinCard(LauncherSkin s) {
    final owned = Progress.ownedSkins.contains(s.id);
    final selected = Progress.skin == s.id;
    final can = !owned && Progress.coins >= s.price;
    return GestureDetector(
      onTap: () async {
        if (owned) {
          Progress.skin = s.id;
          Progress.save();
          _done();
          return;
        }
        if (!can) {
          toastPrice(context);
          return;
        }
        Progress.spend(s.price);
        Progress.ownedSkins.add(s.id);
        Progress.skin = s.id;
        Progress.save();
        _done();
        Sfx.play('tier');
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: glassCard(
          border: selected ? const Color(0xFFB45CFF) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SkinPreview(s, size: 62),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(s.name, style: outfit(14, w: FontWeight.w900)),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child:
                  selected
                      ? Text(
                        'SEÇİLİ',
                        style: outfit(12, color: const Color(0xFFB45CFF)),
                      )
                      : owned
                      ? Text('SEÇ', style: outfit(12, color: LP.cyan))
                      : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CoinIcon(size: 14),
                          Text(
                            ' ${formatNum(s.price)}',
                            style: outfit(12, color: can ? LP.gold : LP.muted),
                          ),
                        ],
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _adCoins() {
    final left = Ads.adCoinsLeft;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: glassCard(),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.smart_display_rounded,
                color: Color(0xFFB45CFF),
                size: 36,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reklam İzle, Altın Kazan',
                      style: outfit(17, w: FontWeight.w900),
                    ),
                    Text(
                      left > 0
                          ? 'Her reklam +$adCoinReward altın · bugün $left hakkın var'
                          : 'Bugünkü hakların bitti, yarın gel',
                      style: jakarta(12, color: LP.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (left > 0) ...[
            const SizedBox(height: 10),
            AdButton(
              label: '+$adCoinReward ALTIN',
              onEarned: () {
                Progress.coins += adCoinReward;
                Progress.addStat('ad_coins');
                Progress.save();
                _done();
                Sfx.play('coin');
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _freeGift() {
    final avail = Progress.freeGiftAvailable;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: glassCard(border: avail ? LP.cyan : null),
      child: Row(
        children: [
          const Icon(Icons.card_giftcard_rounded, color: LP.cyan, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ücretsiz Günlük Ödül',
                  style: outfit(17, w: FontWeight.w900),
                ),
                Text(
                  avail ? 'Her gün 100 altın hediye!' : 'Yarın tekrar gel',
                  style: jakarta(12, color: LP.muted),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 104,
            child: JuicyButton.cyan(
              height: 46,
              padding: EdgeInsets.zero,
              onTap:
                  avail
                      ? () async {
                        Progress.claimFreeGift();
                        _done();
                        await showRewardDialog(
                          context,
                          'GÜNLÜK HEDİYE',
                          const Reward(coins: 100),
                        );
                      }
                      : null,
              child: FittedBox(
                child: Text(
                  avail ? 'AL (+100)' : 'ALINDI',
                  style: outfit(
                    15,
                    w: FontWeight.w900,
                    color: const Color(0xFF00363D),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _coinPack(CoinPack p) {
    final highlight = p.tag == 'EN POPÜLER';
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
          decoration: glassCard(border: highlight ? LP.ruby : null),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: LP.bgDeep.withValues(alpha: 0.6),
                ),
                alignment: Alignment.center,
                child: CoinIcon(size: 30 + coinPacks.indexOf(p) * 5.0),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, style: outfit(18, w: FontWeight.w900)),
                    Wrap(
                      spacing: 0,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${formatNum(p.coins)} Altın',
                          style: outfit(15, color: LP.gold),
                        ),
                        if (p.bonus != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: LP.surfaceHighest,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${p.bonus} BONUS',
                              style: outfit(10, color: LP.gold),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 104,
                child: (highlight ? JuicyButton.ruby : JuicyButton.cyan)(
                  height: 46,
                  padding: EdgeInsets.zero,
                  onTap: () => _buyReal(p.id),

                  child: FittedBox(
                    child: MoneyText(
                      p.price,
                      style: outfit(
                        16,
                        w: FontWeight.w900,
                        color:
                            highlight ? Colors.white : const Color(0xFF00363D),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (p.tag != null)
          Positioned(
            top: -10,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: highlight ? LP.ruby : LP.gold,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                p.tag!,
                style: outfit(
                  11,
                  color: highlight ? Colors.white : const Color(0xFF3D2400),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _infiniteCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: glassCard(),
      child: Column(
        children: [
          const HeartIcon(size: 56, infinite: true),
          const SizedBox(height: 8),
          Text(
            'Sonsuz Can',
            textAlign: TextAlign.center,
            style: outfit(16, w: FontWeight.w900),
          ),
          Text(
            '6 saat boyunca can gitmez',
            textAlign: TextAlign.center,
            style: jakarta(11, color: LP.muted),
          ),
          const SizedBox(height: 10),
          JuicyButton.ruby(
            height: 44,
            padding: EdgeInsets.zero,
            onTap: () => _buyReal('infinite_6h'),
            child: FittedBox(
              child: MoneyText(
                Billing.price('infinite_6h'),
                style: outfit(16, w: FontWeight.w900, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _refillCard() {
    final full = Progress.lives >= Progress.maxLives;
    final can = !full && Progress.coins >= Progress.refillPrice;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: glassCard(),
      child: Column(
        children: [
          const HeartIcon(size: 56),
          const SizedBox(height: 8),
          Text(
            'Canları Doldur',
            textAlign: TextAlign.center,
            style: outfit(16, w: FontWeight.w900),
          ),
          Text(
            full ? 'Canların zaten dolu' : 'Anında 5 can',
            textAlign: TextAlign.center,
            style: jakarta(11, color: LP.muted),
          ),
          const SizedBox(height: 10),
          JuicyButton.gold(
            height: 44,
            padding: EdgeInsets.zero,
            onTap:
                can
                    ? () {
                      Progress.refillLives();
                      _done();
                    }
                    : null,
            child: FittedBox(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CoinIcon(size: 20),
                  Text(
                    ' ${Progress.refillPrice}',
                    style: outfit(
                      16,
                      w: FontWeight.w900,
                      color: const Color(0xFF3D2400),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _boosterCard(Booster b) {
    final price = boosterPackPrice[b]!;
    final can = Progress.coins >= price;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: glassCard(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          BoosterIcon(b, size: 52),
          Column(
            children: [
              Text(boosterName(b), style: outfit(15, w: FontWeight.w900)),
              Text(
                '3 Adet · Elinde: ${Progress.boosters[b]}',
                style: jakarta(11, color: LP.muted),
              ),
            ],
          ),
          JuicyButton.cyan(
            height: 42,
            padding: EdgeInsets.zero,
            onTap:
                can
                    ? () {
                      Progress.buyBooster(b, count: 3, price: price);
                      _done();
                    }
                    : null,
            child: FittedBox(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CoinIcon(size: 20),
                  Text(
                    ' $price',
                    style: outfit(
                      16,
                      w: FontWeight.w900,
                      color: const Color(0xFF00363D),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
