import 'package:flutter/material.dart';

import 'audio.dart';
import 'game.dart';
import 'game_screen.dart';
import 'progress.dart';
import 'theme.dart';
import 'widgets.dart';

/// Bölüm başında seçilen başlangıç güçlendiricileri.
class StartBoosters {
  const StartBoosters({
    this.bomb = false,
    this.rainbow = false,
    this.extraMoves = false,
  });
  final bool bomb, rainbow, extraMoves;
  bool get any => bomb || rainbow || extraMoves;
}

const startBombPrice = 250;
const startRainbowPrice = 200;
const startMovesPrice = 200;

/// Bölüm Detay penceresi: bölüm türü, hedef, rekor ve başlangıç
/// güçlendiricileri. OYNA'ya basılırsa seçimleri döndürür, kapatılırsa null.
Future<StartBoosters?> showLevelIntro(BuildContext context, int level) {
  return showDialog<StartBoosters>(
    context: context,
    barrierColor: const Color(0xD9070314),
    builder: (_) => _LevelIntro(level: level),
  );
}

/// Bölüm Detay'ı gösterir, onaylanırsa oyunu açar. [replace] true ise
/// mevcut ekranın yerine geçer (sonraki bölüm).
Future<void> startLevel(
  BuildContext context,
  int level, {
  bool replace = false,
}) async {
  if (!await ensureLife(context) || !context.mounted) return;
  final start = await showLevelIntro(context, level);
  if (start == null || !context.mounted) return;
  final route = MaterialPageRoute(
    builder: (_) => GameScreen(level: level, start: start),
  );
  if (replace) {
    await Navigator.of(context).pushReplacement(route);
  } else {
    await Navigator.of(context).push(route);
  }
}

class _LevelIntro extends StatefulWidget {
  const _LevelIntro({required this.level});
  final int level;

  @override
  State<_LevelIntro> createState() => _LevelIntroState();
}

class _LevelIntroState extends State<_LevelIntro> {
  bool bomb = false, rainbow = false, moves = false;

  bool get _ownRainbow => (Progress.boosters[Booster.rainbow] ?? 0) > 0;

  int get _cost =>
      (bomb ? startBombPrice : 0) +
      (rainbow && !_ownRainbow ? startRainbowPrice : 0) +
      (moves ? startMovesPrice : 0);

  bool _canToggle(int extra) => Progress.coins >= _cost + extra;

  void _play() {
    if (_cost > 0 && !Progress.spend(_cost)) return;
    if (rainbow && _ownRainbow) Progress.useBooster(Booster.rainbow);
    Progress.save();
    Navigator.pop(
      context,
      StartBoosters(bomb: bomb, rainbow: rainbow, extraMoves: moves),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cfg = LevelConfig.forLevel(widget.level);
    final kind = cfg.kind;
    final stars = Progress.stars[widget.level] ?? 0;
    final best = Progress.bestScores[widget.level];
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 30),
            padding: const EdgeInsets.fromLTRB(16, 46, 16, 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1040),
              borderRadius: BorderRadius.circular(36),
              border: Border.all(
                color: kindColor(kind).withValues(alpha: 0.6),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: kindColor(kind).withValues(alpha: 0.25),
                  blurRadius: 32,
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (kind != LevelKind.normal) _kindBanner(cfg),
                  _section(Icons.flag_rounded, 'HEDEF'),
                  _goals(cfg),
                  const SizedBox(height: 10),
                  _record(stars, best),
                  const SizedBox(height: 14),
                  _section(Icons.bolt_rounded, 'BAŞLANGIÇ GÜÇLENDİRİCİLERİ'),
                  Row(
                    children: [
                      Expanded(child: _bombCard()),
                      const SizedBox(width: 8),
                      Expanded(child: _rainbowCard()),
                      const SizedBox(width: 8),
                      Expanded(child: _movesCard()),
                    ],
                  ),
                  const SizedBox(height: 18),
                  JuicyButton.green(
                    height: 70,
                    onTap: _play,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.play_arrow_rounded,
                            color: Color(0xFF00361A),
                            size: 36,
                          ),
                          Text(
                            'OYNA!',
                            style: outfit(
                              28,
                              w: FontWeight.w900,
                              color: const Color(0xFF00361A),
                            ),
                          ),
                          if (!Progress.infinite) ...[
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF00361A,
                                ).withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.favorite_border_rounded,
                                    color: Color(0xFF00361A),
                                    size: 18,
                                  ),
                                  Text(
                                    ' -1',
                                    style: outfit(
                                      16,
                                      color: const Color(0xFF00361A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (_cost > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Başlangıç maliyeti: ',
                          style: jakarta(12, color: LP.muted),
                        ),
                        const CoinIcon(size: 16),
                        Text(' $_cost', style: outfit(13, color: LP.gold)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          // başlık
          Positioned(
            top: 0,
            left: 40,
            right: 40,
            child: Container(
              height: 60,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFE07A), LP.gold],
                ),
                boxShadow: const [
                  BoxShadow(color: Color(0xFF8A5A00), offset: Offset(0, 5)),
                ],
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'BÖLÜM ${widget.level}',
                  style: outfit(
                    30,
                    w: FontWeight.w900,
                    color: const Color(0xFF3D2400),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 34,
            right: -6,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: LP.surfaceHighest,
                ),
                child: const Icon(Icons.close_rounded, color: LP.onSurface),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kindBanner(LevelConfig cfg) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: kindColor(cfg.kind).withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      children: [
        Icon(Icons.local_fire_department_rounded, color: kindColor(cfg.kind)),
        const SizedBox(width: 6),
        Text(
          cfg.kind == LevelKind.hard ? 'ZOR BÖLÜM' : 'ÇOK ZOR BÖLÜM',
          style: outfit(17, w: FontWeight.w900, color: kindColor(cfg.kind)),
        ),
        const Spacer(),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              children: [
                Text('İlk galibiyet +', style: jakarta(12)),
                Text('${cfg.bonusCoins} ', style: outfit(13, color: LP.gold)),
                const CoinIcon(size: 16),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _section(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Icon(icon, size: 18, color: LP.gold),
        const SizedBox(width: 6),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(text, style: outfit(14, color: LP.muted, spacing: 1)),
          ),
        ),
      ],
    ),
  );

  Widget _chip(Widget icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: LP.bgDeep.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 6),
        Flexible(child: Text(text, style: jakarta(12))),
      ],
    ),
  );

  Widget _goals(LevelConfig cfg) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      _chip(
        const Icon(Icons.bubble_chart_rounded, color: LP.cyan, size: 20),
        'Tüm renkli balonları patlat',
      ),
      _chip(
        const Icon(Icons.palette_rounded, color: LP.pink, size: 20),
        '${cfg.colors} renk',
      ),
      if (cfg.stoneRatio > 0)
        _chip(
          const Icon(
            Icons.landscape_rounded,
            color: Color(0xFFB8B2A7),
            size: 20,
          ),
          'Taş balonlar',
        ),
      if (cfg.bombCount > 0)
        _chip(
          const Icon(
            Icons.flash_on_rounded,
            color: Color(0xFFFF4D4D),
            size: 20,
          ),
          '${cfg.bombCount} bomba balon',
        ),
      if (cfg.shotsPerRow > 0)
        _chip(
          const Icon(
            Icons.vertical_align_bottom_rounded,
            color: LP.gold,
            size: 20,
          ),
          '${cfg.shotsPerRow} ıskada yeni sıra',
        ),
    ],
  );

  Widget _record(int stars, int? best) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: LP.bgDeep.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        for (var i = 0; i < 3; i++)
          Icon(
            Icons.star_rounded,
            size: 26,
            color: i < stars ? LP.gold : LP.surfaceHighest,
          ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            best == null
                ? '3 yıldız için hamlelerinin %30\'u kalsın'
                : 'Rekorun: ${formatNum(best)} puan',
            style: jakarta(13, color: LP.onSurface),
          ),
        ),
      ],
    ),
  );

  Widget _card({
    required bool on,
    required Widget icon,
    required String title,
    required Widget price,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: () {
        if (onTap == null) {
          toastPrice(context);
          return;
        }
        Sfx.play('click');
        setState(onTap);
      },
      // altını yetmeyen güçlendirici soluk görünür
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: onTap == null ? 0.45 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.fromLTRB(6, 12, 6, 10),
          decoration: BoxDecoration(
            color:
                on
                    ? LP.cyan.withValues(alpha: 0.14)
                    : LP.bgDeep.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: on ? LP.cyan : LP.surfaceHighest,
              width: on ? 2.5 : 1.5,
            ),
          ),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  SizedBox(width: 50, height: 50, child: icon),
                  if (on)
                    const Positioned(
                      right: -8,
                      top: -8,
                      child: CircleAvatar(
                        radius: 11,
                        backgroundColor: LP.cyan,
                        child: Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: Color(0xFF00363D),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(title, style: outfit(14, w: FontWeight.w900)),
              ),
              const SizedBox(height: 2),
              FittedBox(fit: BoxFit.scaleDown, child: price),
            ],
          ),
        ),
      ),
    );
  }

  Widget _coinPrice(int p) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const CoinIcon(size: 15),
      Text(' $p', style: outfit(13, color: LP.gold)),
    ],
  );

  Widget _bombCard() => _card(
    on: bomb,
    icon: CustomPaint(painter: _BombIconPainter()),
    title: 'Bomba',
    price:
        bomb
            ? Text('Seçili', style: outfit(13, color: LP.cyan))
            : _coinPrice(startBombPrice),
    onTap: bomb || _canToggle(startBombPrice) ? () => bomb = !bomb : null,
  );

  Widget _rainbowCard() {
    final own = Progress.boosters[Booster.rainbow] ?? 0;
    return _card(
      on: rainbow,
      icon: const BoosterIcon(Booster.rainbow, size: 50),
      title: 'Gökkuşağı',
      price:
          rainbow
              ? Text('Seçili', style: outfit(13, color: LP.cyan))
              : own > 0
              ? Text('$own Adet', style: outfit(13, color: LP.muted))
              : _coinPrice(startRainbowPrice),
      onTap:
          rainbow || own > 0 || _canToggle(startRainbowPrice)
              ? () => rainbow = !rainbow
              : null,
    );
  }

  Widget _movesCard() => _card(
    on: moves,
    icon: Container(
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: LP.surfaceHighest,
      ),
      child: Text('+3', style: outfit(22, w: FontWeight.w900, color: LP.gold)),
    ),
    title: 'Ekstra Hamle',
    price:
        moves
            ? Text('Seçili', style: outfit(13, color: LP.cyan))
            : _coinPrice(startMovesPrice),
    onTap: moves || _canToggle(startMovesPrice) ? () => moves = !moves : null,
  );
}

void toastPrice(BuildContext context) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    const SnackBar(content: Text('Yeterli altının yok — mağazaya göz at!')),
  );
}

class _BombIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    GamePainter.drawBomb(
      canvas,
      Offset(size.width / 2, size.height / 2 + 3),
      size.width * 0.42,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
