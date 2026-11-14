import 'dart:math';

import 'package:flutter/material.dart';

import 'cloud/cloud.dart';
import 'cloud/leaderboard_tab.dart';
import 'game.dart';
import 'progress.dart';
import 'theme.dart';
import 'widgets.dart';

/// Arkadaşları bulundukları bölümün yanında gösterir (en fazla 2 kişi/bölüm).
List<Widget> _friendChips(List<Offset> pts, double w) {
  final friends = Cloud.friendsCache?.friends ?? const <Profile>[];
  final byLevel = <int, List<Profile>>{};
  for (final f in friends) {
    final l = f.level.clamp(1, pts.length);
    (byLevel[l] ??= []).add(f);
  }
  final out = <Widget>[];
  byLevel.forEach((level, list) {
    final p = pts[level - 1];
    final right = p.dx < w / 2;
    for (var i = 0; i < list.length && i < 2; i++) {
      out.add(
        Positioned(
          top: p.dy - 14 + i * 32 - (list.length > 1 ? 16 : 0),
          left: right ? p.dx + 58 : null,
          right: right ? null : w - p.dx + 58,
          child: FriendChip(list[i]),
        ),
      );
    }
  });
  return out;
}

const regionNames = [
  'Şeker Vadisi',
  'Kristal Göl',
  'Neon Orman',
  'Yıldız Tozu Çölü',
  'Gökkuşağı Krallığı',
  'Kuasar Adası',
  'Ay Işığı Bahçesi',
  'Süpernova Zirvesi',
  'Mercan Lagünü',
  'Buzul Sarayı',
  'Lav Kanyonu',
  'Bulut Şehri',
  'Kehribar Ormanı',
  'Fırtına Burnu',
  'Lale Tepeleri',
  'Gece Çarşısı',
  'Safir Mağarası',
  'Rüzgar Değirmenleri',
  'Altın Kumsal',
  'Nebula Yolu',
  'Kristal Labirent',
  'Volkan Adası',
  'Kuzey Işıkları',
  'Gizemli Bataklık',
  'Ejder Vadisi',
  'Pembe Okyanus',
  'Zümrüt Şelalesi',
  'Gölge Kalesi',
  'Galaksi Kapısı',
  'Balon Tahtı',
];
const levelsPerRegion = 10;

class MapTab extends StatefulWidget {
  const MapTab({super.key, required this.onOpen});

  /// Bölüm açma isteği (can kontrolü kabukta yapılır).
  final Future<void> Function(int level) onOpen;

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  static const spacing = 120.0;
  static const bottomPad = 90.0;
  late final ScrollController _ctrl = ScrollController(
    initialScrollOffset: max(0, (Progress.unlocked - 1) * spacing - 220),
  );

  /// Gösterilen düğüm sayısı: bulunulan bölgenin bir sonrakinin sonuna kadar.
  int get shown => min(
    maxLevel,
    max(30, ((Progress.unlocked - 1) ~/ levelsPerRegion + 2) * levelsPerRegion),
  );

  Future<void> _open(int level) async {
    await widget.onOpen(level);
    if (mounted) setState(() {});
  }

  Offset _pos(int level, double w, double h) => Offset(
    w / 2 + sin(level * 0.85) * w * 0.27,
    h - bottomPad - (level - 1) * spacing,
  );

  @override
  Widget build(BuildContext context) {
    final current = Progress.unlocked;
    final region = (current - 1) ~/ levelsPerRegion;
    return Column(
      children: [
        _regionCard(region),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              final h = shown * spacing + bottomPad + 80;
              final pts = [for (var i = 1; i <= shown; i++) _pos(i, w, h)];
              return SingleChildScrollView(
                controller: _ctrl,
                reverse: true,
                child: SizedBox(
                  width: w,
                  height: h,
                  child: Stack(
                    children: [
                      CustomPaint(
                        size: Size(w, h),
                        painter: _PathPainter(pts, current - 1),
                      ),
                      for (
                        var i = levelsPerRegion + 1;
                        i <= shown;
                        i += levelsPerRegion
                      )
                        _regionGate(i, pts[i - 2], pts[i - 1]),
                      for (var i = 1; i <= shown; i++)
                        ..._node(i, pts[i - 1], current),
                      if (shown < maxLevel)
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 18,
                          child: Center(
                            child: Text(
                              'Daha fazlası için ilerle ▲',
                              style: outfit(13, color: LP.muted),
                            ),
                          ),
                        ),
                      ..._friendChips(pts, w),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _regionCard(int region) {
    final first = region * levelsPerRegion + 1;
    final totalStars = Progress.stars.values.fold(0, (a, b) => a + b);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: glassCard(),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF8CF5FF), LP.cyanDeep],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: const Icon(Icons.castle_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BÖLGE ${region + 1}',
                  style: outfit(12, color: LP.cyan, spacing: 1.5),
                ),
                Text(
                  regionNames[region % regionNames.length],
                  style: outfit(22, w: FontWeight.w900),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: LP.surfaceHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Bölüm $first-${first + levelsPerRegion - 1}',
                  style: outfit(12, w: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: LP.gold, size: 18),
                  Text(' $totalStars', style: outfit(14, color: LP.gold)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Bölgeler arası geçişte yol üstünde bölge adını gösteren rozet.
  Widget _regionGate(int firstLevel, Offset a, Offset b) {
    final region = (firstLevel - 1) ~/ levelsPerRegion;
    final y = (a.dy + b.dy) / 2;
    final locked = firstLevel > Progress.unlocked;
    return Positioned(
      left: 0,
      right: 0,
      top: y - 16,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: locked ? LP.surfaceHigh : const Color(0xFF2A1F5C),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: locked ? LP.surfaceHighest : LP.gold,
              width: 2,
            ),
          ),
          child: Text(
            'BÖLGE ${region + 1} · ${regionNames[region % regionNames.length]}',
            style: outfit(13, color: locked ? LP.muted : LP.gold),
          ),
        ),
      ),
    );
  }

  List<Widget> _node(int level, Offset p, int current) {
    final kind = LevelConfig.kindOf(level);
    Widget centered(Offset at, Widget child) => Positioned(
      left: at.dx,
      top: at.dy,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: child,
      ),
    );

    if (level == current) {
      return [
        centered(
          p,
          GestureDetector(
            onTap: () => _open(level),
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  center: Alignment(-0.3, -0.4),
                  colors: [Color(0xFFFF7FA8), LP.ruby, LP.rubyLedge],
                  stops: [0, 0.55, 1],
                ),
                boxShadow: [
                  BoxShadow(
                    color: LP.ruby.withValues(alpha: 0.6),
                    blurRadius: 40,
                  ),
                  const BoxShadow(color: LP.rubyLedge, offset: Offset(0, 6)),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$level',
                    style: outfit(
                      36,
                      w: FontWeight.w900,
                      color: Colors.white,
                      shadows: embossShadow,
                    ),
                  ),
                  Text(
                    '▶ OYNA',
                    style: outfit(12, color: Colors.white, spacing: 1),
                  ),
                ],
              ),
            ),
          ),
        ),
        centered(
          p + const Offset(0, -62),
          kind == LevelKind.normal
              ? Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: LP.gold,
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Color(0xFF6B3E00),
                  size: 24,
                ),
              )
              : Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: kindColor(kind),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  kind == LevelKind.hard ? '🔥 ZOR' : '🔥 ÇOK ZOR',
                  style: outfit(12, color: Colors.white),
                ),
              ),
        ),
        centered(
          p + const Offset(0, 68),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: LP.ruby.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '● SEN BURADASIN',
              style: outfit(12, color: Colors.white, spacing: 0.5),
            ),
          ),
        ),
      ];
    }

    if (level < current) {
      final s = Progress.stars[level] ?? 0;
      return [
        centered(
          p,
          GestureDetector(
            onTap: () => _open(level),
            child: Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  center: Alignment(-0.3, -0.4),
                  colors: [Color(0xFFB8FAFF), LP.cyan, LP.cyanLedge],
                  stops: [0, 0.55, 1],
                ),
                boxShadow: [
                  BoxShadow(
                    color: LP.cyan.withValues(alpha: 0.4),
                    blurRadius: 18,
                  ),
                  const BoxShadow(color: LP.cyanLedge, offset: Offset(0, 4)),
                ],
                border:
                    kind == LevelKind.normal
                        ? null
                        : Border.all(color: kindColor(kind), width: 3),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$level',
                    style: outfit(
                      22,
                      w: FontWeight.w900,
                      color: const Color(0xFF00363D),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < 3; i++)
                        Icon(
                          Icons.star_rounded,
                          size: 13,
                          color:
                              i < s
                                  ? LP.gold
                                  : const Color(
                                    0xFF00363D,
                                  ).withValues(alpha: 0.35),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ];
    }

    return [
      centered(
        p,
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: LP.surfaceHigh,
            border: Border.all(
              color:
                  kind == LevelKind.normal
                      ? LP.surfaceHighest
                      : kindColor(kind).withValues(alpha: 0.7),
              width: 3,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                level == maxLevel
                    ? Icons.emoji_events_rounded
                    : kind == LevelKind.normal
                    ? Icons.lock_rounded
                    : Icons.local_fire_department_rounded,
                size: 18,
                color: kind == LevelKind.normal ? LP.muted : kindColor(kind),
              ),
              Text('$level', style: outfit(13, color: LP.muted)),
            ],
          ),
        ),
      ),
    ];
  }
}

class _PathPainter extends CustomPainter {
  _PathPainter(this.pts, this.doneIndex);
  final List<Offset> pts;
  final int doneIndex;

  Path _path(int upTo) {
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (var i = 1; i <= upTo && i < pts.length; i++) {
      final a = pts[i - 1], b = pts[i];
      final my = (a.dy + b.dy) / 2;
      path.cubicTo(a.dx, my, b.dx, my, b.dx, b.dy);
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      _path(pts.length - 1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 22
        ..strokeCap = StrokeCap.round
        ..color = LP.surfaceHigh,
    );
    if (doneIndex > 0) {
      canvas.drawPath(
        _path(doneIndex),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round
          ..color = LP.cyan.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawPath(
        _path(doneIndex),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..color = LP.cyan.withValues(alpha: 0.8),
      );
    }
  }

  @override
  bool shouldRepaint(_PathPainter old) =>
      old.doneIndex != doneIndex || old.pts.length != pts.length;
}

class LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width * 0.26;
    drawBubble(
      canvas,
      Offset(r * 1.1, size.height - r * 1.1),
      r,
      const Color(0xFF00D8F5),
      glow: false,
    );
    drawBubble(
      canvas,
      Offset(size.width - r * 1.1, size.height - r * 1.1),
      r,
      const Color(0xFFFFB800),
      glow: false,
    );
    drawBubble(
      canvas,
      Offset(size.width / 2, r * 1.2),
      r * 1.15,
      const Color(0xFFFF4E7C),
      glow: false,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
