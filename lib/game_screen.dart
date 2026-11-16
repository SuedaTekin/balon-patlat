import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'audio.dart';
import 'game.dart';
import 'level_intro.dart';
import 'progress.dart';
import 'settings.dart';
import 'theme.dart';
import 'widgets.dart';

const _boosterKind = {
  Booster.rainbow: ShotKind.rainbow,
  Booster.fire: ShotKind.fire,
  Booster.laser: ShotKind.laser,
};
const _kindBooster = {
  ShotKind.rainbow: Booster.rainbow,
  ShotKind.fire: Booster.fire,
  ShotKind.laser: Booster.laser,
};

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.level,
    this.start = const StartBoosters(),
  });
  final int level;
  final StartBoosters start;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late final BubbleGame game;
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  bool _pointerAiming = false, _paused = false, _handledWin = false;
  bool _newBest = false, _lifeTaken = false;
  int _reward = 0;
  bool _lostSfx = false, _adContinueUsed = false, _adDoubled = false;
  bool _startApplied = false;
  final List<ShotKind> _startQueue = [];
  ShotKind? _prepaid;
  static int _open = 0;

  @override
  void initState() {
    super.initState();
    game = BubbleGame(LevelConfig.forLevel(widget.level));
    game.onPop = (n) => Sfx.haptic(n >= 6 ? 2 : 1);
    game.onSfx = (e) {
      if (e == 'bomb') Progress.addStat('bomb');
      if (e == 'pop') {
        Sfx.pop(game.combo);
      } else {
        Sfx.play(e, volume: e == 'bounce' ? 0.6 : 1);
      }
    };
    _open++;
    Sfx.playMusic('game');
    game.onShot = (popped, dropped, combo, colors) {
      Progress.addStat('pop', popped + dropped);
      if (dropped > 0) Progress.addStat('drop', dropped);
      if (combo >= 3) Progress.addStat('combo3');
      colors.forEach((c, n) => Progress.addStat('pop_c$c', n));
      Progress.save();
    };
    _ticker = createTicker(_tick)..start();
    _intro = _introFor(widget.level);
    if (_intro != null) {
      Future.delayed(const Duration(milliseconds: 2600), () {
        if (mounted) setState(() => _intro = null);
      });
    }
  }

  /// Bölüm başında gösterilen kısa tanıtım: yeni taş balon ya da zor bölüm.
  (String, String, Color)? _intro;

  static (String, String, Color)? _introFor(int level) {
    final cfg = LevelConfig.forLevel(level);
    if (level == 12) {
      return (
        'YENİ: BOMBA BALON',
        'Yanındaki bir balonu patlat, bomba çevresini havaya uçursun!',
        const Color(0xFFFF4D4D),
      );
    }
    if (level == 21) {
      return (
        'YENİ: TAŞ BALON',
        'Taşlar patlamaz! Altındakileri koparıp düşür ya da Ateş ve Lazer ile kır.',
        const Color(0xFF9AA3B5),
      );
    }
    return switch (cfg.kind) {
      LevelKind.hard => (
        'ZOR BÖLÜM',
        'Daha az hamle — ilk galibiyette +${cfg.bonusCoins} altın!',
        kindColor(cfg.kind),
      ),
      LevelKind.superHard => (
        'ÇOK ZOR BÖLÜM',
        'Sıralar hızlı iner — ilk galibiyette +${cfg.bonusCoins} altın!',
        kindColor(cfg.kind),
      ),
      LevelKind.normal => null,
    };
  }

  Widget _introBanner((String, String, Color) intro) {
    final (title, body, color) = intro;
    return Positioned(
      left: 24,
      right: 24,
      top: 120,
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutBack,
          builder:
              (context, k, child) => Transform.scale(scale: k, child: child),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: LP.bgDeep.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: color, width: 2),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 28),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  child: Text(
                    title,
                    style: outfit(24, w: FontWeight.w900, color: color),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: jakarta(13, color: LP.onSurface),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// En az bir atış yapıldıysa ve bölüm kazanılmadıysa bölümden çıkmak can yakar.
  bool get _wouldLoseLife =>
      !_lifeTaken &&
      game.state != GameState.won &&
      game.movesLeft < game.totalMoves &&
      !Progress.infinite;

  void _forfeit() {
    if (_wouldLoseLife) {
      Progress.loseLife();
      _lifeTaken = true;
    }
  }

  void _quit() {
    _forfeit();
    Navigator.pop(context);
  }

  Future<void> _retry() async {
    _forfeit();
    if (!await ensureLife(context)) {
      if (mounted) Navigator.pop(context);
      return;
    }
    setState(_restart);
  }

  Future<void> _next() async {
    if (widget.level >= maxLevel) {
      Navigator.pop(context);
      return;
    }
    await startLevel(context, widget.level + 1, replace: true);
  }

  /// Başlangıç güçlendiricilerini ilk karede uygular (ızgara o an kurulur).
  void _applyStart() {
    if (_startApplied || game.totalMoves == 0) return;
    _startApplied = true;
    final s = widget.start;
    if (s.extraMoves) {
      game.totalMoves += 3;
      game.addMoves(3);
    }
    if (s.bomb) _startQueue.add(ShotKind.bomb);
    if (s.rainbow) _startQueue.add(ShotKind.rainbow);
    _armNextStart();
  }

  void _armNextStart() {
    if (_startQueue.isEmpty) {
      _prepaid = null;
      return;
    }
    _prepaid = _startQueue.removeAt(0);
    game.armed = _prepaid!;
  }

  void _onBack() {
    switch (game.state) {
      case GameState.won:
        Navigator.pop(context);
      case GameState.lostMoves || GameState.lostDanger:
        _quit();
      case GameState.playing:
        _pause();
    }
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (!_paused) game.update(dt);
    _applyStart();
    if (game.state == GameState.won && !_handledWin) {
      _handledWin = true;
      final prev = Progress.bestScores[widget.level];
      _newBest = prev != null && game.score > prev;
      _reward = Progress.recordWin(widget.level, game.stars, game.score);
      Sfx.haptic(3);
      Sfx.play('win');
      for (var i = 0; i < game.stars; i++) {
        Future.delayed(Duration(milliseconds: 700 + i * 260), () {
          if (mounted) Sfx.play('star');
        });
      }
    }
    final lost =
        game.state == GameState.lostMoves || game.state == GameState.lostDanger;
    if (lost && !_lostSfx) Sfx.play('lose');
    _lostSfx = lost;
    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    // sonraki bölüme geçerken yeni ekran önce açılır; müzik oyunda kalsın
    if (--_open == 0) Sfx.playMusic('menu');
    super.dispose();
  }

  void _restart() {
    game.restart();
    _handledWin = false;
    _newBest = false;
    _lifeTaken = false;
    _adContinueUsed = false;
    _adDoubled = false;
    // başlangıç güçlendiricileri tek seferliktir; yeniden başlamada gelmez
    _startQueue.clear();
    _prepaid = null;
  }

  // ---------------- kullanıcı girişi ----------------
  void _onDown(PointerDownEvent e) {
    if ((e.localPosition - game.nextPos).distance < game.r * 1.8) {
      game.swap();
      Sfx.haptic(0);
      return;
    }
    _pointerAiming = true;
    game.aiming = true;
    game.aimAt(e.localPosition);
  }

  void _onUp(PointerUpEvent e) {
    if (!_pointerAiming) return;
    _pointerAiming = false;
    game.aiming = false;
    final kind = game.fire();
    if (kind == null) return;
    if (_prepaid != null && kind == _prepaid) {
      // başlangıçta ödendi; sıradakini kur
      _armNextStart();
      return;
    }
    final b = _kindBooster[kind];
    if (b != null) Progress.useBooster(b);
  }

  Future<void> _onBooster(Booster b) async {
    if (game.state != GameState.playing || game.ballPos != null) return;
    if (_prepaid != null && game.armed == _prepaid) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Önce başlangıç güçlendiricini at!'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    if (Progress.boosters[b]! <= 0) {
      await _buyDialog(b);
      return;
    }
    Sfx.haptic(0);
    if (b == Booster.moves) {
      Progress.useBooster(b);
      game.addMoves(5);
      return;
    }
    final kind = _boosterKind[b]!;
    game.armed = game.armed == kind ? ShotKind.normal : kind;
  }

  Future<void> _buyDialog(Booster b) async {
    _paused = true;
    await showDialog<void>(
      context: context,
      barrierColor: const Color(0xD9070314),
      builder:
          (ctx) => ModalCard(
            title: boosterName(b).toUpperCase(),
            titleColor: LP.cyan,
            children: [
              SizedBox(height: 70, width: 70, child: BoosterIcon(b, size: 70)),
              const SizedBox(height: 12),
              Text(
                boosterInfo(b),
                textAlign: TextAlign.center,
                style: jakarta(15),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Altının: ', style: jakarta(13, color: LP.muted)),
                  Text(
                    formatNum(Progress.coins),
                    style: outfit(14, color: LP.gold),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              JuicyButton.gold(
                onTap:
                    Progress.coins >= Progress.boosterPrice
                        ? () {
                          Progress.buyBooster(b);
                          Navigator.pop(ctx);
                        }
                        : null,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'SATIN AL  ',
                      style: outfit(
                        20,
                        w: FontWeight.w900,
                        color: const Color(0xFF3D2400),
                      ),
                    ),
                    const CoinIcon(size: 26),
                    Text(
                      ' ${Progress.boosterPrice}',
                      style: outfit(
                        20,
                        w: FontWeight.w900,
                        color: const Color(0xFF3D2400),
                      ),
                    ),
                  ],
                ),
              ),
              if (Progress.coins < Progress.boosterPrice)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Yeterli altın yok — bölüm kazanarak topla!',
                    style: jakarta(13, color: LP.pink),
                  ),
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Vazgeç', style: outfit(16, color: LP.muted)),
              ),
            ],
          ),
    );
    _paused = false;
  }

  Future<void> _pause() async {
    _paused = true;
    await showDialog<void>(
      context: context,
      barrierColor: const Color(0xD9070314),
      builder:
          (ctx) => ModalCard(
            title: 'DURAKLATILDI',
            titleColor: LP.cyan,
            children: [
              JuicyButton.cyan(
                onTap: () => Navigator.pop(ctx),
                child: Text(
                  'DEVAM ET',
                  style: outfit(
                    20,
                    w: FontWeight.w900,
                    color: const Color(0xFF00363D),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              JuicyButton.gold(
                onTap: () {
                  Navigator.pop(ctx);
                  _retry();
                },
                child: Text(
                  'YENİDEN BAŞLA',
                  style: outfit(
                    20,
                    w: FontWeight.w900,
                    color: const Color(0xFF3D2400),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              JuicyButton.ruby(
                onTap: () {
                  Navigator.pop(ctx);
                  _quit();
                },
                child: Text(
                  'HARİTAYA DÖN',
                  style: outfit(20, w: FontWeight.w900, color: Colors.white),
                ),
              ),
              TextButton.icon(
                onPressed: () => showSettings(ctx),
                icon: const Icon(Icons.settings_rounded, color: LP.muted),
                label: Text('Ayarlar', style: outfit(15, color: LP.muted)),
              ),
              if (_wouldLoseLife) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.heart_broken_rounded,
                      color: LP.pink,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Çıkarsan veya baştan başlarsan 1 can gider',
                        style: jakarta(12, color: LP.pink),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 6),
            ],
          ),
    );
    _paused = false;
  }

  // ---------------- arayüz ----------------
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: _scaffold(),
    );
  }

  Widget _scaffold() {
    return Scaffold(
      body: Container(
        decoration: bgGradient,
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [_hud(), Expanded(child: _field()), _boosterRow()],
              ),
              if (_intro != null && game.state == GameState.playing)
                _introBanner(_intro!),
              if (game.state == GameState.won) _victory(),
              if (game.state == GameState.lostMoves ||
                  game.state == GameState.lostDanger)
                _defeat(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hud() {
    final low = game.movesLeft <= 5;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      padding: const EdgeInsets.all(10),
      decoration: glassCard(radius: 30),
      child: Row(
        children: [
          GestureDetector(
            onTap: _pause,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: LP.surfaceHighest,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Color(0xFF0F082B), offset: Offset(0, 4)),
                ],
              ),
              child: const Icon(
                Icons.pause_rounded,
                color: LP.onSurface,
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
            decoration: BoxDecoration(
              color: LP.bgDeep.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kindColor(game.cfg.kind),
                  ),
                  child: Icon(
                    game.cfg.kind == LevelKind.normal
                        ? Icons.flag_rounded
                        : Icons.local_fire_department_rounded,
                    color:
                        game.cfg.kind == LevelKind.normal
                            ? const Color(0xFF00363D)
                            : Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(switch (game.cfg.kind) {
                      LevelKind.normal => 'SEVİYE',
                      LevelKind.hard => 'ZOR',
                      LevelKind.superHard => 'ÇOK ZOR',
                    }, style: outfit(11, color: LP.muted, spacing: 1)),
                    Text(
                      '${widget.level}',
                      style: outfit(
                        20,
                        w: FontWeight.w900,
                        color: kindColor(game.cfg.kind),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Skor: ',
                        style: outfit(14, w: FontWeight.w700),
                      ),
                      TextSpan(
                        text: formatNum(game.score),
                        style: outfit(15, color: LP.gold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    height: 10,
                    color: LP.bgDeep,
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: max(0.02, game.cleared),
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [LP.gold, Color(0xFFFF5C93)],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  game.cfg.shotsPerRow > 0
                      ? 'Yeni sıra: ${game.shotsUntilRow} atış'
                      : 'Tüm balonları temizle!',
                  style: jakarta(10.5, color: LP.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.3, -0.4),
                colors:
                    low
                        ? const [Color(0xFFFF7FA8), LP.ruby, LP.rubyLedge]
                        : const [Color(0xFFFF5C93), LP.rubyDeep, LP.rubyLedge],
              ),
              boxShadow: [
                BoxShadow(
                  color: LP.ruby.withValues(alpha: low ? 0.8 : 0.35),
                  blurRadius: low ? 22 : 12,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'HAMLE',
                  style: outfit(10, color: Colors.white70, spacing: 1),
                ),
                Text(
                  '${game.movesLeft}',
                  style: outfit(
                    26,
                    w: FontWeight.w900,
                    color: Colors.white,
                    shadows: embossShadow,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _field() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: glassCard(radius: 32),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: LayoutBuilder(
          builder: (context, c) {
            game.layout(Size(c.maxWidth, c.maxHeight));
            return Stack(
              children: [
                Listener(
                  onPointerDown: _onDown,
                  onPointerMove: (e) {
                    if (_pointerAiming) game.aimAt(e.localPosition);
                  },
                  onPointerUp: _onUp,
                  onPointerCancel: (_) {
                    _pointerAiming = false;
                    game.aiming = false;
                  },
                  child: CustomPaint(
                    size: Size(c.maxWidth, c.maxHeight),
                    painter: GamePainter(game),
                  ),
                ),
                if (game.comboText != null)
                  Positioned(
                    top: 6,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: Center(
                        child: Opacity(
                          opacity: game.comboTimer.clamp(0.0, 1.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              gradient: const LinearGradient(
                                colors: [LP.gold, LP.cyan],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: LP.gold.withValues(alpha: 0.5),
                                  blurRadius: 18,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.bolt_rounded,
                                  color: Color(0xFF3D2400),
                                  size: 20,
                                ),
                                Text(
                                  game.comboText!,
                                  style: outfit(
                                    16,
                                    w: FontWeight.w900,
                                    color: const Color(0xFF3D2400),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _boosterRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 10),
      child: Row(
        children: [
          for (final b in Booster.values) Expanded(child: _boosterChip(b)),
        ],
      ),
    );
  }

  Widget _boosterChip(Booster b) {
    final count = Progress.boosters[b]!;
    final armed = _boosterKind[b] != null && game.armed == _boosterKind[b];
    return GestureDetector(
      onTap: () => _onBooster(b),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: armed ? const Color(0xFF15405A) : LP.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: armed ? LP.cyan : Colors.white.withValues(alpha: 0.08),
                width: armed ? 2 : 1,
              ),
              boxShadow: [
                const BoxShadow(color: Color(0xFF0F082B), offset: Offset(0, 4)),
                if (armed)
                  BoxShadow(
                    color: LP.cyan.withValues(alpha: 0.5),
                    blurRadius: 16,
                  ),
              ],
            ),
            child: Column(
              children: [
                SizedBox(width: 50, height: 50, child: BoosterIcon(b)),
                const SizedBox(height: 6),
                FittedBox(
                  child: Text(
                    boosterName(b),
                    style: jakarta(12, color: LP.onSurface),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 0,
            top: -6,
            child: Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: count > 0 ? LP.cyan : LP.gold,
                border: Border.all(color: LP.bg, width: 2),
              ),
              child:
                  count > 0
                      ? Text(
                        '$count',
                        style: outfit(
                          12,
                          w: FontWeight.w900,
                          color: const Color(0xFF00363D),
                        ),
                      )
                      : const Icon(
                        Icons.add_rounded,
                        size: 16,
                        color: Color(0xFF3D2400),
                      ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- bitiş ekranları ----------------
  Widget _victory() {
    final s = game.stars;
    return _Backdrop(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Ribbon(
            text: 'SEVİYE ${widget.level}\nTAMAMLANDI!',
            colors: const [LP.goldLight, LP.gold],
            ledge: LP.goldLedge,
            textColor: const Color(0xFF3D2400),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _StarBall(on: s >= 1, size: 70),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: _StarBall(on: s >= 2, size: 92),
              ),
              const SizedBox(width: 8),
              _StarBall(on: s >= 3, size: 70),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
            decoration: BoxDecoration(
              color: LP.bgDeep.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.military_tech_rounded,
                  color: LP.gold,
                  size: 30,
                ),
                const SizedBox(width: 8),
                Text(
                  formatNum(game.score),
                  style: outfit(36, w: FontWeight.w900),
                ),
                const SizedBox(width: 8),
                Text('PUAN', style: outfit(16, color: LP.pink)),
              ],
            ),
          ),
          if (_newBest) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: LP.ruby,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: LP.ruby.withValues(alpha: 0.6),
                    blurRadius: 14,
                  ),
                ],
              ),
              child: Text(
                '⚡ YENİ BÖLÜM REKORU!',
                style: outfit(14, color: Colors.white, spacing: 1),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Text(
            'KAZANILAN ÖDÜL',
            style: outfit(13, color: LP.pink, spacing: 1.5),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CoinIcon(size: 40),
              const SizedBox(width: 10),
              Text('+$_reward', style: outfit(28, w: FontWeight.w900)),
              const SizedBox(width: 6),
              Text('Altın', style: jakarta(14, color: LP.muted)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.workspace_premium_rounded,
                color: LP.gold,
                size: 18,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  '+${Progress.lastPassXp} Bilet XP · Kademe ${Progress.passTier}',
                  style: outfit(13, color: LP.gold),
                ),
              ),
            ],
          ),
          if (!_adDoubled && _reward > 0) ...[
            const SizedBox(height: 10),
            AdButton(
              label: 'ALTINI 2 KATINA ÇIKAR',
              onEarned: () {
                Progress.coins += _reward;
                Progress.save();
                Sfx.play('coin');
                setState(() {
                  _reward *= 2;
                  _adDoubled = true;
                });
              },
            ),
          ],
          const SizedBox(height: 20),
          JuicyButton.green(
            onTap: _next,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.level >= maxLevel
                        ? 'HARİTAYA DÖN'
                        : 'SONRAKİ SEVİYE',
                    style: outfit(
                      24,
                      w: FontWeight.w900,
                      color: const Color(0xFF053D1C),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.play_circle_fill_rounded,
                    color: Color(0xFF053D1C),
                    size: 30,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _textButtons(),
        ],
      ),
    );
  }

  Widget _defeat() {
    final danger = game.state == GameState.lostDanger;
    final pct = (game.cleared * 100).round();
    final price = danger ? Progress.rescuePrice : Progress.extraMovesPrice;
    return _Backdrop(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Ribbon(
            text: danger ? 'TEHLİKE ÇİZGİSİ!' : 'HAMLELER BİTTİ!',
            colors: const [Color(0xFFFF8FB0), Color(0xFFFF4E7C)],
            ledge: LP.rubyLedge,
            textColor: const Color(0xFF4A0018),
          ),
          const SizedBox(height: 14),
          const SizedBox(
            width: 130,
            height: 130,
            child: CustomPaint(painter: _SadBubble()),
          ),
          const SizedBox(height: 6),
          Text('Seviye ${widget.level}', style: outfit(20, color: LP.muted)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: LP.bgDeep.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Flexible(
                      child: FittedBox(
                        child: Text('Bölüm İlerlemesi', style: outfit(14)),
                      ),
                    ),
                    const Spacer(),
                    Flexible(
                      child: FittedBox(
                        child: Text(
                          '%$pct TEMİZLENDİ',
                          style: outfit(14, color: LP.gold),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    height: 14,
                    color: LP.surfaceHighest,
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: max(0.03, game.cleared),
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [LP.gold, LP.emerald, LP.cyan],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  pct >= 70
                      ? 'Hedefe çok yaklaştın! Pes etme.'
                      : 'Biraz daha dene, yapabilirsin!',
                  textAlign: TextAlign.center,
                  style: jakarta(13, color: LP.pink),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          JuicyButton.gold(
            height: 76,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            onTap:
                Progress.coins >= price
                    ? () {
                      Progress.spend(price);
                      Sfx.haptic(2);
                      Sfx.play('coin');
                      if (danger) {
                        game.rescue();
                      } else {
                        game.addMoves(5);
                      }
                    }
                    : null,
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF3D2400).withValues(alpha: 0.15),
                  ),
                  alignment: Alignment.center,
                  child:
                      danger
                          ? const Icon(
                            Icons.auto_fix_high_rounded,
                            color: Color(0xFF3D2400),
                            size: 28,
                          )
                          : Text(
                            '+5',
                            style: outfit(
                              24,
                              w: FontWeight.w900,
                              color: const Color(0xFF3D2400),
                            ),
                          ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          danger ? 'KURTAR' : 'EK HAMLE',
                          style: outfit(
                            22,
                            w: FontWeight.w900,
                            color: const Color(0xFF3D2400),
                          ),
                        ),
                        Text(
                          danger
                              ? 'Alt sıralar patlar, devam et'
                              : '5 hamle daha oyna',
                          style: jakarta(12, color: const Color(0xFF5E4200)),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3D2400).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '$price ',
                        style: outfit(
                          20,
                          w: FontWeight.w900,
                          color: const Color(0xFF3D2400),
                        ),
                      ),
                      const CoinIcon(size: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Altının: ${formatNum(Progress.coins)}',
            style: jakarta(12, color: LP.muted),
          ),
          if (!_adContinueUsed) ...[
            const SizedBox(height: 10),
            AdButton(
              label: danger ? 'ÜCRETSİZ KURTAR' : 'ÜCRETSİZ +5 HAMLE',
              onEarned: () {
                setState(() => _adContinueUsed = true);
                if (danger) {
                  game.rescue();
                } else {
                  game.addMoves(5);
                }
              },
            ),
          ],
          if (_wouldLoseLife) ...[
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: LP.rubyLedge.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.heart_broken_rounded,
                      color: LP.pink,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Çıkarsan 1 Can Kaybedilecek',
                      style: outfit(13, color: LP.pink),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ghostButton(Icons.close_rounded, 'Pes Et', _quit),
                const SizedBox(width: 10),
                _ghostButton(Icons.refresh_rounded, 'Yeniden Oyna', _retry),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _textButtons() => FittedBox(
    fit: BoxFit.scaleDown,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ghostButton(Icons.refresh_rounded, 'Tekrar Oyna', _restart),
        const SizedBox(width: 10),
        _ghostButton(Icons.map_rounded, 'Harita', () => Navigator.pop(context)),
      ],
    ),
  );

  Widget _ghostButton(IconData icon, String text, void Function() onTap) {
    return GestureDetector(
      onTap:
          () => setState(() {
            onTap();
          }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: LP.surfaceHighest.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            Icon(icon, color: LP.onSurface, size: 22),
            const SizedBox(width: 6),
            Text(text, style: outfit(17, w: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

// =================== yardımcı widget'lar ===================

class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: const Color(0xD9070314),
        alignment: Alignment.center,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1040).withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(44),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 1.5,
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _Ribbon extends StatelessWidget {
  const _Ribbon({
    required this.text,
    required this.colors,
    required this.ledge,
    required this.textColor,
  });
  final String text;
  final List<Color> colors;
  final Color ledge, textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
        boxShadow: [
          BoxShadow(color: ledge, offset: const Offset(0, 6)),
          BoxShadow(color: colors.last.withValues(alpha: 0.5), blurRadius: 30),
        ],
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: outfit(28, w: FontWeight.w900, color: textColor),
      ),
    );
  }
}

class _StarBall extends StatelessWidget {
  const _StarBall({required this.on, required this.size});
  final bool on;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.4),
          colors:
              on
                  ? const [Color(0xFFFFF382), LP.gold, Color(0xFFC77700)]
                  : const [LP.surfaceHighest, LP.surfaceHigh, LP.surface],
        ),
        boxShadow:
            on
                ? [
                  BoxShadow(
                    color: LP.gold.withValues(alpha: 0.6),
                    blurRadius: 24,
                  ),
                ]
                : null,
      ),
      child: Icon(
        Icons.star_rounded,
        size: size * 0.62,
        color: on ? const Color(0xFF6B3E00) : LP.bgDeep.withValues(alpha: 0.5),
      ),
    );
  }
}

class _SadBubble extends CustomPainter {
  const _SadBubble();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width * 0.45;
    drawBubble(canvas, c, r, const Color(0xFFFF6E98));
    final dark = Paint()..color = const Color(0xFF2A0A1C);
    final white = Paint()..color = Colors.white;
    for (final dx in [-r * 0.32, r * 0.32]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: c + Offset(dx, -r * 0.05),
          width: r * 0.3,
          height: r * 0.24,
        ),
        white,
      );
      canvas.drawCircle(c + Offset(dx, -r * 0.02), r * 0.08, dark);
    }
    final mouth =
        Path()
          ..moveTo(c.dx - r * 0.22, c.dy + r * 0.38)
          ..quadraticBezierTo(
            c.dx,
            c.dy + r * 0.16,
            c.dx + r * 0.22,
            c.dy + r * 0.38,
          );
    canvas.drawPath(
      mouth,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.08
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF2A0A1C),
    );
    // gözyaşı
    canvas.drawOval(
      Rect.fromCenter(
        center: c + Offset(-r * 0.42, r * 0.22),
        width: r * 0.13,
        height: r * 0.2,
      ),
      Paint()..color = const Color(0xFF7FE8FF),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// =================== oyun alanı çizimi ===================

class GamePainter extends CustomPainter {
  GamePainter(this.g);
  final BubbleGame g;

  static void _icon(
    Canvas canvas,
    IconData icon,
    Offset c,
    double size,
    Color color,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: size,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  /// Taş balon: gri, çatlaklı, parlamasız.
  static void drawStone(Canvas canvas, Offset c, double radius) {
    final rect = Rect.fromCircle(center: c, radius: radius);
    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.4),
          colors: [Color(0xFFB8B2A7), Color(0xFF7A746B), Color(0xFF45403A)],
          stops: [0, 0.6, 1],
        ).createShader(rect),
    );
    // kayaç yüzeyleri: köşeli parçalar, sol üst açık, sağ alt koyu
    canvas.save();
    canvas.clipPath(Path()..addOval(rect));
    Offset at(double x, double y) => c + Offset(x * radius, y * radius);
    void facet(List<Offset> pts, Color color) {
      final p = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final o in pts.skip(1)) {
        p.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(p..close(), Paint()..color = color);
    }

    facet([
      at(-1, -1),
      at(0.15, -1),
      at(-0.05, -0.2),
      at(-1, 0.05),
    ], const Color(0x30FFFFFF));
    facet([
      at(0.15, -1),
      at(1, -0.55),
      at(0.55, 0.05),
      at(-0.05, -0.2),
    ], const Color(0x14FFFFFF));
    facet([
      at(-1, 0.05),
      at(-0.05, -0.2),
      at(0.1, 0.55),
      at(-0.6, 1),
    ], const Color(0x18000000));
    facet([
      at(-0.05, -0.2),
      at(0.55, 0.05),
      at(1, 0.6),
      at(0.1, 0.55),
    ], const Color(0x2A000000));
    facet([
      at(0.1, 0.55),
      at(1, 0.6),
      at(0.6, 1),
      at(-0.6, 1),
    ], const Color(0x40000000));
    // facet kenarları
    final edge =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.05
          ..color = const Color(0x55262A36);
    canvas.drawPath(
      Path()
        ..moveTo(at(0.15, -1).dx, at(0.15, -1).dy)
        ..lineTo(at(-0.05, -0.2).dx, at(-0.05, -0.2).dy)
        ..lineTo(at(0.1, 0.55).dx, at(0.1, 0.55).dy)
        ..moveTo(at(-1, 0.05).dx, at(-1, 0.05).dy)
        ..lineTo(at(-0.05, -0.2).dx, at(-0.05, -0.2).dy)
        ..lineTo(at(0.55, 0.05).dx, at(0.55, 0.05).dy)
        ..lineTo(at(1, 0.6).dx, at(1, 0.6).dy),
      edge,
    );
    // küçük çukurlar
    final pit = Paint()..color = const Color(0x55262A36);
    for (final (x, y, s) in [
      (-0.5, 0.45, 0.09),
      (0.45, -0.4, 0.07),
      (0.55, 0.45, 0.06),
      (-0.3, -0.55, 0.05),
    ]) {
      canvas.drawCircle(at(x, y), radius * s, pit);
      canvas.drawCircle(
        at(x - s * 0.4, y - s * 0.4),
        radius * s * 0.5,
        Paint()..color = const Color(0x22FFFFFF),
      );
    }
    canvas.restore();
    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.1
        ..color = const Color(0xFF2B2F3D),
    );
    // üst parlama (cilasız taş: küçük ve mat)
    canvas.drawOval(
      Rect.fromCenter(
        center: at(-0.42, -0.5),
        width: radius * 0.36,
        height: radius * 0.18,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.28),
    );
  }

  /// Bomba balon: parlak siyah gövde, fitil ve kıvılcım, kırmızı halka.
  static void drawBomb(Canvas canvas, Offset c, double radius, [double t = 0]) {
    canvas.drawCircle(
      c,
      radius * 1.08,
      Paint()
        ..color = const Color(
          0xFFFF3D3D,
        ).withValues(alpha: 0.35 + 0.25 * sin(t * 8))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.35),
    );
    drawBubble(canvas, c, radius, const Color(0xFF2E2A3E), glow: false);
    canvas.drawCircle(
      c,
      radius * 0.97,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.1
        ..color = const Color(0xFFFF4D4D),
    );
    // fitil
    final top = c + Offset(radius * 0.35, -radius * 0.8);
    canvas.drawPath(
      Path()
        ..moveTo(top.dx, top.dy)
        ..quadraticBezierTo(
          top.dx + radius * 0.35,
          top.dy - radius * 0.35,
          top.dx + radius * 0.15,
          top.dy - radius * 0.55,
        ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.12
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFD9B98A),
    );
    final spark = top + Offset(radius * 0.15, -radius * 0.55);
    final flick = 0.8 + 0.2 * sin(t * 23);
    canvas.drawCircle(
      spark,
      radius * 0.28 * flick,
      Paint()..color = const Color(0xFFFFB800).withValues(alpha: 0.7),
    );
    canvas.drawCircle(spark, radius * 0.12, Paint()..color = Colors.white);
    _icon(
      canvas,
      Icons.flash_on_rounded,
      c,
      radius * 1.0,
      const Color(0xFFFF6B6B),
    );
  }

  static void drawShot(
    Canvas canvas,
    Offset c,
    double radius,
    ShotKind kind,
    int color,
  ) {
    switch (kind) {
      case ShotKind.normal:
        drawBubble(canvas, c, radius, bubbleColors[color]);
      case ShotKind.rainbow:
        canvas.drawCircle(
          c,
          radius,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.4)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.5),
        );
        canvas.drawCircle(
          c,
          radius,
          Paint()
            ..shader = SweepGradient(
              colors: [...bubbleColors, bubbleColors.first],
            ).createShader(Rect.fromCircle(center: c, radius: radius)),
        );
        drawBubble(canvas, c, radius, Colors.white, opacity: 0.25, glow: false);
      case ShotKind.fire:
        drawBubble(canvas, c, radius, const Color(0xFFFF4D2E));
        _icon(
          canvas,
          Icons.local_fire_department_rounded,
          c,
          radius * 1.2,
          const Color(0xFFFFE07A),
        );
      case ShotKind.laser:
        drawBubble(canvas, c, radius, LP.cyan);
        _icon(
          canvas,
          Icons.gps_fixed_rounded,
          c,
          radius * 1.1,
          const Color(0xFF00363D),
        );
      case ShotKind.bomb:
        drawBomb(canvas, c, radius);
    }
  }

  /// Balonların en alt sırası tehlike çizgisine ne kadar yakın (0 uzak, 1 dibinde).
  double _dangerLevel() {
    for (var row = g.grid.length - 1; row >= 0; row--) {
      if (g.grid[row].any((v) => v != null)) {
        final left = g.maxRows - 1 - row;
        return left >= 3 ? 0 : (3 - left) / 3;
      }
    }
    return 0;
  }

  /// Arka planda yavaşça yükselen soluk balonlar.
  void _bokeh(Canvas canvas, Size size) {
    final t = g.time;
    for (var i = 0; i < 14; i++) {
      final speed = 10.0 + (i % 4) * 7;
      final span = size.height + 120;
      final y = span - ((t * speed + i * 137.0) % span) - 60;
      final x =
          ((i * 61) % 100) / 100 * size.width + sin(t * 0.4 + i * 1.7) * 14;
      final rad = g.r * (0.35 + (i % 5) * 0.18);
      canvas.drawCircle(
        Offset(x, y),
        rad,
        Paint()
          ..color = bubbleColors[i % bubbleColors.length].withValues(
            alpha: 0.06,
          ),
      );
      canvas.drawCircle(
        Offset(x - rad * 0.3, y - rad * 0.3),
        rad * 0.25,
        Paint()..color = Colors.white.withValues(alpha: 0.05),
      );
    }
  }

  /// Giriş (yukarıdan kayma) ve çarpışma sallanması ile balonun çizim yeri.
  Offset _bubblePos(int row, int c) {
    var p = g.cellCenter(row, c);
    // giriş animasyonu: sıralar sırayla yukarıdan iner
    final k = ((g.time - row * 0.04) / 0.5).clamp(0.0, 1.0);
    if (k < 1) {
      final e = 1 - pow(1 - k, 3).toDouble();
      p = p.translate(0, -(1 - e) * (row + 4) * g.rowH);
    }
    // çarpışma: yakın komşular dışa doğru kısa bir esneme yapar
    final ip = g.impactPos;
    if (ip != null && g.impactT < 0.32) {
      final d = p - ip;
      final dist = d.distance;
      final reach = g.r * 4.5;
      if (dist > 1 && dist < reach) {
        final amp =
            g.r * 0.28 * (1 - dist / reach) * sin(g.impactT / 0.32 * pi);
        p += d / dist * amp;
      }
    }
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final r = g.r;
    _bokeh(canvas, size);

    // tehlike çizgisi (balonlar yaklaştıkça kırmızı nabız atar)
    final dy = g.dangerY;
    final danger = _dangerLevel();
    if (danger > 0) {
      final pulse = 0.5 + 0.5 * sin(g.time * 7);
      canvas.drawRect(
        Rect.fromLTWH(0, dy - r * 2.2, size.width, r * 2.2),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              LP.ruby.withValues(alpha: 0.28 * danger * (0.5 + pulse * 0.5)),
            ],
          ).createShader(Rect.fromLTWH(0, dy - r * 2.2, size.width, r * 2.2)),
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(0, dy - 1 - danger * 1.5, size.width, 2 + danger * 3),
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            LP.ruby.withValues(alpha: 0.8),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, dy, size.width, 2)),
    );
    final label = TextPainter(
      text: TextSpan(
        text: '⚠ TEHLİKE ÇİZGİSİ',
        style: outfit(11, color: Colors.white, spacing: 0.8),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final lr = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, dy),
        width: label.width + 22,
        height: label.height + 8,
      ),
      const Radius.circular(99),
    );
    canvas.drawRRect(lr, Paint()..color = const Color(0xFF9A0039));
    label.paint(
      canvas,
      Offset(size.width / 2 - label.width / 2, dy - label.height / 2),
    );

    // ızgara
    for (var row = 0; row < g.grid.length; row++) {
      for (var c = 0; c < g.rowLen(row); c++) {
        final v = g.grid[row][c];
        if (v == null) continue;
        final p = _bubblePos(row, c);
        if (v == stone) {
          drawStone(canvas, p, r * 0.93);
        } else if (v == bombCell) {
          drawBomb(canvas, p, r * 0.93, g.time + row + c);
        } else {
          drawBubble(canvas, p, r * 0.93, bubbleColors[v]);
        }
      }
    }

    // efektler
    for (final p in g.particles) {
      if (p.falling && p.color == stone) {
        drawStone(canvas, p.pos, r * 0.93);
      } else if (p.falling && p.color == bombCell) {
        drawBomb(canvas, p.pos, r * 0.93);
      } else if (p.falling) {
        drawBubble(
          canvas,
          p.pos,
          r * 0.93,
          bubbleColors[p.color],
          opacity: 0.85,
          glow: false,
        );
      } else {
        final k = (p.t / 0.35).clamp(0.0, 1.0);
        final col =
            p.color == stone
                ? const Color(0xFF9AA3B5)
                : p.color == bombCell
                ? const Color(0xFFFF4D4D)
                : bubbleColors[p.color];
        canvas.drawCircle(
          p.pos,
          r * (0.9 + k),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.3 * (1 - k)
            ..color = col.withValues(alpha: 1 - k),
        );
        final spark = Paint()..color = Colors.white.withValues(alpha: 1 - k);
        for (var i = 0; i < 6; i++) {
          final a = i * pi / 3 + p.pos.dx;
          canvas.drawCircle(
            p.pos + Offset(cos(a), sin(a)) * r * (0.6 + k * 1.6),
            r * 0.1 * (1 - k),
            spark,
          );
        }
      }
    }

    // bomba şok dalgaları
    for (final (c, t) in g.bombBlasts) {
      final k = (t / 0.45).clamp(0.0, 1.0);
      canvas.drawCircle(
        c,
        r * (1 + k * 4.2),
        Paint()
          ..color = const Color(0xFFFFB800).withValues(alpha: 0.35 * (1 - k)),
      );
      canvas.drawCircle(
        c,
        r * (1 + k * 4.6),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.35 * (1 - k)
          ..color = Colors.white.withValues(alpha: 0.9 * (1 - k)),
      );
    }

    // uçuşan puan yazıları
    for (final f in g.floats) {
      final k = (f.t / 0.9).clamp(0.0, 1.0);
      final tp = TextPainter(
        text: TextSpan(
          text: f.text,
          style: outfit(
            r * 0.95,
            w: FontWeight.w900,
            color: Colors.white.withValues(alpha: 1 - k * k),
            shadows: [
              Shadow(
                color: bubbleColors[f.color].withValues(alpha: 1 - k),
                blurRadius: 8,
              ),
              const Shadow(color: Color(0xAA1A0730), offset: Offset(0, 2)),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final scale = k < 0.15 ? 0.6 + k / 0.15 * 0.5 : 1.1 - (k - 0.15) * 0.15;
      canvas.save();
      canvas.translate(f.pos.dx, f.pos.dy - k * r * 2.6);
      canvas.scale(scale);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }

    // nişan çizgisi
    if (g.aiming && g.ballPos == null && g.state == GameState.playing) {
      final color = switch (g.armed) {
        ShotKind.fire => const Color(0xFFFF7A1A),
        ShotKind.rainbow => Colors.white,
        ShotKind.laser => LP.cyan,
        ShotKind.bomb => const Color(0xFFFF4D4D),
        ShotKind.normal => bubbleColors[g.current],
      };
      var pos = g.shooter;
      var dir = Offset(cos(g.aimAngle), sin(g.aimAngle));
      final step = r * 0.5;
      final dot = Paint();
      var bounces = 0;
      for (var i = 0; i < 200; i++) {
        pos += dir * step;
        if (pos.dx < r || pos.dx > size.width - r) {
          pos = Offset(pos.dx.clamp(r, size.width - r), pos.dy);
          dir = Offset(pos.dx <= r ? dir.dx.abs() : -dir.dx.abs(), dir.dy);
          // en fazla 2 sekme gösterilir; ekran noktalarla dolmasın
          if (++bounces > 2) break;
        }
        if (pos.dy < r || (g.armed != ShotKind.fire && _near(pos))) {
          // hedef: balonun oturacağı yerde hayalet balon
          if (g.armed == ShotKind.normal ||
              g.armed == ShotKind.rainbow ||
              g.armed == ShotKind.bomb) {
            final cell = g.landingCell(Offset(pos.dx, max(pos.dy, r)));
            if (cell != null) {
              final at = g.cellCenter(cell.$1, cell.$2);
              final pulse = 0.5 + 0.5 * sin(g.time * 6);
              if (g.armed == ShotKind.bomb) {
                // patlama alanı önizlemesi
                for (final (a, b) in g.blastArea(cell.$1, cell.$2)) {
                  if (g.grid[a][b] != null) {
                    canvas.drawCircle(
                      g.cellCenter(a, b),
                      r * 0.95,
                      Paint()
                        ..color = const Color(
                          0xFFFF4D4D,
                        ).withValues(alpha: 0.18 + 0.12 * pulse),
                    );
                  }
                }
              }
              canvas.drawCircle(
                at,
                r * 0.9,
                Paint()..color = color.withValues(alpha: 0.18 + 0.1 * pulse),
              );
              canvas.drawCircle(
                at,
                r * 0.9,
                Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = r * 0.12
                  ..color = color.withValues(alpha: 0.65 + 0.3 * pulse),
              );
            }
          }
          break;
        }
        if (i % 3 == 0 && i > 3) {
          dot.color = color.withValues(alpha: max(0.25, 0.95 - i / 260));
          canvas.drawCircle(pos, r * (0.15 - min(i, 120) / 2400), dot);
        }
      }
    }

    // atıcı halkası
    final s = g.shooter;
    final dir = Offset(cos(g.aimAngle), sin(g.aimAngle));
    canvas.drawCircle(
      s,
      r * 1.55,
      Paint()..color = LP.bgDeep.withValues(alpha: 0.6),
    );
    canvas.drawCircle(
      s,
      r * 1.55,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.22
        ..shader = const SweepGradient(
          colors: [LP.goldLight, LP.gold, Color(0xFFC77700), LP.goldLight],
        ).createShader(Rect.fromCircle(center: s, radius: r * 1.55)),
    );
    final tip = s + dir * r * 2.05;
    final side = Offset(-dir.dy, dir.dx);
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(
          (s + dir * r * 1.6 + side * r * 0.32).dx,
          (s + dir * r * 1.6 + side * r * 0.32).dy,
        )
        ..lineTo(
          (s + dir * r * 1.6 - side * r * 0.32).dx,
          (s + dir * r * 1.6 - side * r * 0.32).dy,
        )
        ..close(),
      Paint()..color = LP.gold,
    );
    if (g.ballPos == null && g.state == GameState.playing) {
      drawShot(canvas, s, r * 1.05, g.armed, g.current);
    }
    final bp = g.ballPos;
    if (bp != null) {
      if (g.ballKind == ShotKind.fire) {
        canvas.drawCircle(
          bp,
          r * 1.6,
          Paint()
            ..color = const Color(0xFFFF7A1A).withValues(alpha: 0.5)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.8),
        );
      }
      drawShot(canvas, bp, r * 0.93, g.ballKind, g.ballColor);
    }

    // sıradaki balon + takas
    drawBubble(canvas, g.nextPos, r * 0.78, bubbleColors[g.next]);
    final swapC = g.nextPos + Offset(0, r * 1.45);
    canvas.drawCircle(swapC, r * 0.45, Paint()..color = LP.surfaceHighest);
    _icon(canvas, Icons.sync_rounded, swapC, r * 0.6, LP.onSurface);
  }

  bool _near(Offset pos) {
    final lim = (2 * g.r * 0.85) * (2 * g.r * 0.85);
    for (var row = 0; row < g.grid.length; row++) {
      for (var c = 0; c < g.rowLen(row); c++) {
        if (g.grid[row][c] != null &&
            (g.cellCenter(row, c) - pos).distanceSquared < lim) {
          return true;
        }
      }
    }
    return false;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
