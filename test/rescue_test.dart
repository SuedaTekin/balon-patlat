import 'dart:ui';

import 'package:balon_patlat/game.dart';
import 'package:balon_patlat/progress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

BubbleGame _game(int level) =>
    BubbleGame(LevelConfig.forLevel(level))..layout(const Size(392, 640));

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Progress.load();
  });

  test(
    'kurtarma bölümleri: 18. bölümden itibaren 6\'nın katı normal bölümler',
    () {
      expect(LevelConfig.forLevel(12).rescue, isFalse);
      expect(LevelConfig.forLevel(18).rescue, isTrue);
      expect(LevelConfig.forLevel(19).rescue, isFalse);
      expect(LevelConfig.forLevel(30).rescue, isFalse, reason: 'zor bölüm');
      expect(LevelConfig.forLevel(18).chickCount, 3);
      expect(LevelConfig.forLevel(498).chickCount, 5);
      expect(LevelConfig.daily(18, '2026-11-17').rescue, isFalse);
      expect(LevelConfig.endlessMode(1).rescue, isFalse);
    },
  );

  test('yavrular üst sıralara konur, temizlenecek balonlardan sayılmaz', () {
    final g = _game(18);
    expect(g.chickTotal, 3);
    expect(g.chicksLeft, 3);
    for (var row = 3; row < g.grid.length; row++) {
      expect(g.grid[row].contains(chickCell), isFalse);
    }
    expect(g.initialCount, g.bubbleCount);
    expect(g.goalProgress, 0);
    // normal bölümden daha az hamle
    expect(g.totalMoves, lessThan(_game(17).totalMoves));
  });

  test(
    'yanındaki balon patlayınca yavru kurtulur; hepsi kurtulunca kazanılır',
    () {
      final g = _game(18);
      g.grid = [for (final row in g.grid) List<int?>.filled(row.length, null)];
      for (var c = 0; c < g.rowLen(0); c++) {
        g.grid[0][c] = 0;
      }
      g.grid[0][5] = chickCell;
      g.grid[1][2] = 1; // kazanınca kalan balon da düşer
      g.chickTotal = 1;
      g.chicksSaved = 0;
      g.current = 0;
      g.next = 0;
      final a = g.bestAim();
      expect(a, isNotNull);
      g.aimAngle = a!;
      g.fire();
      for (var k = 0; k < 400 && g.ballPos != null; k++) {
        g.update(1 / 60);
      }
      expect(g.chicksSaved, 1);
      expect(g.flyingChicks, isNotEmpty);
      expect(g.state, GameState.won, reason: 'kalan balona rağmen kazanılır');
      expect(g.bubbleCount, 0);
      expect(g.stars, greaterThan(0));
    },
  );

  test('Ateş/Bomba alanındaki yavru patlamaz, kurtulur', () {
    final g = _game(18);
    g.grid = [for (final row in g.grid) List<int?>.filled(row.length, null)];
    g.grid[0][3] = chickCell;
    g.grid[0][4] = 2;
    final saved = g.chicksSaved;
    expect(g.popCells([(0, 3), (0, 4)]), 1, reason: 'yavru sayılmaz');
    expect(g.chicksSaved, saved + 1);
    expect(g.grid[0][3], isNull);
  });

  test('yıldız sandığı yeni yıldızlarla dolar ve açılır', () {
    expect(Progress.starChest, 0);
    Progress.recordWin(1, 2, 100);
    expect(Progress.starChest, 2);
    Progress.recordWin(1, 2, 100); // aynı yıldız: sayılmaz
    expect(Progress.starChest, 2);
    Progress.recordWin(1, 3, 100); // +1 yeni yıldız
    expect(Progress.starChest, 3);
    expect(Progress.starChestReady, isFalse);
    expect(Progress.openStarChest(), isNull);
    for (var l = 2; l <= 8; l++) {
      Progress.recordWin(l, 3, 100);
    }
    expect(Progress.starChest, 24);
    expect(Progress.starChestReady, isTrue);
    final coins = Progress.coins;
    final r = Progress.openStarChest()!;
    expect(Progress.coins, coins + r.coins);
    expect(Progress.starChest, 4, reason: 'artan yıldız bir sonrakine kalır');
    expect(Progress.starChestsOpened, 1);
    final j = Progress.toJson();
    Progress.resetLocal();
    expect(Progress.starChest, 0);
    Progress.fromJson(j);
    expect(Progress.starChest, 4);
    expect(Progress.starChestsOpened, 1);
  });
}
