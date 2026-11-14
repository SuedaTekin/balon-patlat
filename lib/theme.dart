import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'audio.dart';

/// "Luminous Pop" tasarım sistemi renkleri (Stitch DESIGN.md).
class LP {
  static const bg = Color(0xFF140D30);
  static const bgDeep = Color(0xFF070314);
  static const surface = Color(0xFF211A3D);
  static const surfaceHigh = Color(0xFF2B2548);
  static const surfaceHighest = Color(0xFF363054);
  static const onSurface = Color(0xFFE6DEFF);
  static const muted = Color(0xFFB4A9D6);
  static const ruby = Color(0xFFFF1E6C);
  static const rubyDeep = Color(0xFFE0004D);
  static const rubyLedge = Color(0xFF8E0032);
  static const pink = Color(0xFFFFB2BE);
  static const cyan = Color(0xFF00E5FF);
  static const cyanDeep = Color(0xFF00B8D4);
  static const cyanLedge = Color(0xFF00616D);
  static const gold = Color(0xFFFFB800);
  static const goldLight = Color(0xFFFFE07A);
  static const goldLedge = Color(0xFF8A5200);
  static const emerald = Color(0xFF10E56A);
  static const emeraldDeep = Color(0xFF05B04E);
  static const emeraldLedge = Color(0xFF056B30);
}

TextStyle outfit(
  double size, {
  FontWeight w = FontWeight.w800,
  Color color = LP.onSurface,
  double? spacing,
  List<Shadow>? shadows,
}) => GoogleFonts.outfit(
  fontSize: size,
  fontWeight: w,
  color: color,
  letterSpacing: spacing,
  shadows: shadows,
);

TextStyle jakarta(
  double size, {
  FontWeight w = FontWeight.w600,
  Color color = LP.onSurface,
}) => GoogleFonts.plusJakartaSans(fontSize: size, fontWeight: w, color: color);

/// Fiyat metni: Outfit yazı tipinde ₺ işareti olmadığı için para birimi
/// sembollerini sistem yazı tipiyle (Roboto) çizer.
class MoneyText extends StatelessWidget {
  const MoneyText(this.text, {super.key, required this.style, this.textAlign});
  final String text;
  final TextStyle style;
  final TextAlign? textAlign;

  static final _symbol = RegExp(r'[₺€\$£¥₹]');

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    var last = 0;
    for (final m in _symbol.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      spans.add(
        TextSpan(
          text: m.group(0),
          style: style.copyWith(
            fontFamily: 'Roboto',
            fontFamilyFallback: const ['sans-serif'],
          ),
        ),
      );
      last = m.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last)));
    }
    return Text.rich(
      TextSpan(style: style, children: spans),
      textAlign: textAlign,
    );
  }
}

const embossShadow = [Shadow(color: Color(0xFF1A0730), offset: Offset(0, 3))];

const bgGradient = BoxDecoration(
  gradient: RadialGradient(
    center: Alignment(0, -0.3),
    radius: 1.2,
    colors: [Color(0xFF241650), LP.bg, LP.bgDeep],
    stops: [0, 0.55, 1],
  ),
);

/// 4 katmanlı parlak balon: taban, alt gölge, yan ışık, üst-sol parlama.
void drawBubble(
  Canvas canvas,
  Offset c,
  double radius,
  Color color, {
  double opacity = 1,
  bool glow = true,
}) {
  final rect = Rect.fromCircle(center: c, radius: radius);
  if (glow) {
    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..color = color.withValues(alpha: 0.45 * opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.4),
    );
  }
  canvas.drawCircle(
    c,
    radius,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.35),
        radius: 0.95,
        colors: [
          Color.lerp(color, Colors.white, 0.5)!.withValues(alpha: opacity),
          color.withValues(alpha: opacity),
          Color.lerp(color, Colors.black, 0.42)!.withValues(alpha: opacity),
        ],
        stops: const [0, 0.5, 1],
      ).createShader(rect),
  );
  // alt hilal gölge
  canvas.drawCircle(
    c,
    radius,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          Colors.black.withValues(alpha: 0.22 * opacity),
        ],
        stops: const [0.55, 1],
      ).createShader(rect),
  );
  // üst-sol parlama hapı
  canvas.save();
  canvas.translate(c.dx - radius * 0.32, c.dy - radius * 0.4);
  canvas.rotate(-pi / 4);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset.zero,
        width: radius * 0.62,
        height: radius * 0.3,
      ),
      Radius.circular(radius),
    ),
    Paint()..color = Colors.white.withValues(alpha: 0.75 * opacity),
  );
  canvas.restore();
  // sağ-alt yumuşak ışık
  canvas.drawCircle(
    c + Offset(radius * 0.42, radius * 0.45),
    radius * 0.12,
    Paint()..color = Colors.white.withValues(alpha: 0.3 * opacity),
  );
}

/// Bastırınca 4px inen, alt kenarlı 3B hap buton.
class JuicyButton extends StatefulWidget {
  const JuicyButton({
    super.key,
    required this.child,
    required this.top,
    required this.bottom,
    required this.ledge,
    this.onTap,
    this.height = 64,
    this.radius = 999,
    this.padding = const EdgeInsets.symmetric(horizontal: 24),
  });

  final Widget child;
  final Color top, bottom, ledge;
  final VoidCallback? onTap;
  final double height, radius;
  final EdgeInsets padding;

  factory JuicyButton.green({
    required Widget child,
    VoidCallback? onTap,
    double height = 64,
  }) => JuicyButton(
    top: const Color(0xFF4DFF97),
    bottom: LP.emeraldDeep,
    ledge: LP.emeraldLedge,
    onTap: onTap,
    height: height,
    child: child,
  );

  factory JuicyButton.gold({
    required Widget child,
    VoidCallback? onTap,
    double height = 64,
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 24),
  }) => JuicyButton(
    top: LP.goldLight,
    bottom: LP.gold,
    ledge: LP.goldLedge,
    onTap: onTap,
    height: height,
    padding: padding,
    child: child,
  );

  factory JuicyButton.ruby({
    required Widget child,
    VoidCallback? onTap,
    double height = 64,
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 24),
  }) => JuicyButton(
    top: const Color(0xFFFF5C93),
    bottom: LP.rubyDeep,
    ledge: LP.rubyLedge,
    onTap: onTap,
    height: height,
    padding: padding,
    child: child,
  );

  factory JuicyButton.cyan({
    required Widget child,
    VoidCallback? onTap,
    double height = 64,
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 24),
  }) => JuicyButton(
    top: const Color(0xFF8CF5FF),
    bottom: LP.cyanDeep,
    ledge: LP.cyanLedge,
    onTap: onTap,
    height: height,
    padding: padding,
    child: child,
  );

  @override
  State<JuicyButton> createState() => _JuicyButtonState();
}

class _JuicyButtonState extends State<JuicyButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final lift = _down ? 2.0 : 6.0;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp:
            enabled
                ? (_) {
                  setState(() => _down = false);
                  Sfx.play('click');
                  widget.onTap!();
                }
                : null,
        onTapCancel: () => setState(() => _down = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 70),
          height: widget.height,
          margin: EdgeInsets.only(top: 6 - lift, bottom: lift),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [widget.top, widget.bottom],
            ),
            boxShadow: [
              BoxShadow(color: widget.ledge, offset: Offset(0, lift)),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                offset: Offset(0, lift + 4),
                blurRadius: 18,
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: 4,
                left: widget.height * 0.35,
                right: widget.height * 0.35,
                height: widget.height * 0.32,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: Colors.white.withValues(alpha: 0.28),
                  ),
                ),
              ),
              Padding(
                padding: widget.padding,
                child: Center(child: widget.child),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Altın kaynak kapsülü (ikon sola taşar).
class CoinPill extends StatelessWidget {
  const CoinPill({super.key, required this.coins});
  final int coins;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            margin: const EdgeInsets.only(left: 14),
            padding: const EdgeInsets.only(left: 26, right: 14),
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: LP.bgDeep.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: LP.gold.withValues(alpha: 0.5)),
            ),
            child: Text(formatNum(coins), style: outfit(17, color: LP.gold)),
          ),
          const Positioned(left: 0, top: 2, child: CoinIcon(size: 36)),
        ],
      ),
    );
  }
}

class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 28});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.3, -0.4),
          colors: [Color(0xFFFFF382), LP.gold, Color(0xFFC77700)],
        ),
        border: Border.all(color: const Color(0xFF8A5200), width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        '\$',
        style: outfit(
          size * 0.55,
          w: FontWeight.w900,
          color: const Color(0xFF6B3E00),
        ),
      ),
    );
  }
}

String formatNum(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}

/// Cam efektli koyu kart.
BoxDecoration glassCard({double radius = 28, Color? border}) => BoxDecoration(
  color: const Color(0xFF1E1040).withValues(alpha: 0.65),
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(
    color: border ?? Colors.white.withValues(alpha: 0.12),
    width: 1,
  ),
);
