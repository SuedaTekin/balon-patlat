// Uygulama ikonunu oyunun kendi balon çizimiyle üretir.
// Çalıştırma: flutter test test/icon_gen_test.dart --dart-define=ICON=1
import 'dart:io';
import 'dart:ui' as ui;

import 'package:balon_patlat/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _size = 1024.0;

void _bubbles(Canvas canvas, double s, {double scale = 1}) {
  canvas.save();
  canvas.translate(s / 2, s / 2);
  canvas.scale(scale);
  canvas.translate(-s / 2, -s / 2);
  final r = s * 0.2;
  drawBubble(canvas, Offset(s * 0.30, s * 0.64), r, const Color(0xFF00D8F5));
  drawBubble(canvas, Offset(s * 0.70, s * 0.64), r, const Color(0xFFFFB800));
  drawBubble(
    canvas,
    Offset(s * 0.50, s * 0.33),
    r * 1.12,
    const Color(0xFFFF4E7C),
  );
  // küçük parıltılar
  final spark = Paint()..color = Colors.white.withValues(alpha: 0.9);
  for (final (x, y, rr) in [
    (0.16, 0.24, 0.022),
    (0.84, 0.22, 0.016),
    (0.86, 0.40, 0.012),
  ]) {
    canvas.drawCircle(Offset(s * x, s * y), s * rr, spark);
  }
  canvas.restore();
}

void _background(Canvas canvas, double s) {
  final rect = Rect.fromLTWH(0, 0, s, s);
  canvas.drawRect(
    rect,
    Paint()
      ..shader = const RadialGradient(
        center: Alignment(0, -0.2),
        radius: 0.85,
        colors: [Color(0xFF5B2BB8), Color(0xFF2A1466), Color(0xFF140A38)],
        stops: [0, 0.6, 1],
      ).createShader(rect),
  );
}

Future<void> _save(String path, void Function(Canvas) draw) async {
  final rec = ui.PictureRecorder();
  draw(Canvas(rec));
  final img = await rec.endRecording().toImage(_size.toInt(), _size.toInt());
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(data!.buffer.asUint8List());
}

void main() {
  test('ikon üret', () async {
    if (const String.fromEnvironment('ICON').isEmpty) return;
    await _save('build/icon/full.png', (c) {
      _background(c, _size);
      _bubbles(c, _size, scale: 0.92);
    });
    // uyarlanabilir ikon ön yüzü: 108dp'nin ortadaki 72dp'si güvenli alan
    await _save('build/icon/foreground.png', (c) {
      _bubbles(c, _size, scale: 0.62);
    });
    await _save('build/icon/background.png', (c) => _background(c, _size));
  });
}
