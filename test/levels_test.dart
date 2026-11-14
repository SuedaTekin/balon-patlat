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
}
