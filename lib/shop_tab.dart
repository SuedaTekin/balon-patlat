import 'package:flutter/material.dart';

import 'ads.dart';
import 'audio.dart';
import 'billing.dart';
import 'game.dart';
import 'progress.dart';
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
        _freeGift(),
        const SizedBox(height: 12),
        _adCoins(),
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
