// Uygulama ikonunu oyunun kendi balon çizimiyle üretir.
// Çalıştırma: flutter test test/icon_gen_test.dart --dart-define=ICON=1
// Çıktı: build/icon/{full,foreground,background,play_store_512}.png
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:balon_patlat/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _size = 1024.0;

Path _star(Offset c, double r1, double r2, int n, [double rot = 0]) {
  final p = Path();
  for (var i = 0; i < n * 2; i++) {
    final r = i.isEven ? r1 : r2;
    final a = rot + i * pi / n - pi / 2;
    final o = c + Offset(cos(a), sin(a)) * r;
    i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
  }
  return p..close();
}

/// Sahne: üstte balon kümesi, ortada patlama, alttan fırlayan pembe balon
/// ve altın atıcı. [s] tuval boyu, [k] ölçek (güvenli alan için).
void _scene(Canvas canvas, double s, {double k = 1}) {
  canvas.save();
  canvas.translate(s / 2, s / 2);
  canvas.scale(k);
  canvas.translate(-s / 2, -s / 2);

  final r = s * 0.105;
  // üst küme (altıgen dizilim)
  const colors = [
    Color(0xFF00D8F5),
    Color(0xFFFFB800),
    Color(0xFF10E56A),
    Color(0xFFA25CFF),
    Color(0xFFFF7A1A),
    Color(0xFF00D8F5),
    Color(0xFFA25CFF),
  ];
  final cluster = <Offset>[
    for (var i = 0; i < 4; i++) Offset(s * 0.5 + (i - 1.5) * r * 2, s * 0.17),
    for (var i = 0; i < 3; i++)
      Offset(s * 0.5 + (i - 1) * r * 2, s * 0.17 + r * 1.73),
  ];
  // patlama: sağ alt balonun yerinde
  final burst = cluster[6];
  canvas.drawPath(
    _star(burst, r * 1.9, r * 0.9, 9, 0.2),
    Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white,
          const Color(0xFFFFE07A),
          const Color(0x00FF4E7C),
        ],
        stops: const [0, 0.45, 1],
      ).createShader(Rect.fromCircle(center: burst, radius: r * 1.9)),
  );
  for (var i = 0; i < cluster.length - 1; i++) {
    drawBubble(canvas, cluster[i], r * 0.95, colors[i]);
  }
  // parçacıklar
  final rnd = Random(4);
  for (var i = 0; i < 9; i++) {
    final a = -0.45 + i * 2.0 / 8; // sadece sağa doğru saçılır
    final d = r * (1.9 + rnd.nextDouble() * 0.8);
    canvas.drawCircle(
      burst + Offset(cos(a), sin(a)) * d,
      r * (0.12 + rnd.nextDouble() * 0.12),
      Paint()..color = colors[i % colors.length],
    );
  }

  // atılan pembe balon ve iz
  final shot = Offset(s * 0.56, s * 0.53);
  final from = Offset(s * 0.5, s * 0.86);
  for (var i = 5; i >= 1; i--) {
    final t = i / 6;
    canvas.drawCircle(
      Offset.lerp(shot, from, t)!,
      r * (1.05 - t * 0.55),
      Paint()
        ..color = const Color(0xFFFF4E7C).withValues(alpha: 0.28 * (1 - t)),
    );
  }
  drawBubble(canvas, shot, r * 1.25, const Color(0xFFFF4E7C));
  // hız çizgileri
  final speed =
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..strokeWidth = s * 0.012
        ..strokeCap = StrokeCap.round;
  for (final dx in [-0.9, 0.0, 0.9]) {
    final a = shot + Offset(dx * r * 0.7, r * 1.55);
    canvas.drawLine(a, a + Offset(-r * 0.08, r * 0.55), speed);
  }

  // altın atıcı
  final base = Offset(s * 0.5, s * 0.93);
  final barrel = RRect.fromRectAndRadius(
    Rect.fromCenter(
      center: base + Offset(0, -r * 1.25),
      width: r * 1.15,
      height: r * 1.7,
    ),
    Radius.circular(r * 0.4),
  );
  final gold =
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFFF0A0), Color(0xFFFFB800), Color(0xFFB86E00)],
          stops: [0, 0.5, 1],
        ).createShader(barrel.outerRect);
  canvas.drawRRect(barrel, gold);
  canvas.drawArc(
    Rect.fromCircle(center: base, radius: r * 1.5),
    pi,
    pi,
    true,
    Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.3, -0.5),
        colors: [Color(0xFFFFF0A0), Color(0xFFFFB800), Color(0xFF9A5A00)],
      ).createShader(Rect.fromCircle(center: base, radius: r * 1.5)),
  );
  canvas.drawOval(
    Rect.fromCenter(
      center: base + Offset(-r * 0.45, -r * 0.85),
      width: r * 0.55,
      height: r * 0.28,
    ),
    Paint()..color = Colors.white.withValues(alpha: 0.55),
  );

  // yıldız parıltıları
  final sp = Paint()..color = Colors.white;
  for (final (x, y, z) in [
    (0.14, 0.42, 0.035),
    (0.86, 0.36, 0.028),
    (0.82, 0.70, 0.022),
    (0.2, 0.72, 0.018),
  ]) {
    canvas.drawPath(_star(Offset(s * x, s * y), s * z, s * z * 0.3, 4), sp);
  }
  canvas.restore();
}

void _background(Canvas canvas, double s) {
  final rect = Rect.fromLTWH(0, 0, s, s);
  canvas.drawRect(
    rect,
    Paint()
      ..shader = const RadialGradient(
        center: Alignment(0, 0.1),
        radius: 0.9,
        colors: [Color(0xFF8A3CF0), Color(0xFF3B1890), Color(0xFF150A3C)],
        stops: [0, 0.55, 1],
      ).createShader(rect),
  );
  // ışık huzmeleri
  final c = Offset(s * 0.56, s * 0.53);
  final ray = Paint()..color = Colors.white.withValues(alpha: 0.06);
  for (var i = 0; i < 12; i++) {
    final a = i * pi / 6;
    final p =
        Path()
          ..moveTo(c.dx, c.dy)
          ..lineTo(c.dx + cos(a - 0.11) * s, c.dy + sin(a - 0.11) * s)
          ..lineTo(c.dx + cos(a + 0.11) * s, c.dy + sin(a + 0.11) * s)
          ..close();
    canvas.drawPath(p, ray);
  }
}

Future<void> _save(
  String path,
  void Function(Canvas) draw, [
  int px = 1024,
]) async {
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  canvas.scale(px / _size);
  draw(canvas);
  final img = await rec.endRecording().toImage(px, px);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(data!.buffer.asUint8List());
}

void main() {
  test('ikon üret', () async {
    if (const String.fromEnvironment('ICON').isEmpty) return;
    void full(Canvas c) {
      _background(c, _size);
      _scene(c, _size, k: 0.96);
    }

    await _save('build/icon/full.png', full);
    await _save('build/icon/play_store_512.png', full, 512);
    // uyarlanabilir ikon: 108dp'nin ortadaki ~66dp'si güvenli alan
    await _save('build/icon/foreground.png', (c) => _scene(c, _size, k: 0.64));
    await _save('build/icon/background.png', (c) => _background(c, _size));
  });
}
