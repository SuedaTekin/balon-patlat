import 'dart:ui';

import 'package:balon_patlat/game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('300 bölüm: zorluk türleri ve taş oranı', () {
    expect(LevelConfig.kindOf(14), LevelKind.normal);
    expect(LevelConfig.kindOf(15), LevelKind.hard);
    expect(LevelConfig.kindOf(20), LevelKind.hard);
    expect(LevelConfig.kindOf(30), LevelKind.superHard);
    expect(LevelConfig.forLevel(20).stoneRatio, 0);
    expect(LevelConfig.forLevel(21).stoneRatio, greaterThan(0));
    expect(LevelConfig.forLevel(maxLevel).movesScale, greaterThan(0.5));
    var stoneLevels = 0;
    for (var l = 1; l <= maxLevel; l++) {
      final g = BubbleGame(LevelConfig.forLevel(l))
        ..layout(const Size(392, 640));
      expect(g.bubbleCount, greaterThan(5), reason: 'L$l');
      expect(g.totalMoves, greaterThanOrEqualTo(10), reason: 'L$l');
      expect(g.grid[0].contains(stone), isFalse, reason: 'L$l');
      expect(g.pickColor(), isNot(stone));
      if (g.stoneCount > 0) stoneLevels++;
    }
    expect(stoneLevels, greaterThan(200));
  });

  test('sadece taş kalınca bölüm kazanılır, taşlar ufalanır', () {
    final g = BubbleGame(LevelConfig.forLevel(40))
      ..layout(const Size(392, 640));
    for (final row in g.grid) {
      row.fillRange(0, row.length, null);
    }
    g.grid[0][0] = stone; // tavana asılı taş
    g.grid[g.maxRows - 2][0] = 1; // tek renkli balon, alt sırada
    expect(g.bubbleCount, 1);
    g.rescue(); // alt sıraları patlatır → renkli balon kalmaz
    expect(g.state, GameState.won);
    expect(g.stoneCount, 0);
  });

  test('bomba balonlar 12. bölümden itibaren gelir ve renk sayılmaz', () {
    expect(LevelConfig.forLevel(11).bombCount, 0);
    expect(LevelConfig.forLevel(12).bombCount, greaterThan(0));
    final g = BubbleGame(LevelConfig.forLevel(40))
      ..layout(const Size(392, 640));
    final bombs = g.grid.fold(
      0,
      (s, row) => s + row.where((v) => v == bombCell).length,
    );
    expect(bombs, greaterThan(0));
    expect(isColor(bombCell), isFalse);
    expect(g.pickColor(), lessThan(bubbleColors.length));
  });

  test('altın balon yanındaki patlamayla altın verir', () {
    expect(LevelConfig.forLevel(4).goldCount, 0);
    expect(LevelConfig.forLevel(6).goldCount, 3);
    final g = BubbleGame(LevelConfig.forLevel(40))
      ..layout(const Size(392, 640));
    for (var row = 0; row < g.grid.length; row++) {
      for (var c = 0; c < g.rowLen(row); c++) {
        g.grid[row][c] = row < 5 ? 1 : null;
      }
    }
    g.grid[3][3] = goldCell;
    var coins = 0;
    g.onGold = (n) => coins += n;
    g.popCells([(3, 4)]);
    expect(g.grid[3][3], isNull);
    expect(coins, goldCoins);
    expect(g.goldPopped, 1);
    expect(isColor(goldCell), isFalse);
  });

  test('günlük meydan okuma: gün aynıysa aynı dizilim, farklıysa farklı', () {
    List<List<int?>> grid(String day) =>
        (BubbleGame(LevelConfig.daily(40, day))
          ..layout(const Size(392, 640))).grid;
    expect(grid('2026-11-16'), grid('2026-11-16'));
    expect(grid('2026-11-16'), isNot(grid('2026-11-17')));
  });

  test('yanındaki balon patlayınca bomba iki halkayı temizler', () {
    final g = BubbleGame(LevelConfig.forLevel(40))
      ..layout(const Size(392, 640));
    // ilk 5 sıra mavi, ortada bir bomba ve ikinci bir bomba (zincir için)
    for (var row = 0; row < g.grid.length; row++) {
      for (var c = 0; c < g.rowLen(row); c++) {
        g.grid[row][c] = row < 5 ? 1 : null;
      }
    }
    g.grid[2][3] = bombCell;
    g.grid[2][6] = bombCell; // ilk bombanın alanında değil ama alanın komşusu
    final area = g.blastArea(2, 3);
    expect(area.length, greaterThan(12));
    // bombanın yanındaki tek balonu patlat → bomba tetiklenir
    final n = g.popCells([(2, 4)]);
    expect(n, greaterThan(area.length - 1));
    expect(g.grid[2][3], isNull); // bomba patladı
    expect(g.grid[2][1], isNull); // iki halka uzaktaki balon da gitti
    expect(g.grid[2][6], isNull); // zincirleme: ikinci bomba da patladı
    expect(g.bombBlasts.length, 2);
  });
}
