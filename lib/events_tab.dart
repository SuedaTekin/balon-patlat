import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'achievements.dart';
import 'game.dart';
import 'pass_tab.dart';
import 'progress.dart';
import 'quests.dart';
import 'theme.dart';
import 'widgets.dart';

class SpinSlice {
  const SpinSlice(this.label, this.icon, this.color, this.weight, this.reward);
  final String label;
  final IconData icon;
  final Color color;
  final int weight;
  final Reward reward;

  bool get darkText => color == LP.gold || color == LP.cyan;
}

const _dark = Color(0xFF2B2548);

const spinSlices = <SpinSlice>[
  SpinSlice('JACKPOT', Icons.stars_rounded, LP.gold, 5, Reward(coins: 1000)),
  SpinSlice(
    'GÖKKUŞAĞI',
    Icons.palette_rounded,
    LP.ruby,
    12,
    Reward(boosters: {Booster.rainbow: 1}),
  ),
  SpinSlice(
    '250 ALTIN',
    Icons.monetization_on_rounded,
    _dark,
    14,
    Reward(coins: 250),
  ),
  SpinSlice(
    'ATEŞ TOPU',
    Icons.local_fire_department_rounded,
    LP.cyan,
    12,
    Reward(boosters: {Booster.fire: 1}),
  ),
  SpinSlice(
    '30 DK CAN',
    Icons.all_inclusive_rounded,
    LP.ruby,
    10,
    Reward(infiniteMinutes: 30),
  ),
  SpinSlice(
    'LAZER',
    Icons.navigation_rounded,
    _dark,
    12,
    Reward(boosters: {Booster.laser: 1}),
  ),
  SpinSlice(
    '+5 HAMLE',
    Icons.add_circle_rounded,
    LP.cyan,
    14,
    Reward(boosters: {Booster.moves: 1}),
  ),
  SpinSlice(
    '100 ALTIN',
    Icons.monetization_on_rounded,
    _dark,
    21,
    Reward(coins: 100),
  ),
];

int pickSlice(Random rnd) {
  final total = spinSlices.fold(0, (s, x) => s + x.weight);
  var roll = rnd.nextInt(total);
  for (var i = 0; i < spinSlices.length; i++) {
    roll -= spinSlices[i].weight;
    if (roll < 0) return i;
  }
  return spinSlices.length - 1;
}

class EventsTab extends StatefulWidget {
  const EventsTab({super.key, required this.onChanged, required this.onPlay});
  final VoidCallback onChanged;
  final VoidCallback onPlay;

  @override
  State<EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<EventsTab>
    with SingleTickerProviderStateMixin {
  int _page = 0;
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  );
  double _from = 0, _to = 0;
  bool _spinning = false;
  final _rnd = Random();

  double get _rotation =>
      _from + (_to - _from) * Curves.easeOutCubic.transform(_anim.value);

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _spin() async {
    if (_spinning) return;
    // Çark günde yalnızca 1 kez çevrilir.
    if (!Progress.freeSpinAvailable) return;
    Progress.useFreeSpin();
    HapticFeedback.mediumImpact();
    final i = pickSlice(_rnd);
    final seg = 2 * pi / spinSlices.length;
    final cur = _rotation % (2 * pi);
    final jitter = (_rnd.nextDouble() - 0.5) * seg * 0.6;
    var target = -(i + 0.5) * seg + jitter;
    target = (target % (2 * pi) + 2 * pi) % (2 * pi);
    _from = cur;
    _to = (target <= cur ? target + 2 * pi : target) + 2 * pi * 6;
    setState(() => _spinning = true);
    widget.onChanged();
    await _anim.forward(from: 0);
    if (!mounted) return;
    final s = spinSlices[i];
    Progress.grant(s.reward);
    Progress.addStat('spin');
    Progress.save();
    setState(() => _spinning = false);
    widget.onChanged();
    HapticFeedback.heavyImpact();
    await showRewardDialog(
      context,
      s.label == 'JACKPOT' ? 'JACKPOT!' : 'TEBRİKLER!',
      s.reward,
      subtitle: 'Çarktan kazandın',
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ready = readyQuestCount;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: LP.bgDeep.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                _segment(
                  0,
                  Icons.casino_rounded,
                  'Çark',
                  Progress.freeSpinAvailable || Progress.streakClaimable
                      ? '!'
                      : null,
                ),
                _segment(
                  1,
                  Icons.task_alt_rounded,
                  'Görev',
                  ready > 0 ? '$ready' : null,
                ),
                _segment(
                  2,
                  Icons.workspace_premium_rounded,
                  'Bilet',
                  Progress.passReadyCount > 0
                      ? '${Progress.passReadyCount}'
                      : null,
                ),
                _segment(
                  3,
                  Icons.military_tech_rounded,
                  'Rozet',
                  achievementsReady > 0 ? '$achievementsReady' : null,
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: switch (_page) {
            0 => _spinPage(),
            1 => _questPage(),
            2 => PassPage(onChanged: widget.onChanged),
            _ => AchievementsPage(
              onChanged: () {
                widget.onChanged();
                setState(() {});
              },
            ),
          },
        ),
      ],
    );
  }

  Widget _segment(int i, IconData icon, String text, String? badge) {
    final on = _page == i;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _page = i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: on ? LP.surfaceHighest : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: on ? LP.cyan : LP.muted),
              const SizedBox(width: 6),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    text,
                    style: outfit(15, color: on ? LP.onSurface : LP.muted),
                  ),
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: LP.ruby,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(badge, style: outfit(12, color: Colors.white)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ===================== ÇARK =====================

  Widget _spinPage() {
    final free = Progress.freeSpinAvailable;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFF8FB0), Color(0xFFFF4E7C)],
            ),
            boxShadow: const [
              BoxShadow(color: LP.rubyLedge, offset: Offset(0, 6)),
            ],
          ),
          child: Text(
            'GÜNLÜK ŞANS ÇARKI',
            textAlign: TextAlign.center,
            style: outfit(
              26,
              w: FontWeight.w900,
              color: const Color(0xFF4A0018),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: LP.bgDeep.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              free
                  ? '● Günün İlk Çevirmesi ÜCRETSİZ!'
                  : 'Bugünkü hakkını kullandın, yarın tekrar gel!',
              style: outfit(14, color: free ? LP.gold : LP.muted),
            ),
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, c) {
            final size = min(c.maxWidth, 340.0);
            return Center(
              child: SizedBox(
                width: size,
                height: size,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _anim,
                      builder:
                          (_, __) => CustomPaint(
                            size: Size(size, size),
                            painter: _WheelPainter(_rotation),
                          ),
                    ),
                    GestureDetector(
                      onTap: free ? _spin : null,
                      child: Container(
                        width: size * 0.26,
                        height: size * 0.26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(
                            center: Alignment(-0.3, -0.4),
                            colors: [Color(0xFFFF9DBA), Color(0xFFFF4E7C)],
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: LP.rubyLedge,
                              offset: Offset(0, 5),
                            ),
                            BoxShadow(color: Colors.black54, blurRadius: 14),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.sync_rounded,
                              color: Color(0xFF4A0018),
                              size: 22,
                            ),
                            FittedBox(
                              child: Text(
                                'ÇEVİR',
                                style: outfit(
                                  18,
                                  w: FontWeight.w900,
                                  color: const Color(0xFF4A0018),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      child: CustomPaint(
                        size: const Size(34, 40),
                        painter: _PointerPainter(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        JuicyButton.gold(
          height: 72,
          onTap: _spinning || !free ? null : _spin,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.play_circle_outline_rounded,
                  color: Color(0xFF3D2400),
                  size: 30,
                ),
                const SizedBox(width: 10),
                if (free)
                  Text(
                    'ÜCRETSİZ ÇEVİR',
                    style: outfit(
                      24,
                      w: FontWeight.w900,
                      color: const Color(0xFF3D2400),
                    ),
                  )
                else
                  const SpinCountdown(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        _streakCard(),
      ],
    );
  }

  Widget _streakCard() {
    final today = Progress.streakDayToday;
    final claimable = Progress.streakClaimable;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: glassCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: LP.surfaceHighest,
                ),
                child: const Icon(
                  Icons.local_fire_department_rounded,
                  color: LP.pink,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('GİRİŞ SERİSİ', style: outfit(22, w: FontWeight.w900)),
                    Text(
                      'Her gün gel, Kral Sandığını kap!',
                      style: jakarta(12, color: LP.muted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: LP.surfaceHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${claimable ? today - 1 : today} / 7 GÜN',
                  style: outfit(15, color: LP.gold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (var d = 1; d <= 7; d++)
                Expanded(child: _streakDay(d, today, claimable)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: LP.bgDeep.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Text('$today. Gün Ödülü:', style: jakarta(13)),
                const SizedBox(width: 8),
                Expanded(child: RewardChips(Progress.streakReward(today))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (claimable)
            JuicyButton.ruby(
              height: 56,
              onTap: () async {
                final r = Progress.claimStreak();
                widget.onChanged();
                setState(() {});
                if (r != null) {
                  HapticFeedback.mediumImpact();
                  await showRewardDialog(context, '$today. GÜN ÖDÜLÜ', r);
                }
              },
              child: Text(
                'ÖDÜLÜ AL',
                style: outfit(20, w: FontWeight.w900, color: Colors.white),
              ),
            )
          else
            Center(
              child: Text(
                '✓ Bugünün ödülü alındı — yarın tekrar gel!',
                style: outfit(14, color: LP.emerald),
              ),
            ),
        ],
      ),
    );
  }

  Widget _streakDay(int d, int today, bool claimable) {
    final done = d < today || (d == today && !claimable);
    final isToday = d == today && claimable;
    final king = d == 7;
    final Color bg =
        isToday
            ? LP.ruby
            : king
            ? LP.gold
            : done
            ? LP.surfaceHighest
            : LP.surface;
    final IconData icon =
        done
            ? Icons.check_rounded
            : king
            ? Icons.workspace_premium_rounded
            : isToday
            ? Icons.redeem_rounded
            : Icons.lock_rounded;
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bg,
            boxShadow:
                isToday
                    ? [
                      BoxShadow(
                        color: LP.ruby.withValues(alpha: 0.6),
                        blurRadius: 14,
                      ),
                    ]
                    : null,
          ),
          child: Icon(
            icon,
            size: 20,
            color:
                king && !done
                    ? const Color(0xFF6B3E00)
                    : done
                    ? LP.cyan
                    : Colors.white70,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          child: Text(
            isToday ? 'BUGÜN' : (king ? 'KRAL' : '$d. Gün'),
            style: outfit(
              11,
              color:
                  isToday
                      ? LP.pink
                      : king
                      ? LP.gold
                      : LP.muted,
            ),
          ),
        ),
      ],
    );
  }

  // ===================== GÖREVLER =====================

  Widget _questPage() {
    final quests = dailyQuests();
    final now = DateTime.now();
    final left = DateTime(now.year, now.month, now.day + 1).difference(now);
    final claimed = quests.where((q) => q.claimed).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      children: [
        Row(
          children: [
            const Icon(Icons.bolt_rounded, color: LP.cyan),
            const SizedBox(width: 6),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'Günlük Görevler',
                  style: outfit(20, w: FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: LP.surfaceHighest,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${left.inHours}s ${left.inMinutes.remainder(60)}d kaldı',
                style: outfit(12, color: LP.muted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final q in quests) ...[_questCard(q), const SizedBox(height: 12)],
        _bonusCard(claimed),
      ],
    );
  }

  Future<void> _claim(QuestDef q) async {
    if (!q.ready) return;
    Progress.grant(q.reward);
    Progress.markClaimed(q.id);
    widget.onChanged();
    setState(() {});
    HapticFeedback.mediumImpact();
    await showRewardDialog(
      context,
      'GÖREV TAMAM!',
      q.reward,
      subtitle: q.title,
    );
  }

  Widget _questCard(QuestDef q) {
    final ready = q.ready;
    final claimed = q.claimed;
    return Opacity(
      opacity: claimed ? 0.6 : 1,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: glassCard(
          border: ready ? LP.cyan.withValues(alpha: 0.7) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: q.color.withValues(alpha: 0.2),
                  ),
                  child: Icon(q.icon, color: q.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(q.title, style: outfit(18, w: FontWeight.w900)),
                      Text(q.desc, style: jakarta(12, color: LP.muted)),
                    ],
                  ),
                ),
                if (ready)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: LP.cyan),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('HAZIR', style: outfit(11, color: LP.cyan)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  q.done ? 'Tamamlandı!' : 'İlerleme',
                  style: outfit(13, w: FontWeight.w700),
                ),
                const Spacer(),
                Text(
                  '${q.progress} / ${q.target}',
                  style: outfit(13, color: q.done ? LP.cyan : LP.gold),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: q.progress / q.target,
                minHeight: 10,
                backgroundColor: LP.bgDeep,
                color: q.done ? LP.cyan : LP.gold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: RewardChips(q.reward),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 140,
                  child:
                      claimed
                          ? Center(
                            child: Text(
                              '✓ ALINDI',
                              style: outfit(15, color: LP.muted),
                            ),
                          )
                          : ready
                          ? JuicyButton.ruby(
                            height: 48,
                            padding: EdgeInsets.zero,
                            onTap: () => _claim(q),
                            child: FittedBox(
                              child: Text(
                                'ÖDÜLÜ AL',
                                style: outfit(
                                  17,
                                  w: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          )
                          : JuicyButton.cyan(
                            height: 48,
                            padding: EdgeInsets.zero,
                            onTap:
                                q.stat == 'spin'
                                    ? () => setState(() => _page = 0)
                                    : widget.onPlay,
                            child: FittedBox(
                              child: Text(
                                q.stat == 'spin' ? 'ÇEVİR ▶' : 'OYNA ▶',
                                style: outfit(
                                  17,
                                  w: FontWeight.w900,
                                  color: const Color(0xFF00363D),
                                ),
                              ),
                            ),
                          ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bonusCard(int claimed) {
    final done = Progress.isClaimed(bonusId);
    final ready = bonusReady;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: glassCard(border: ready ? LP.gold : null),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: LP.surfaceHighest,
            ),
            child: Icon(
              done ? Icons.lock_open_rounded : Icons.lock_rounded,
              color: LP.gold,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Günün Bonusu',
                          style: outfit(17, w: FontWeight.w900),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('$claimed/3', style: outfit(13, color: LP.cyan)),
                  ],
                ),
                const SizedBox(height: 4),
                const RewardChips(dailyBonus),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child:
                done
                    ? Center(
                      child: Text(
                        '✓ ALINDI',
                        style: outfit(14, color: LP.muted),
                      ),
                    )
                    : JuicyButton.ruby(
                      height: 46,
                      padding: EdgeInsets.zero,
                      onTap:
                          ready
                              ? () async {
                                Progress.grant(dailyBonus);
                                Progress.markClaimed(bonusId);
                                widget.onChanged();
                                setState(() {});
                                await showRewardDialog(
                                  context,
                                  'GÜNÜN BONUSU!',
                                  dailyBonus,
                                );
                              }
                              : null,
                      child: FittedBox(
                        child: Text(
                          ready ? 'AL' : '${3 - claimed} GÖREV',
                          style: outfit(
                            15,
                            w: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter(this.rotation);
  final double rotation;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final outer = size.width / 2;
    final r = outer * 0.86;
    // dış çerçeve
    canvas.drawCircle(
      c,
      outer * 0.97,
      Paint()
        ..color = LP.surfaceHigh
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 6),
    );
    canvas.drawCircle(
      c,
      outer * 0.97,
      Paint()..color = const Color(0xFF241C45),
    );
    for (var i = 0; i < 8; i++) {
      final a = -pi / 2 + i * pi / 4 + pi / 8;
      final p = c + Offset(cos(a), sin(a)) * outer * 0.915;
      canvas.drawCircle(
        p,
        outer * 0.035,
        Paint()
          ..color = const Color(0xFFFFE07A)
          ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4),
      );
    }

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(rotation);
    final seg = 2 * pi / spinSlices.length;
    final rect = Rect.fromCircle(center: Offset.zero, radius: r);
    for (var i = 0; i < spinSlices.length; i++) {
      final s = spinSlices[i];
      final start = -pi / 2 + i * seg;
      canvas.drawArc(
        rect,
        start,
        seg,
        true,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Color.lerp(s.color, Colors.white, 0.15)!,
              s.color,
              Color.lerp(s.color, Colors.black, 0.35)!,
            ],
            stops: const [0, 0.6, 1],
          ).createShader(rect),
      );
      canvas.drawLine(
        Offset.zero,
        Offset(cos(start), sin(start)) * r,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.18)
          ..strokeWidth = 2,
      );
      // etiket
      final mid = start + seg / 2;
      canvas.save();
      canvas.rotate(mid);
      final col = s.darkText ? const Color(0xFF2A1A00) : Colors.white;
      final tp = TextPainter(
        text: TextSpan(
          text: s.label,
          style: outfit(r * 0.085, w: FontWeight.w900, color: col),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(r * 0.36, -tp.height / 2));
      final ip = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(s.icon.codePoint),
          style: TextStyle(
            fontFamily: s.icon.fontFamily,
            package: s.icon.fontPackage,
            fontSize: r * 0.13,
            color: col,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      ip.paint(canvas, Offset(r * 0.36 + tp.width + 4, -ip.height / 2));
      canvas.restore();
    }
    canvas.restore();
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white.withValues(alpha: 0.25),
    );
  }

  @override
  bool shouldRepaint(_WheelPainter old) => old.rotation != rotation;
}

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path =
        Path()
          ..moveTo(0, 0)
          ..lineTo(size.width, 0)
          ..lineTo(size.width / 2, size.height)
          ..close();
    canvas.drawShadow(path, Colors.black, 4, false);
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [LP.goldLight, LP.gold],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Çark kullanıldıysa gece yarısına kalan süre.
class SpinCountdown extends StatefulWidget {
  const SpinCountdown({super.key});

  @override
  State<SpinCountdown> createState() => _SpinCountdownState();
}

class _SpinCountdownState extends State<SpinCountdown> {
  late final Timer _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final left = DateTime(now.year, now.month, now.day + 1).difference(now);
    return Text(
      'YENİ HAK: ${fmtDuration(left)}',
      style: outfit(22, w: FontWeight.w900, color: const Color(0xFF3D2400)),
    );
  }
}
