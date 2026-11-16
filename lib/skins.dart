import 'package:flutter/material.dart';

import 'progress.dart';

/// Atıcı teması: halkanın renkleri ve kaidenin parıltısı (kozmetik).
class LauncherSkin {
  const LauncherSkin(this.id, this.name, this.price, this.ring, this.glow);
  final String id, name;
  final int price;
  final List<Color> ring;
  final Color glow;
}

const launcherSkins = [
  LauncherSkin('altin', 'Altın', 0, [
    Color(0xFFFFE07A),
    Color(0xFFFFB800),
    Color(0xFFC77700),
    Color(0xFFFFE07A),
  ], Color(0xFF00D8F5)),
  LauncherSkin('neon', 'Neon', 1500, [
    Color(0xFF00F0FF),
    Color(0xFFFF2BD6),
    Color(0xFF00F0FF),
  ], Color(0xFFFF2BD6)),
  LauncherSkin('ates', 'Ateş', 2000, [
    Color(0xFFFFE066),
    Color(0xFFFF7A1A),
    Color(0xFFE5243B),
    Color(0xFFFFE066),
  ], Color(0xFFFF7A1A)),
  LauncherSkin('buz', 'Buz', 2000, [
    Color(0xFFFFFFFF),
    Color(0xFF9BE7FF),
    Color(0xFF3FA9F5),
    Color(0xFFFFFFFF),
  ], Color(0xFF9BE7FF)),
  LauncherSkin('galaksi', 'Galaksi', 3000, [
    Color(0xFF7B3CFF),
    Color(0xFF2B6BFF),
    Color(0xFFFF4E9A),
    Color(0xFF7B3CFF),
  ], Color(0xFFB45CFF)),
  LauncherSkin('gokkusagi', 'Gökkuşağı', 4000, [
    Color(0xFFFF4E7C),
    Color(0xFFFFB800),
    Color(0xFF10E56A),
    Color(0xFF00D8F5),
    Color(0xFFA25CFF),
    Color(0xFFFF4E7C),
  ], Color(0xFFFFFFFF)),
];

LauncherSkin get currentSkin => launcherSkins.firstWhere(
  (s) => s.id == Progress.skin,
  orElse: () => launcherSkins.first,
);

/// Tema önizlemesi: halka + küçük kaide (mağaza kartları için).
class SkinPreview extends StatelessWidget {
  const SkinPreview(this.skin, {super.key, this.size = 64});
  final LauncherSkin skin;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _SkinPainter(skin)),
  );
}

class _SkinPainter extends CustomPainter {
  _SkinPainter(this.skin);
  final LauncherSkin skin;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.45);
    final r = size.width * 0.32;
    canvas.drawOval(
      Rect.fromCenter(
        center: c + Offset(0, r * 1.05),
        width: r * 2.8,
        height: r * 0.8,
      ),
      Paint()..color = skin.glow.withValues(alpha: 0.35),
    );
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF140A38));
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.28
        ..shader = SweepGradient(
          colors: skin.ring,
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  @override
  bool shouldRepaint(covariant _SkinPainter old) => old.skin != skin;
}
