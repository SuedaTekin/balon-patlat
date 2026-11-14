import 'package:flutter/material.dart';

import '../game.dart';
import '../theme.dart';

/// 0-2: Stitch karakter görselleri, 3-8: renkli balon + baş harf.
const avatarCount = 9;

const clanBadgeIcons = [
  Icons.star_rounded,
  Icons.shield_rounded,
  Icons.bolt_rounded,
  Icons.favorite_rounded,
  Icons.diamond_rounded,
  Icons.rocket_launch_rounded,
  Icons.pets_rounded,
  Icons.emoji_events_rounded,
];

class AvatarImage extends StatelessWidget {
  const AvatarImage(
    this.index, {
    super.key,
    this.size = 44,
    this.name = '',
    this.ring,
  });
  final int index;
  final double size;
  final String name;
  final Color? ring;

  @override
  Widget build(BuildContext context) {
    final i = index.clamp(0, avatarCount - 1);
    final Widget inner;
    if (i < 3) {
      inner = Image.asset(
        'assets/avatars/a$i.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
      );
    } else {
      final c = bubbleColors[(i - 3) % bubbleColors.length];
      inner = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.3, -0.4),
            colors: [
              Color.lerp(c, Colors.white, 0.45)!,
              c,
              Color.lerp(c, Colors.black, 0.4)!,
            ],
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          name.isEmpty ? '?' : name.characters.first.toUpperCase(),
          style: outfit(
            size * 0.45,
            w: FontWeight.w900,
            color: Colors.white,
            shadows: embossShadow,
          ),
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ring ?? LP.gold, width: size > 60 ? 4 : 2),
      ),
      child: ClipOval(child: inner),
    );
  }
}

class ClanBadge extends StatelessWidget {
  const ClanBadge(this.badge, {super.key, this.size = 56});
  final int badge;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = bubbleColors[badge % bubbleColors.length];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.4),
          colors: [Color.lerp(c, Colors.white, 0.4)!, c, LP.bgDeep],
          stops: const [0, 0.6, 1],
        ),
        border: Border.all(color: LP.gold, width: 2.5),
        boxShadow: [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 14)],
      ),
      child: Icon(
        clanBadgeIcons[badge % clanBadgeIcons.length],
        color: Colors.white,
        size: size * 0.5,
      ),
    );
  }
}
