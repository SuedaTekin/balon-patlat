import 'dart:math';

import 'package:flutter/material.dart';

import 'audio.dart';
import 'billing.dart';
import 'game.dart';
import 'progress.dart';
import 'theme.dart';
import 'widgets.dart';

/// Ay adına göre sezon başlığı.
const seasonNames = [
  'Kış Masalı',
  'Buz Kristalleri',
  'Bahar Uyanışı',
  'Lale Bahçesi',
  'Gökkuşağı Şenliği',
  'Yaz Dalgası',
  'Mercan Resifi',
  'Yıldız Yağmuru',
  'Hasat Festivali',
  'Neon Gece',
  'Sihirli Gökyüzü',
  'Kar Tanesi Balosu',
];

String get seasonName => seasonNames[DateTime.now().month - 1];

Duration get seasonLeft {
  final n = DateTime.now();
  return DateTime(n.year, n.month + 1).difference(n);
}

const _boosterCycle = [
  Booster.rainbow,
  Booster.fire,
  Booster.laser,
  Booster.moves,
];

/// Kademe ödülü. Ücretsiz yol herkese, Altın Bilet yolu bileti alanlara.
Reward passReward(int tier, {required bool gold}) {
  final b = _boosterCycle[(tier ~/ 5) % _boosterCycle.length];
  if (tier == Progress.passTiers) {
    return gold
        ? const Reward(
          coins: 3000,
          infiniteMinutes: 180,
          boosters: {
            Booster.rainbow: 3,
            Booster.fire: 3,
            Booster.laser: 3,
            Booster.moves: 3,
          },
        )
        : const Reward(coins: 500, boosters: {Booster.rainbow: 2});
  }
  if (tier % 5 == 0) {
    return gold
        ? Reward(coins: 300, boosters: {b: 2})
        : Reward(coins: 100, boosters: {b: 1});
  }
  if (tier % 3 == 0) {
    return gold
        ? const Reward(coins: 200, infiniteMinutes: 60)
        : const Reward(infiniteMinutes: 15);
  }
  return gold ? Reward(coins: 150 + tier * 15) : Reward(coins: 50 + tier * 5);
}

class PassPage extends StatefulWidget {
  const PassPage({super.key, required this.onChanged});
  final VoidCallback onChanged;

  @override
  State<PassPage> createState() => _PassPageState();
}

class _PassPageState extends State<PassPage> {
  late final ScrollController _ctrl = ScrollController(
    initialScrollOffset: max(0, (Progress.passTier - 1) * 68.0),
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _claim(int tier, bool gold) async {
    if (!Progress.passClaimable(tier, gold: gold)) return;
    final r = passReward(tier, gold: gold);
    (gold ? Progress.passGoldClaimed : Progress.passFreeClaimed).add(tier);
    Progress.grant(r);
    Progress.save();
    Sfx.play('tier');
    Sfx.haptic(2);
    widget.onChanged();
    setState(() {});
    await showRewardDialog(
      context,
      'KADEME $tier ÖDÜLÜ',
      r,
      subtitle: gold ? 'Altın Bilet' : 'Ücretsiz yol',
    );
  }

  Future<void> _buyGold() async {
    if (!await Billing.buy(context, 'gold_pass')) return;
    widget.onChanged();
    setState(() {});
    if (mounted) {
      await showRewardDialog(
        context,
        'ALTIN BİLET AKTİF!',
        const Reward(),
        subtitle: 'Altın yoldaki tüm ödüller artık senin',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tier = Progress.passTier;
    final inTier =
        tier >= Progress.passTiers
            ? Progress.passXpPerTier
            : Progress.passXp % Progress.passXpPerTier;
    return ListView(
      controller: _ctrl,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        _header(tier, inTier),
        const SizedBox(height: 12),
        if (!Progress.passGold) ...[_goldOffer(), const SizedBox(height: 12)],
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  const Icon(Icons.verified_rounded, color: LP.cyan, size: 18),
                  const SizedBox(width: 4),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'ÜCRETSİZ',
                        style: outfit(13, color: LP.cyan),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Text('KADEME', style: outfit(12, color: LP.muted)),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'ALTIN BİLET',
                        style: outfit(13, color: LP.gold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.workspace_premium_rounded,
                    color: LP.gold,
                    size: 18,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (var t = 1; t <= Progress.passTiers; t++) _row(t, tier),
        const SizedBox(height: 8),
        Text(
          'Her galibiyet 10 XP, her yıldız +10 XP kazandırır. '
          'Sezon ay sonunda biter, alınmayan ödüller kaybolur.',
          textAlign: TextAlign.center,
          style: jakarta(12, color: LP.muted),
        ),
      ],
    );
  }

  Widget _header(int tier, int inTier) {
    final left = seasonLeft;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B1E8C), Color(0xFF1E1040)],
        ),
        border: Border.all(color: LP.surfaceHighest),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _pill(
                Icons.auto_awesome_rounded,
                'SEZON ${DateTime.now().month}',
                LP.gold,
              ),
              _pill(
                Icons.timer_outlined,
                '${left.inDays}g ${left.inHours % 24}s kaldı',
                LP.onSurface,
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(seasonName, style: outfit(30, w: FontWeight.w900)),
          ),
          Text(
            'Balon patlat, kademeleri aç, ödülleri topla!',
            style: jakarta(13, color: LP.muted),
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Kademe $tier',
                  style: outfit(26, w: FontWeight.w900, color: LP.gold),
                ),
                Text(
                  ' / ${Progress.passTiers}',
                  style: outfit(15, color: LP.muted),
                ),
                if (tier < Progress.passTiers) ...[
                  const SizedBox(width: 16),
                  Text(
                    '$inTier / ${Progress.passXpPerTier} XP',
                    style: outfit(17, color: LP.cyan),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 14,
              child: Stack(
                children: [
                  Container(color: LP.bgDeep),
                  FractionallySizedBox(
                    widthFactor: inTier / Progress.passXpPerTier,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [LP.pink, LP.gold, LP.cyan],
                        ),
                      ),
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

  Widget _pill(IconData icon, String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: LP.bgDeep.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(text, style: outfit(12, color: color)),
      ],
    ),
  );

  Widget _goldOffer() => GestureDetector(
    onTap: _buyGold,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            LP.gold.withValues(alpha: 0.25),
            LP.gold.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(color: LP.gold.withValues(alpha: 0.7), width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: LP.gold,
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: Color(0xFF3D2400),
              size: 30,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Altın Bilet\'i Aç',
                  style: outfit(19, w: FontWeight.w900, color: LP.gold),
                ),
                Text(
                  '30 kademede ek ödüller: ~15.000 altın, sonsuz can, '
                  'güçlendiriciler',
                  style: jakarta(12, color: LP.onSurface),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: LP.gold,
              borderRadius: BorderRadius.circular(999),
            ),
            child: MoneyText(
              Billing.price('gold_pass'),
              style: outfit(
                15,
                w: FontWeight.w900,
                color: const Color(0xFF3D2400),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _row(int t, int tier) {
    final reached = t <= tier;
    final current = t == tier + 1 || (t == tier && tier == Progress.passTiers);
    return Container(
      height: 62,
      margin: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _rewardCell(t, false, reached)),
          SizedBox(
            width: 58,
            child: Center(
              child: Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: reached ? LP.cyan : LP.surfaceHigh,
                  border: Border.all(
                    color: current ? LP.gold : Colors.transparent,
                    width: 3,
                  ),
                ),
                child: Text(
                  '$t',
                  style: outfit(
                    18,
                    w: FontWeight.w900,
                    color: reached ? const Color(0xFF00363D) : LP.muted,
                  ),
                ),
              ),
            ),
          ),
          Expanded(child: _rewardCell(t, true, reached)),
        ],
      ),
    );
  }

  Widget _rewardCell(int t, bool gold, bool reached) {
    final r = passReward(t, gold: gold);
    final claimed = (gold ? Progress.passGoldClaimed : Progress.passFreeClaimed)
        .contains(t);
    final can = Progress.passClaimable(t, gold: gold);
    final locked = gold && !Progress.passGold;
    final accent = gold ? LP.gold : LP.cyan;
    return GestureDetector(
      onTap: can ? () => _claim(t, gold) : (locked ? _buyGold : null),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color:
              can
                  ? accent.withValues(alpha: 0.18)
                  : LP.bgDeep.withValues(alpha: reached ? 0.6 : 0.35),
          border: Border.all(
            color: can ? accent : LP.surfaceHighest.withValues(alpha: 0.6),
            width: can ? 2 : 1,
          ),
        ),
        child: Opacity(
          opacity: claimed ? 0.45 : (reached || gold ? 1 : 0.7),
          child: Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: RewardChips(r),
                ),
              ),
              const SizedBox(width: 4),
              if (claimed)
                const Icon(Icons.check_circle_rounded, color: LP.cyan, size: 22)
              else if (locked)
                const Icon(Icons.lock_rounded, color: LP.gold, size: 20)
              else if (can)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'AL',
                    style: outfit(13, color: const Color(0xFF1A0E45)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
