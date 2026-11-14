import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'ads.dart';
import 'audio.dart';
import 'game.dart';
import 'progress.dart';
import 'theme.dart';

/// Bölüm türü rengi: normal camgöbeği, zor kırmızı, çok zor mor.
Color kindColor(LevelKind k) => switch (k) {
  LevelKind.normal => LP.cyan,
  LevelKind.hard => const Color(0xFFFF3D6E),
  LevelKind.superHard => const Color(0xFFB45CFF),
};

String boosterName(Booster b) => switch (b) {
  Booster.moves => '+5 Hamle',
  Booster.rainbow => 'Gökkuşağı',
  Booster.fire => 'Ateş Topu',
  Booster.laser => 'Lazer',
};

String boosterInfo(Booster b) => switch (b) {
  Booster.moves => 'Hemen 5 ek hamle verir.',
  Booster.rainbow => 'Değdiği balonların rengine dönüşür.',
  Booster.fire => 'Yolundaki tüm balonları yakarak geçer.',
  Booster.laser => 'Çarptığı sıranın tamamını yok eder.',
};

String fmtDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

class ModalCard extends StatelessWidget {
  const ModalCard({
    super.key,
    required this.title,
    required this.titleColor,
    required this.children,
  });
  final String title;
  final Color titleColor;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1040),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(
            color: titleColor.withValues(alpha: 0.6),
            width: 3,
          ),
          boxShadow: [
            BoxShadow(color: titleColor.withValues(alpha: 0.3), blurRadius: 32),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: outfit(
                    28,
                    w: FontWeight.w900,
                    color: titleColor,
                    shadows: embossShadow,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class BoosterIcon extends StatelessWidget {
  const BoosterIcon(this.b, {super.key, this.size = 50});
  final Booster b;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (Gradient g, Widget child) = switch (b) {
      Booster.moves => (
        const RadialGradient(
          center: Alignment(-0.3, -0.4),
          colors: [Color(0xFFFFF382), LP.gold, Color(0xFFC77700)],
        ),
        Text(
          '+5',
          style: outfit(
            size * 0.4,
            w: FontWeight.w900,
            color: const Color(0xFF3D2400),
          ),
        ),
      ),
      Booster.rainbow => (
        const SweepGradient(
          colors: [
            Color(0xFFFF4E7C),
            Color(0xFFFFB800),
            Color(0xFF10E56A),
            Color(0xFF00D8F5),
            Color(0xFFA25CFF),
            Color(0xFFFF4E7C),
          ],
        ),
        Icon(Icons.palette_rounded, color: Colors.white, size: size * 0.5),
      ),
      Booster.fire => (
        const RadialGradient(
          center: Alignment(-0.3, -0.4),
          colors: [Color(0xFFFF9A5C), Color(0xFFFF3D3D), LP.rubyLedge],
        ),
        Icon(
          Icons.local_fire_department_rounded,
          color: Colors.white,
          size: size * 0.55,
        ),
      ),
      Booster.laser => (
        const RadialGradient(
          center: Alignment(-0.3, -0.4),
          colors: [Color(0xFFB8FAFF), LP.cyan, LP.cyanLedge],
        ),
        Icon(
          Icons.navigation_rounded,
          color: const Color(0xFF00363D),
          size: size * 0.5,
        ),
      ),
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: g),
      alignment: Alignment.center,
      child: child,
    );
  }
}

class HeartIcon extends StatelessWidget {
  const HeartIcon({super.key, this.size = 28, this.infinite = false});
  final double size;
  final bool infinite;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: Alignment(-0.3, -0.4),
          colors: [Color(0xFFFF7FA8), LP.ruby, LP.rubyLedge],
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        infinite ? Icons.all_inclusive_rounded : Icons.favorite_rounded,
        color: Colors.white,
        size: size * 0.55,
      ),
    );
  }
}

/// Ödülün kalemlerini (altın, güçlendirici, sonsuz can) yan yana gösterir.
class RewardChips extends StatelessWidget {
  const RewardChips(this.r, {super.key, this.big = false});
  final Reward r;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final s = big ? 44.0 : 22.0;
    final ts = big ? 22.0 : 13.0;
    Widget chip(Widget icon, String text) => Container(
      padding: EdgeInsets.symmetric(
        horizontal: big ? 14 : 8,
        vertical: big ? 10 : 4,
      ),
      decoration: BoxDecoration(
        color: LP.bgDeep.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          SizedBox(width: big ? 8 : 4),
          Text(text, style: outfit(ts, w: FontWeight.w900)),
        ],
      ),
    );
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        if (r.coins > 0) chip(CoinIcon(size: s), '+${formatNum(r.coins)}'),
        for (final e in r.boosters.entries)
          chip(BoosterIcon(e.key, size: s), '${e.value}x'),
        if (r.infiniteMinutes > 0)
          chip(
            HeartIcon(size: s, infinite: true),
            r.infiniteMinutes >= 60
                ? '${r.infiniteMinutes ~/ 60} Saat'
                : '${r.infiniteMinutes} Dk',
          ),
        if (r.refillLives) chip(HeartIcon(size: s), 'Dolu Can'),
      ],
    );
  }
}

Future<void> showRewardDialog(
  BuildContext context,
  String title,
  Reward r, {
  String? subtitle,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: const Color(0xD9070314),
    builder:
        (ctx) => ModalCard(
          title: title,
          titleColor: LP.gold,
          children: [
            const Icon(Icons.redeem_rounded, color: LP.gold, size: 64),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: jakarta(14, color: LP.muted),
              ),
            ],
            const SizedBox(height: 14),
            RewardChips(r, big: true),
            const SizedBox(height: 20),
            JuicyButton.green(
              onTap: () => Navigator.pop(ctx),
              child: Text(
                'HARİKA!',
                style: outfit(
                  22,
                  w: FontWeight.w900,
                  color: const Color(0xFF053D1C),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
  );
}

/// Oynamak için can var mı? Yoksa "Canın kalmadı" penceresini açar.
Future<bool> ensureLife(BuildContext context) async {
  if (Progress.canPlay) return true;
  final ok = await showDialog<bool>(
    context: context,
    barrierColor: const Color(0xD9070314),
    builder: (_) => const LivesDialog(),
  );
  return ok == true && Progress.canPlay;
}

/// Can durumu: kalan süre, altınla doldurma.
/// "Reklam izle → ödül" düğmesi. Reklam hazır değilse soluk görünür ve
/// dokununca bilgi verir.
class AdButton extends StatefulWidget {
  const AdButton({super.key, required this.label, required this.onEarned});
  final String label;
  final VoidCallback onEarned;

  @override
  State<AdButton> createState() => _AdButtonState();
}

class _AdButtonState extends State<AdButton> {
  bool _busy = false;

  Future<void> _tap() async {
    if (_busy) return;
    if (!Ads.ready) {
      Ads.showRewarded(); // yüklemeyi tetikler
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Reklam hazırlanıyor, birazdan tekrar dene.'),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    Sfx.pauseMusic();
    final ok = await Ads.showRewarded();
    Sfx.resumeMusic();
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) widget.onEarned();
  }

  @override
  Widget build(BuildContext context) {
    final ready = Ads.ready && !_busy;
    return Opacity(
      opacity: ready ? 1 : 0.55,
      child: GestureDetector(
        onTap: _tap,
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: const LinearGradient(
              colors: [Color(0xFF7B3CFF), Color(0xFFB45CFF)],
            ),
            boxShadow: const [
              BoxShadow(color: Color(0xFF4A1FA0), offset: Offset(0, 4)),
            ],
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.smart_display_rounded,
                  color: Colors.white,
                  size: 26,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: outfit(17, w: FontWeight.w900, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LivesDialog extends StatefulWidget {
  const LivesDialog({super.key});

  @override
  State<LivesDialog> createState() => _LivesDialogState();
}

class _LivesDialogState extends State<LivesDialog> {
  late final Timer _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(
      const Duration(seconds: 1),
      (_) => mounted ? setState(() {}) : null,
    );
  }

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final next = Progress.nextLifeIn;
    final inf = Progress.infinite;
    final full = Progress.lives >= Progress.maxLives;
    return ModalCard(
      title: Progress.lives == 0 && !inf ? 'CANIN KALMADI!' : 'CANLAR',
      titleColor: LP.ruby,
      children: [
        Center(child: HeartIcon(size: 84, infinite: inf)),
        const SizedBox(height: 12),
        Text(
          inf
              ? 'Sonsuz can: ${fmtDuration(Progress.infiniteLeft)}'
              : '${Progress.lives} / ${Progress.maxLives} can',
          textAlign: TextAlign.center,
          style: outfit(24, w: FontWeight.w900),
        ),
        if (!inf && next != null)
          Text(
            'Sonraki can: ${fmtDuration(next)}',
            textAlign: TextAlign.center,
            style: jakarta(14, color: LP.pink),
          ),
        const SizedBox(height: 4),
        Text(
          'Her ${Progress.lifeRegen.inMinutes} dakikada 1 can dolar.',
          textAlign: TextAlign.center,
          style: jakarta(12, color: LP.muted),
        ),
        const SizedBox(height: 18),
        JuicyButton.gold(
          onTap:
              !full && !inf && Progress.coins >= Progress.refillPrice
                  ? () {
                    Progress.refillLives();
                    Navigator.pop(context, true);
                  }
                  : null,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'CANLARI DOLDUR  ',
                  style: outfit(
                    19,
                    w: FontWeight.w900,
                    color: const Color(0xFF3D2400),
                  ),
                ),
                const CoinIcon(size: 24),
                Text(
                  ' ${Progress.refillPrice}',
                  style: outfit(
                    19,
                    w: FontWeight.w900,
                    color: const Color(0xFF3D2400),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Altının: ${formatNum(Progress.coins)}',
          textAlign: TextAlign.center,
          style: jakarta(12, color: LP.muted),
        ),
        if (!full && !inf) ...[
          const SizedBox(height: 8),
          AdButton(
            label: 'ÜCRETSİZ +1 CAN',
            onEarned: () {
              Progress.lives = min(Progress.maxLives, Progress.lives + 1);
              Progress.save();
              Navigator.pop(context, true);
            },
          ),
        ],
        TextButton(
          onPressed: () => Navigator.pop(context, Progress.canPlay),
          child: Text('Kapat', style: outfit(16, color: LP.muted)),
        ),
      ],
    );
  }
}

/// Üst bardaki can kapsülü.
class LivesPill extends StatelessWidget {
  const LivesPill({super.key, this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final inf = Progress.infinite;
    final next = Progress.nextLifeIn;
    final text =
        inf
            ? fmtDuration(Progress.infiniteLeft)
            : next == null
            ? '${Progress.lives}/${Progress.maxLives}'
            : '${Progress.lives} · ${fmtDuration(next)}';
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 40,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              margin: const EdgeInsets.only(left: 14),
              padding: const EdgeInsets.only(left: 22, right: 12),
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: LP.bgDeep.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: LP.ruby.withValues(alpha: 0.5)),
              ),
              child: Text(text, style: outfit(14, color: LP.onSurface)),
            ),
            Positioned(
              left: 0,
              top: 2,
              child: HeartIcon(size: 36, infinite: inf),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simüle satın alma onayı (gerçek ödeme alınmaz).
Future<bool> confirmPurchase(
  BuildContext context,
  String item,
  String price,
) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierColor: const Color(0xD9070314),
    builder:
        (ctx) => ModalCard(
          title: 'SATIN AL',
          titleColor: LP.cyan,
          children: [
            Text(item, textAlign: TextAlign.center, style: outfit(20)),
            const SizedBox(height: 6),
            MoneyText(
              price,
              textAlign: TextAlign.center,
              style: outfit(30, w: FontWeight.w900, color: LP.gold),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: LP.cyan.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Test modu: Bu satın alma simülasyondur, gerçek ödeme alınmaz.',
                textAlign: TextAlign.center,
                style: jakarta(12, color: LP.cyan),
              ),
            ),
            const SizedBox(height: 16),
            JuicyButton.green(
              onTap: () => Navigator.pop(ctx, true),
              child: Text(
                'ONAYLA',
                style: outfit(
                  22,
                  w: FontWeight.w900,
                  color: const Color(0xFF053D1C),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Vazgeç', style: outfit(16, color: LP.muted)),
            ),
          ],
        ),
  );
  return ok == true;
}
