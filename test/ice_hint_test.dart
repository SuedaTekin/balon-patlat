import 'dart:ui';

import 'package:balon_patlat/game.dart';
import 'package:flutter_test/flutter_test.dart';

BubbleGame _game(int level) =>
    BubbleGame(LevelConfig.forLevel(level))..layout(const Size(392, 640));

void main() {
  test('buz balon 40. bölümden itibaren gelir ve sayılır', () {
    expect(LevelConfig.forLevel(39).iceCount, 0);
    expect(LevelConfig.forLevel(40).iceCount, 3);
    expect(LevelConfig.forLevel(500).iceCount, 8);
    final g = _game(40);
    expect(g.iceLeft, greaterThan(0));
    // buzlar temizlenmesi gereken balonlardan sayılır
    expect(g.initialCount, g.bubbleCount);
  });

  test('yanındaki balon patlayınca buz kırılır, kendisi patlamaz', () {
    final g = _game(40);
    // boş ızgarada: (2,3) buz, yanında (2,4) normal
    g.grid = [for (final row in g.grid) List<int?>.filled(row.length, null)];
    for (var c = 0; c < g.rowLen(0); c++) {
      g.grid[0][c] = 0;
    }
    g.grid[1][3] = 0;
    g.grid[2][3] = iceBase + 2;
    g.grid[2][4] = 1;
    g.popCells([(2, 4)]);
    expect(g.grid[2][3], 2, reason: 'buz kırılıp sarı balona dönmeli');
    expect(g.iceBroken, 1);
  });

  test('bomba buzu doğrudan patlatır', () {
    final g = _game(40);
    g.grid = [for (final row in g.grid) List<int?>.filled(row.length, null)];
    g.grid[0][3] = iceBase + 1;
    g.grid[0][4] = bombCell;
    g.popCells([(0, 4)]);
    expect(g.grid[0][3], isNull);
  });

  test('virüs ve bukalemun ileri bölümlerde gelir', () {
    expect(LevelConfig.forLevel(69).virusCount, 0);
    expect(LevelConfig.forLevel(71).virusCount, 1);
    expect(LevelConfig.forLevel(99).chamCount, 0);
    expect(LevelConfig.forLevel(101).chamCount, 2);
    final g = _game(250);
    expect(g.virusLeft, greaterThan(0));
    var cham = 0;
    for (final row in g.grid) {
      cham += row.where(isCham).length;
    }
    expect(cham, greaterThan(0));
  });

  test('yanındaki balon patlayınca virüs yok olur', () {
    final g = _game(71);
    g.grid = [for (final row in g.grid) List<int?>.filled(row.length, null)];
    g.grid[0][3] = virusCell;
    g.grid[0][4] = 1;
    g.popCells([(0, 4)]);
    expect(g.grid[0][3], isNull);
    expect(g.virusKilled, 1);
  });

  test('bukalemun o anki rengiyle eşleşir', () {
    expect(matchColor(chamBase + 2), 2);
    expect(matchColor(iceBase + 2), -1);
    expect(matchColor(virusCell), -1);
    expect(shownColor(chamBase + 4), 4);
  });

  test('ıskada virüs yayılır, bukalemun renk değiştirir', () {
    final g = _game(120);
    // üstte tek sıra: virüs + yanında renkli balonlar; bukalemun ayrı
    g.grid = [for (final row in g.grid) List<int?>.filled(row.length, null)];
    g.grid[0][0] = virusCell;
    g.grid[0][1] = 0;
    g.grid[0][9] = chamBase + 0;
    g.current = 1;
    g.aimAngle = -0.35; // sağa doğru, kimseyi patlatmadan yapışır
    g.fire();
    for (var k = 0; k < 400 && g.ballPos != null; k++) {
      g.update(1 / 60);
    }
    expect(g.grid[0][1], virusCell, reason: 'virüs yanındaki balona yayılmalı');
    expect(g.grid[0][9], chamBase + 1, reason: 'bukalemun sıradaki renge geçmeli');
  });

  test('sadece virüs kalınca bölüm kazanılır', () {
    final g = _game(71);
    g.grid = [for (final row in g.grid) List<int?>.filled(row.length, null)];
    g.grid[0][3] = virusCell;
    g.grid[0][4] = 2;
    g.grid[0][5] = 2;
    g.current = 2;
    // iki sarının yanına üçüncü sarıyı at: sarılar patlar, virüs de gider
    g.aimAngle = g.bestAim()!;
    g.fire();
    for (var k = 0; k < 400 && g.ballPos != null; k++) {
      g.update(1 / 60);
    }
    expect(g.state, GameState.won);
  });

  test('ipucu patlatan bir açı bulur', () {
    final g = _game(1);
    final a = g.bestAim();
    expect(a, isNotNull);
    final s = g.clone()..aimAngle = a!;
    final before = s.bubbleCount;
    s.fire();
    for (var k = 0; k < 400 && s.ballPos != null; k++) {
      s.update(1 / 60);
    }
    expect(s.bubbleCount, lessThan(before));
  });
}
