import 'package:flutter/material.dart';

import 'audio.dart';
import 'game.dart';
import 'progress.dart';
import 'theme.dart';
import 'widgets.dart';

/// Kalıcı başarım: bir sayaç hedefe ulaşınca ödülü alınabilir.
class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.desc,
    required this.icon,
    required this.color,
    required this.target,
    required this.value,
    required this.reward,
  });
  final String id, title, desc;
  final IconData icon;
  final Color color;
  final int target;
  final int Function() value;
  final Reward reward;

  int get progress => value().clamp(0, target);
  bool get done => value() >= target;
  bool get claimed => Progress.claimedAch.contains(id);
  bool get ready => done && !claimed;
}

int _levelsDone() => Progress.unlocked - 1;
int _threeStars() => Progress.stars.values.where((s) => s == 3).length;

final achievements = <Achievement>[
  Achievement(
    id: 'lv1',
    title: 'İlk Adım',
    desc: 'İlk bölümünü bitir',
    icon: Icons.flag_rounded,
    color: LP.cyan,
    target: 1,
    value: _levelsDone,
    reward: const Reward(coins: 100),
  ),
  Achievement(
    id: 'lv25',
    title: 'Yolcu',
    desc: '25 bölüm bitir',
    icon: Icons.hiking_rounded,
    color: LP.cyan,
    target: 25,
    value: _levelsDone,
    reward: const Reward(coins: 300, boosters: {Booster.rainbow: 1}),
  ),
  Achievement(
    id: 'lv100',
    title: 'Kaşif',
    desc: '100 bölüm bitir',
    icon: Icons.explore_rounded,
    color: LP.cyan,
    target: 100,
    value: _levelsDone,
    reward: const Reward(coins: 1000, boosters: {Booster.fire: 2}),
  ),
  Achievement(
    id: 'lv300',
    title: 'Efsane',
    desc: '300 bölüm bitir',
    icon: Icons.emoji_events_rounded,
    color: LP.gold,
    target: 300,
    value: _levelsDone,
    reward: const Reward(
      coins: 5000,
      boosters: {Booster.rainbow: 3, Booster.fire: 3, Booster.laser: 3},
    ),
  ),
  Achievement(
    id: 'st50',
    title: 'Yıldız Toplayıcı',
    desc: '50 yıldız topla',
    icon: Icons.star_rounded,
    color: LP.gold,
    target: 50,
    value: () => Progress.totalStars,
    reward: const Reward(coins: 250),
  ),
  Achievement(
    id: 'st300',
    title: 'Yıldız Avcısı',
    desc: '300 yıldız topla',
    icon: Icons.auto_awesome_rounded,
    color: LP.gold,
    target: 300,
    value: () => Progress.totalStars,
    reward: const Reward(coins: 1500, infiniteMinutes: 60),
  ),
  Achievement(
    id: 'perfect20',
    title: 'Mükemmeliyetçi',
    desc: '20 bölümü 3 yıldızla bitir',
    icon: Icons.workspace_premium_rounded,
    color: Color(0xFFFFE07A),
    target: 20,
    value: _threeStars,
    reward: const Reward(coins: 500, boosters: {Booster.laser: 2}),
  ),
  Achievement(
    id: 'pop1k',
    title: 'Patlatıcı',
    desc: '1.000 balon patlat',
    icon: Icons.bubble_chart_rounded,
    color: LP.pink,
    target: 1000,
    value: () => Progress.life('pop'),
    reward: const Reward(coins: 300),
  ),
  Achievement(
    id: 'pop10k',
    title: 'Balon Fırtınası',
    desc: '10.000 balon patlat',
    icon: Icons.storm_rounded,
    color: LP.pink,
    target: 10000,
    value: () => Progress.life('pop'),
    reward: const Reward(coins: 2000, boosters: {Booster.fire: 3}),
  ),
  Achievement(
    id: 'drop500',
    title: 'Yer Çekimi',
    desc: '500 balonu koparıp düşür',
    icon: Icons.south_rounded,
    color: Color(0xFF10E56A),
    target: 500,
    value: () => Progress.life('drop'),
    reward: const Reward(coins: 400, boosters: {Booster.moves: 1}),
  ),
  Achievement(
    id: 'combo50',
    title: 'Kombo Ustası',
    desc: '50 kez x3 kombo yap',
    icon: Icons.bolt_rounded,
    color: Color(0xFFA25CFF),
    target: 50,
    value: () => Progress.life('combo3'),
    reward: const Reward(coins: 600, boosters: {Booster.rainbow: 2}),
  ),
  Achievement(
    id: 'bomb25',
    title: 'Bomba Uzmanı',
    desc: '25 bomba patlat',
    icon: Icons.flash_on_rounded,
    color: Color(0xFFFF4D4D),
    target: 25,
    value: () => Progress.life('bomb'),
    reward: const Reward(coins: 500),
  ),
  Achievement(
    id: 'spin30',
    title: 'Şans Meraklısı',
    desc: 'Şans çarkını 30 kez çevir',
    icon: Icons.casino_rounded,
    color: Color(0xFFFF7A1A),
    target: 30,
    value: () => Progress.life('spin'),
    reward: const Reward(coins: 800, infiniteMinutes: 30),
  ),
  Achievement(
    id: 'pass10',
    title: 'Sezon Avcısı',
    desc: 'Bubble Pass\'te 10. kademeye ulaş',
    icon: Icons.confirmation_number_rounded,
    color: LP.gold,
    target: 10,
    value: () => Progress.passTier,
    reward: const Reward(coins: 700),
  ),
  Achievement(
    id: 'rich10k',
    title: 'Hazine Avcısı',
    desc: 'Elinde 10.000 altın biriktir',
    icon: Icons.savings_rounded,
    color: LP.gold,
    target: 10000,
    value: () => Progress.coins,
    reward: const Reward(boosters: {Booster.rainbow: 2, Booster.laser: 2}),
  ),
];

int get achievementsReady => achievements.where((a) => a.ready).length;

class AchievementsPage extends StatefulWidget {
  const AchievementsPage({super.key, required this.onChanged});
  final VoidCallback onChanged;

  @override
  State<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends State<AchievementsPage> {
  Future<void> _claim(Achievement a) async {
    if (!a.ready) return;
    Progress.claimedAch.add(a.id);
    Progress.grant(a.reward);
    Progress.save();
    Sfx.play('tier');
    Sfx.haptic(2);
    widget.onChanged();
    setState(() {});
    await showRewardDialog(
      context,
      'BAŞARIM AÇILDI!',
      a.reward,
      subtitle: a.title,
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = [...achievements]..sort((a, b) {
      int rank(Achievement x) => x.ready ? 0 : (x.claimed ? 2 : 1);
      return rank(a).compareTo(rank(b));
    });
    final done = achievements.where((a) => a.claimed).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: glassCard(border: LP.gold.withValues(alpha: 0.5)),
          child: Row(
            children: [
              const Icon(Icons.military_tech_rounded, color: LP.gold, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Başarımlar', style: outfit(22, w: FontWeight.w900)),
                    Text(
                      '$done / ${achievements.length} rozet kazanıldı',
                      style: jakarta(13, color: LP.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final a in list) ...[_card(a), const SizedBox(height: 10)],
      ],
    );
  }

  Widget _card(Achievement a) {
    final k = a.progress / a.target;
    return GestureDetector(
      onTap: a.ready ? () => _claim(a) : null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: glassCard(border: a.ready ? a.color : null),
        child: Opacity(
          opacity: a.claimed ? 0.55 : 1,
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      a.done
                          ? a.color.withValues(alpha: 0.25)
                          : LP.bgDeep.withValues(alpha: 0.6),
                  border: Border.all(
                    color: a.done ? a.color : LP.surfaceHighest,
                    width: 2,
                  ),
                ),
                child: Icon(
                  a.icon,
                  color: a.done ? a.color : LP.muted,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.title, style: outfit(16, w: FontWeight.w900)),
                    Text(a.desc, style: jakarta(12, color: LP.muted)),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: k,
                        minHeight: 7,
                        backgroundColor: LP.bgDeep,
                        valueColor: AlwaysStoppedAnimation(a.color),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${formatNum(a.progress)} / ${formatNum(a.target)}',
                          style: outfit(11, color: LP.muted),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: RewardChips(a.reward),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (a.claimed)
                const Icon(Icons.check_circle_rounded, color: LP.cyan)
              else if (a.ready)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: a.color,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'AL',
                    style: outfit(14, color: const Color(0xFF1A0E45)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
