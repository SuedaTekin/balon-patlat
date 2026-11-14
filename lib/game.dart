import 'dart:math';
import 'dart:ui';

/// Luminous Pop balon renkleri: pembe, camgöbeği, altın, zümrüt, ametist, turuncu.
const List<Color> bubbleColors = [
  Color(0xFFFF4E7C),
  Color(0xFF00D8F5),
  Color(0xFFFFB800),
  Color(0xFF10E56A),
  Color(0xFFA25CFF),
  Color(0xFFFF7A1A),
];

enum Booster { moves, rainbow, fire, laser }

enum ShotKind { normal, rainbow, fire, laser, bomb }

enum GameState { playing, won, lostMoves, lostDanger }

class Particle {
  Offset pos;
  Offset vel;
  final int color;
  final bool falling;
  double t = 0;
  Particle(this.pos, this.vel, this.color, this.falling);
}

/// Patlamanın olduğu yerde yükselip kaybolan puan yazısı.
class FloatText {
  FloatText(this.pos, this.text, this.color);
  final Offset pos;
  final String text;
  final int color;
  double t = 0;
}

typedef Cell = (int, int);

/// Taş balon: eşleşmez, sadece altındaki bağ kopunca düşer ya da
/// Ateş/Lazer ile kırılır. Kazanmak için taşları temizlemek gerekmez.
const int stone = 99;

bool isColor(int? v) => v != null && v < bubbleColors.length;

/// Bomba balon: yanındaki bir balon patlayınca (ya da Ateş/Lazer değince)
/// çevresindeki iki halkayı havaya uçurur; zincirleme patlayabilir.
/// Taş gibi, kazanmak için temizlenmesi gerekmez.
const int bombCell = 98;

/// Toplam bölüm sayısı.
const int maxLevel = 500;

/// Bölüm türü: zor bölümler haritada kırmızı/mor işaretlenir ve
/// daha çok altın verir.
enum LevelKind { normal, hard, superHard }

class LevelConfig {
  final int level, rows, colors, shotsPerRow;
  const LevelConfig(this.level, this.rows, this.colors, this.shotsPerRow);

  /// Zorluk eğrisi: seviye arttıkça daha çok sıra, daha çok renk,
  /// daha az hamle, daha sık inen yeni sıralar ve 21. bölümden sonra
  /// taş balonlar.
  factory LevelConfig.forLevel(int level) => LevelConfig(
    level,
    min(4 + (level + 1) ~/ 2, 12),
    level < 3 ? 3 : (level < 7 ? 4 : (level < 16 ? 5 : 6)),
    level < 4
        ? 0
        : max(kindOf(level) == LevelKind.superHard ? 3 : 4, 9 - level ~/ 5),
  );

  static LevelKind kindOf(int level) {
    if (level >= 30 && level % 10 == 0) return LevelKind.superHard;
    if (level >= 15 && level % 5 == 0) return LevelKind.hard;
    return LevelKind.normal;
  }

  LevelKind get kind => kindOf(level);

  /// Hamle çarpanı: 1. seviyede cömert (1.10), 32'de 0.72, 132'de 0.60,
  /// 300'den sonra 500'e kadar 0.55'e iner. Bölge başları biraz rahat,
  /// zor bölümler daha sıkı.
  double get movesScale {
    var s =
        level <= 32
            ? 1.10 - (level - 1) * 0.012
            : level <= 300
            ? max(0.60, 0.72 - (level - 32) * 0.0012)
            : max(0.55, 0.60 - (level - 300) * 0.00025);
    if (level > 10 && level % 10 == 1) s *= 1.08;
    s *= switch (kind) {
      LevelKind.hard => 0.96,
      LevelKind.superHard => 0.92,
      LevelKind.normal => 1.0,
    };
    return s;
  }

  /// Taş balon oranı: 21. bölümden itibaren %3'ten %10'a, 300'den sonra
  /// %13'e kadar; zor bölümde +%3.
  double get stoneRatio {
    if (level < 21) return 0;
    var r = min(0.10, 0.03 + (level - 21) * 0.0005);
    if (level > 300) r += min(0.03, (level - 300) * 0.00015);
    if (kind != LevelKind.normal) r += 0.03;
    return r;
  }

  /// Izgaradaki bomba balon sayısı (12. bölümden itibaren 1–3).
  int get bombCount => level < 12 ? 0 : min(3, 1 + (level - 12) ~/ 60);

  /// Tehlike çizgisinin üstünde boş bırakılan sıra sayısı.
  int get freeRows => level < 10 ? 5 : 4;

  /// Top hızı (ekran genişliği/saniye), seviyeyle hafifçe artar.
  double get speedFactor => 3.4 + min(level, 150) * 0.010;

  /// Kazanınca ilk sefer verilen ek altın.
  int get bonusCoins => switch (kind) {
    LevelKind.hard => 60,
    LevelKind.superHard => 150,
    LevelKind.normal => 0,
  };
}

class BubbleGame {
  static const int cols = 8;

  BubbleGame(this.cfg);
  final LevelConfig cfg;
  final Random rnd = Random();

  double r = 20, rowH = 34, width = 0, height = 0;
  Offset shooter = Offset.zero;
  int maxRows = 12;

  List<List<int?>> grid = [];
  int parity = 0;

  GameState state = GameState.playing;
  int score = 0, movesLeft = 0, totalMoves = 0, combo = 0, missCount = 0;
  int initialCount = 1, stars = 0;
  int current = 0, next = 0;
  ShotKind armed = ShotKind.normal;

  Offset? ballPos;
  Offset ballVel = Offset.zero;
  int ballColor = 0;
  ShotKind ballKind = ShotKind.normal;
  int _firePopped = 0;

  double aimAngle = -pi / 2;
  bool aiming = false;
  String? comboText;
  double comboTimer = 0;
  final List<Particle> particles = [];
  final List<FloatText> floats = [];

  /// Bölüm başından beri geçen süre (giriş animasyonu, arka plan).
  double time = 0;

  /// Son çarpışma noktası ve üstünden geçen süre (komşu sallanması).
  Offset? impactPos;
  double impactT = 9;
  bool _ready = false;

  void Function(int popped)? onPop;

  /// Ses olayı: shoot, bounce, stick, pop, drop, stone, row, combo,
  /// fire, laser, rainbow. (Bot/klon oyunlarda boş kalır.)
  void Function(String event)? onSfx;

  /// Her atış bitince: patlayan, düşen, kombo, renk başına patlayan sayısı.
  void Function(int popped, int dropped, int combo, Map<int, int> colors)?
  onShot;
  final Map<int, int> _shotColors = {};

  double get speed => width * cfg.speedFactor;
  int get shotsUntilRow => cfg.shotsPerRow - missCount;
  Offset get nextPos => shooter + Offset(-r * 4.4, r * 0.3);
  double get dangerY => (maxRows - 1) * rowH;

  /// Renkli (temizlenmesi gereken) balon sayısı.
  int get bubbleCount =>
      grid.fold(0, (s, row) => s + row.where(isColor).length);

  int get stoneCount =>
      grid.fold(0, (s, row) => s + row.where((v) => v == stone).length);
  double get cleared => (1 - bubbleCount / initialCount).clamp(0.0, 1.0);

  void layout(Size s) {
    if (s.width == width && s.height == height) return;
    width = s.width;
    height = s.height;
    r = width / (cols * 2);
    rowH = r * sqrt(3);
    shooter = Offset(width / 2, height - r * 2.4);
    maxRows = max(7, ((shooter.dy - r * 3.5) / rowH).floor() + 1);
    if (!_ready) {
      _ready = true;
      _generate();
    } else {
      while (grid.length < maxRows) {
        grid.add(List<int?>.filled(cols, null));
      }
      while (grid.length > maxRows) {
        grid.removeLast();
      }
    }
  }

  static int movesFor(int bubbles, LevelConfig cfg) => max(
    10,
    ((bubbles / (2.6 - cfg.colors * 0.12) + 3) * cfg.movesScale).ceil(),
  );

  void _generate() {
    final g = Random(cfg.level * 7919 + 17);
    parity = 0;
    grid = List.generate(maxRows, (_) => List<int?>.filled(cols, null));
    final rows = max(1, min(cfg.rows, maxRows - cfg.freeRows));
    for (var row = 0; row < rows; row++) {
      for (var c = 0; c < rowLen(row); c++) {
        var color = g.nextInt(cfg.colors);
        if (c > 0 && g.nextDouble() < 0.45) {
          color = grid[row][c - 1]!;
        } else if (row > 0 && g.nextDouble() < 0.35) {
          final up = grid[row - 1][min(c, rowLen(row - 1) - 1)];
          if (up != null) color = up;
        }
        grid[row][c] = color;
      }
    }
    // Taşlar: en üst sıraya konmaz (yoksa hiç düşmez), alt sıralara yakın
    // daha sık; renkli balonları kalkan gibi korur.
    final sr = cfg.stoneRatio;
    if (sr > 0) {
      for (var row = 1; row < rows; row++) {
        final weight = 0.6 + 0.8 * row / max(1, rows - 1);
        for (var c = 0; c < rowLen(row); c++) {
          if (g.nextDouble() < sr * weight) grid[row][c] = stone;
        }
      }
      // çok az renkli balon kaldıysa son sırayı renklendir
      if (bubbleCount < 6) {
        for (var c = 0; c < rowLen(rows - 1); c++) {
          grid[rows - 1][c] = g.nextInt(cfg.colors);
        }
      }
    }
    // Bombalar: orta-alt sıralarda renkli bir balonun yerine konur.
    for (var k = 0, tries = 0; k < cfg.bombCount && tries < 50; tries++) {
      final row = max(1, rows ~/ 3) + g.nextInt(max(1, rows - rows ~/ 3));
      final c = g.nextInt(rowLen(min(row, rows - 1)));
      final rr = min(row, rows - 1);
      if (isColor(grid[rr][c]) && bubbleCount > 8) {
        grid[rr][c] = bombCell;
        k++;
      }
    }
    initialCount = bubbleCount;
    // taşlar engel olduğu için az da olsa ek hamle verir
    totalMoves = movesFor(initialCount, cfg) + (stoneCount * 0.12).ceil();
    movesLeft = totalMoves;
    current = pickColor();
    next = pickColor();
  }

  void restart() {
    score = 0;
    combo = 0;
    missCount = 0;
    stars = 0;
    state = GameState.playing;
    armed = ShotKind.normal;
    particles.clear();
    floats.clear();
    bombBlasts.clear();
    ballPos = null;
    comboText = null;
    time = 0;
    impactPos = null;
    _generate();
  }

  /// Nişan çizgisinin değdiği noktada balonun oturacağı hücre.
  Cell? landingCell(Offset pos) {
    final approx = ((pos.dy - r) / rowH).round();
    return _nearestEmpty(pos, approx - 1, approx + 1, true) ??
        _nearestEmpty(pos, 0, grid.length - 1, false);
  }

  BubbleGame clone() {
    return BubbleGame(cfg)
      ..r = r
      ..rowH = rowH
      ..width = width
      ..height = height
      ..shooter = shooter
      ..maxRows = maxRows
      .._ready = true
      ..grid = [for (final row in grid) List.of(row)]
      ..parity = parity
      ..current = current
      ..next = next
      ..movesLeft = movesLeft
      ..totalMoves = totalMoves
      ..initialCount = initialCount
      ..missCount = missCount;
  }

  // ---------- ızgara yardımcıları ----------
  bool isOffset(int row) => (row + parity) % 2 == 1;
  int rowLen(int row) => isOffset(row) ? cols - 1 : cols;
  Offset cellCenter(int row, int c) =>
      Offset(r + c * 2 * r + (isOffset(row) ? r : 0), r + row * rowH);

  List<Cell> neighbors(int row, int c) {
    final o = isOffset(row);
    final cand = <Cell>[
      (row, c - 1),
      (row, c + 1),
      if (o) ...[
        (row - 1, c),
        (row - 1, c + 1),
        (row + 1, c),
        (row + 1, c + 1),
      ] else ...[
        (row - 1, c - 1),
        (row - 1, c),
        (row + 1, c - 1),
        (row + 1, c),
      ],
    ];
    return cand
        .where(
          (p) =>
              p.$1 >= 0 &&
              p.$1 < grid.length &&
              p.$2 >= 0 &&
              p.$2 < rowLen(p.$1),
        )
        .toList();
  }

  Set<Cell> _flood(int row, int c, bool Function(int, int) test) {
    final seen = <Cell>{(row, c)};
    final queue = <Cell>[(row, c)];
    while (queue.isNotEmpty) {
      final cur = queue.removeLast();
      for (final n in neighbors(cur.$1, cur.$2)) {
        if (!seen.contains(n) && test(n.$1, n.$2)) {
          seen.add(n);
          queue.add(n);
        }
      }
    }
    return seen;
  }

  Set<int> _presentColors() {
    final s = <int>{};
    for (final row in grid) {
      for (final v in row) {
        if (isColor(v)) s.add(v!);
      }
    }
    return s;
  }

  /// Atıcıya gelecek rengi, boş komşusu olan (ulaşılabilir) balonların
  /// renklerinden, sayılarıyla ağırlıklı seçer; ölü atışları azaltır.
  int pickColor() {
    final exposed = <int>[];
    for (var row = 0; row < grid.length; row++) {
      for (var c = 0; c < rowLen(row); c++) {
        final v = grid[row][c];
        if (isColor(v) &&
            neighbors(row, c).any((n) => grid[n.$1][n.$2] == null)) {
          exposed.add(v!);
        }
      }
    }
    if (exposed.isNotEmpty) return exposed[rnd.nextInt(exposed.length)];
    final present = _presentColors().toList();
    if (present.isEmpty) return rnd.nextInt(cfg.colors);
    return present[rnd.nextInt(present.length)];
  }

  // ---------- kontrol ----------
  void aimAt(Offset p) {
    final v = p - shooter;
    var a = atan2(v.dy, v.dx);
    if (v.dy >= 0) a = v.dx < 0 ? -pi : 0;
    // çok yatık açılar sonsuz sekmeye yol açar; en az ~11°
    aimAngle = a.clamp(-pi + 0.2, -0.2);
  }

  void swap() {
    if (ballPos != null || state != GameState.playing) return;
    final t = current;
    current = next;
    next = t;
  }

  ShotKind? fire() {
    if (ballPos != null || state != GameState.playing) return null;
    ballKind = armed;
    armed = ShotKind.normal;
    _firePopped = 0;
    _shotColors.clear();
    ballPos = shooter;
    ballVel = Offset(cos(aimAngle), sin(aimAngle)) * speed;
    ballColor = current;
    // bomba renkli balonu harcamaz; sıradaki renk yerinde kalır
    if (ballKind != ShotKind.bomb) {
      current = next;
      next = pickColor();
    }
    movesLeft--;
    onSfx?.call(switch (ballKind) {
      ShotKind.fire => 'fire',
      ShotKind.rainbow => 'rainbow',
      _ => 'shoot',
    });
    return ballKind;
  }

  void addMoves(int n) {
    movesLeft += n;
    if (state == GameState.lostMoves) state = GameState.playing;
  }

  /// Tehlike çizgisine yakın alt sıraları patlatıp oyuna devam ettirir.
  void rescue() {
    final cells = <Cell>[];
    for (var row = max(0, maxRows - 5); row < grid.length; row++) {
      for (var c = 0; c < rowLen(row); c++) {
        if (grid[row][c] != null) cells.add((row, c));
      }
    }
    _pop(cells);
    _dropFloating();
    if (movesLeft <= 0) movesLeft = 3;
    state = GameState.playing;
    if (bubbleCount == 0) _checkEnd();
  }

  // ---------- döngü ----------
  void update(double dt) {
    dt = min(dt, 1 / 30);
    time += dt;
    impactT += dt;
    for (final f in floats) {
      f.t += dt;
    }
    floats.removeWhere((f) => f.t > 0.9);
    for (var i = 0; i < bombBlasts.length; i++) {
      bombBlasts[i] = (bombBlasts[i].$1, bombBlasts[i].$2 + dt);
    }
    bombBlasts.removeWhere((b) => b.$2 > 0.45);
    for (final p in particles) {
      p.t += dt;
      if (p.falling) {
        p.vel += Offset(0, height * 2.5) * dt;
        p.pos += p.vel * dt;
      }
    }
    particles.removeWhere(
      (p) => p.falling ? p.pos.dy > height + r * 2 : p.t > 0.35,
    );
    if (comboTimer > 0) {
      comboTimer -= dt;
      if (comboTimer <= 0) comboText = null;
    }

    final bp = ballPos;
    if (bp == null) return;
    final steps = max(1, (speed * dt / (r * 0.25)).ceil());
    final h = dt / steps;
    var pos = bp;
    var vel = ballVel;
    for (var i = 0; i < steps; i++) {
      pos += vel * h;
      if (pos.dx < r) {
        pos = Offset(r, pos.dy);
        if (vel.dx < 0) onSfx?.call('bounce');
        vel = Offset(vel.dx.abs(), vel.dy);
      }
      if (pos.dx > width - r) {
        pos = Offset(width - r, pos.dy);
        if (vel.dx > 0) onSfx?.call('bounce');
        vel = Offset(-vel.dx.abs(), vel.dy);
      }
      if (ballKind == ShotKind.fire) {
        final hit = _cellsNear(pos, 2 * r * 0.95);
        if (hit.isNotEmpty) _firePopped += _pop(hit);
        if (pos.dy <= r) {
          ballPos = null;
          impactPos = Offset(pos.dx, height * 0.25);
          _finishShot(_firePopped);
          return;
        }
        continue;
      }
      if (pos.dy <= r || _cellsNear(pos, 2 * r * 0.85).isNotEmpty) {
        ballPos = null;
        _snap(pos);
        return;
      }
    }
    ballPos = pos;
    ballVel = vel;
  }

  List<Cell> _cellsNear(Offset pos, double dist) {
    final lim = dist * dist;
    final out = <Cell>[];
    for (var row = 0; row < grid.length; row++) {
      for (var c = 0; c < rowLen(row); c++) {
        if (grid[row][c] != null &&
            (cellCenter(row, c) - pos).distanceSquared < lim) {
          out.add((row, c));
        }
      }
    }
    return out;
  }

  Cell? _nearestEmpty(Offset pos, int fromRow, int toRow, bool attachedOnly) {
    Cell? best;
    var bestD = double.infinity;
    for (var row = max(0, fromRow); row <= min(grid.length - 1, toRow); row++) {
      for (var c = 0; c < rowLen(row); c++) {
        if (grid[row][c] != null) continue;
        if (attachedOnly &&
            row != 0 &&
            !neighbors(row, c).any((n) => grid[n.$1][n.$2] != null)) {
          continue;
        }
        final d = (cellCenter(row, c) - pos).distanceSquared;
        if (d < bestD) {
          bestD = d;
          best = (row, c);
        }
      }
    }
    return best;
  }

  void _snap(Offset pos) {
    final cell = landingCell(pos);
    if (cell == null) {
      state = GameState.lostDanger;
      return;
    }
    final (row, c) = cell;
    impactPos = cellCenter(row, c);
    impactT = 0;

    if (ballKind == ShotKind.laser) {
      // çarpılan balonun sırası (tavana çarptıysa oturduğu sıra) tamamen silinir
      final hits = _cellsNear(pos, 2 * r);
      var target = row;
      if (hits.isNotEmpty) {
        hits.sort(
          (a, b) => (cellCenter(a.$1, a.$2) - pos).distanceSquared.compareTo(
            (cellCenter(b.$1, b.$2) - pos).distanceSquared,
          ),
        );
        target = hits.first.$1;
      }
      grid[row][c] = ballColor;
      final cells = <Cell>[
        (row, c),
        for (var cc = 0; cc < rowLen(target); cc++)
          if (grid[target][cc] != null) (target, cc),
      ];
      onSfx?.call('laser');
      _finishShot(_pop(cells));
      return;
    }

    if (ballKind == ShotKind.bomb) {
      // bomba atış: oturduğu yerde iki halkalık alanı patlatır
      onSfx?.call('bomb');
      bombBlasts.add((impactPos!, 0.0));
      _finishShot(_pop(blastArea(row, c)));
      return;
    }

    if (ballKind == ShotKind.rainbow) {
      var bestColor = ballColor;
      var bestSize = 0;
      final options = {
        for (final n in neighbors(row, c))
          if (isColor(grid[n.$1][n.$2])) grid[n.$1][n.$2]!,
      };
      for (final col in options) {
        grid[row][c] = col;
        final size = _flood(row, c, (a, b) => grid[a][b] == col).length;
        if (size > bestSize) {
          bestSize = size;
          bestColor = col;
        }
      }
      ballColor = bestColor;
    }

    grid[row][c] = ballColor;
    final cluster = _flood(row, c, (a, b) => grid[a][b] == ballColor);
    _finishShot(cluster.length >= 3 ? _pop(cluster) : 0);
  }

  /// Bir hücre ve çevresindeki iki halka (patlama alanı).
  Set<Cell> blastArea(int row, int c) {
    final out = <Cell>{(row, c)};
    for (final n in neighbors(row, c)) {
      out.add(n);
      out.addAll(neighbors(n.$1, n.$2));
    }
    return out;
  }

  /// Testler için: verilen hücreleri patlatır (bomba zinciri dahil).
  int popCells(Iterable<Cell> cells) => _pop(cells);

  /// Patlayan bombaların merkezleri ve yaşları (şok dalgası çizimi için).
  final List<(Offset, double)> bombBlasts = [];

  /// Hücreleri patlatır. Patlayan bir balonun yanındaki bomba balon da
  /// patlar ve iki halkalık alanı temizler (zincirleme olabilir).
  int _pop(Iterable<Cell> cells) {
    var n = 0;
    var stones = false, bombs = false;
    final queue = cells.toList();
    for (var i = 0; i < queue.length; i++) {
      final (a, b) = queue[i];
      final v = grid[a][b];
      if (v == null) continue;
      particles.add(Particle(cellCenter(a, b), Offset.zero, v, false));
      grid[a][b] = null;
      if (isColor(v)) {
        _shotColors[v] = (_shotColors[v] ?? 0) + 1;
      } else if (v == stone) {
        stones = true;
      }
      if (v == bombCell) {
        bombs = true;
        bombBlasts.add((cellCenter(a, b), 0));
        queue.addAll(blastArea(a, b));
      } else {
        // komşudaki bombayı tetikle
        for (final nb in neighbors(a, b)) {
          if (grid[nb.$1][nb.$2] == bombCell) queue.add(nb);
        }
      }
      n++;
    }
    if (bombs) onSfx?.call('bomb');
    if (stones) onSfx?.call('stone');
    return n;
  }

  int _dropFloating() {
    final anchored = <Cell>{};
    for (var cc = 0; cc < rowLen(0); cc++) {
      if (grid[0][cc] != null && !anchored.contains((0, cc))) {
        anchored.addAll(_flood(0, cc, (a, b) => grid[a][b] != null));
      }
    }
    var dropped = 0;
    for (var a = 0; a < grid.length; a++) {
      for (var b = 0; b < rowLen(a); b++) {
        final v = grid[a][b];
        if (v != null && !anchored.contains((a, b))) {
          particles.add(
            Particle(
              cellCenter(a, b),
              Offset(
                (rnd.nextDouble() - 0.5) * r * 8,
                -r * rnd.nextDouble() * 6,
              ),
              v,
              true,
            ),
          );
          grid[a][b] = null;
          dropped++;
        }
      }
    }
    return dropped;
  }

  void _finishShot(int popped) {
    final dropped = popped > 0 ? _dropFloating() : 0;
    if (popped > 0) {
      combo++;
      final pts = (popped * 10 + dropped * 20) * combo;
      score += pts;
      floats.add(
        FloatText(
          impactPos ?? Offset(width / 2, height * 0.3),
          '+$pts',
          isColor(ballColor) ? ballColor : 0,
        ),
      );
      if (combo >= 2) {
        comboText = 'X$combo COMBO! +$pts';
        comboTimer = 1.6;
        onSfx?.call('combo');
      }
      onSfx?.call('pop');
      if (dropped > 0) onSfx?.call('drop');
      onPop?.call(popped + dropped);
      onShot?.call(popped, dropped, combo, Map.of(_shotColors));
    } else {
      combo = 0;
      onSfx?.call('stick');
      if (cfg.shotsPerRow > 0) {
        missCount++;
        if (missCount >= cfg.shotsPerRow) {
          missCount = 0;
          onSfx?.call('row');
          _addRow();
        }
      }
    }
    _checkEnd();
  }

  void _checkEnd() {
    if (bubbleCount == 0) {
      // kalan taşlar ve bombalar ufalanıp düşer
      for (var a = 0; a < grid.length; a++) {
        for (var b = 0; b < rowLen(a); b++) {
          final v = grid[a][b];
          if (v != null) {
            particles.add(
              Particle(
                cellCenter(a, b),
                Offset(
                  (rnd.nextDouble() - 0.5) * r * 6,
                  -r * rnd.nextDouble() * 4,
                ),
                v,
                true,
              ),
            );
            grid[a][b] = null;
            score += v == bombCell ? 100 : 30;
          }
        }
      }
      final ratio = movesLeft / totalMoves;
      stars = ratio >= 0.3 ? 3 : (ratio >= 0.12 ? 2 : 1);
      score += movesLeft * 50;
      state = GameState.won;
      return;
    }
    if (grid.last.any((v) => v != null)) {
      state = GameState.lostDanger;
      return;
    }
    if (movesLeft <= 0) {
      state = GameState.lostMoves;
      return;
    }
    final present = _presentColors();
    if (!present.contains(current)) current = pickColor();
    if (!present.contains(next)) next = pickColor();
  }

  void _addRow() {
    parity ^= 1;
    grid.removeLast();
    final row = List<int?>.filled(cols, null);
    grid.insert(0, row);
    final present = _presentColors().toList();
    for (var c = 0; c < rowLen(0); c++) {
      row[c] =
          present.isNotEmpty && rnd.nextDouble() < 0.7
              ? present[rnd.nextInt(present.length)]
              : rnd.nextInt(cfg.colors);
    }
  }
}
