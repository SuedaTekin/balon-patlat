import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:balon_patlat/game.dart';

BubbleGame newGame([int level = 1]) =>
    BubbleGame(LevelConfig.forLevel(level))..layout(const Size(392, 640));

void settle(BubbleGame g) {
  for (var i = 0; i < 400 && g.ballPos != null; i++) {
    g.update(1 / 60);
  }
}

void clearGrid(BubbleGame g) {
  for (final row in g.grid) {
    row.fillRange(0, row.length, null);
  }
}

void main() {
  test('bölüm aynı seviyede hep aynı dizilimle başlar', () {
    final a = newGame(5), b = newGame(5);
    expect(a.grid, b.grid);
    expect(a.movesLeft, a.totalMoves);
    expect(a.totalMoves, greaterThanOrEqualTo(12));
  });

  test('atış hamle düşürür ve ızgaraya oturur', () {
    final g = newGame();
    final moves = g.movesLeft;
    g.aimAt(g.shooter + const Offset(0, -100));
    g.fire();
    settle(g);
    expect(g.ballPos, isNull);
    expect(g.movesLeft, moves - 1);
  });

  test('aynı renkten üçlü patlar, son balon gidince bölüm kazanılır', () {
    final g = newGame();
    clearGrid(g);
    g.grid[0][0] = 0;
    g.grid[0][1] = 0;
    g.current = 0;
    g.aimAt(g.cellCenter(0, 2));
    g.fire();
    settle(g);
    expect(g.bubbleCount, 0);
    expect(g.state, GameState.won);
    expect(g.stars, 3);
  });

  test('hamle bitince kaybedilir, ek hamle ile devam edilir', () {
    final g = newGame();
    g.movesLeft = 1;
    g.current = 0;
    clearGrid(g);
    g.grid[0][0] = 1;
    g.grid[0][7] = 2;
    g.aimAt(g.cellCenter(0, 4));
    g.fire();
    settle(g);
    expect(g.state, GameState.lostMoves);
    g.addMoves(5);
    expect(g.state, GameState.playing);
    expect(g.movesLeft, 5);
  });

  test('ateş topu yolundaki balonları yakar', () {
    final g = newGame();
    final before = g.bubbleCount;
    g.armed = ShotKind.fire;
    g.aimAt(g.shooter + const Offset(0, -100));
    g.fire();
    settle(g);
    expect(g.bubbleCount, lessThan(before - 3));
  });

  test('lazer çarptığı sırayı siler', () {
    final g = newGame();
    clearGrid(g);
    for (var c = 0; c < 8; c++) {
      g.grid[0][c] = c % 3;
    }
    g.armed = ShotKind.laser;
    g.aimAt(g.cellCenter(0, 4));
    g.fire();
    settle(g);
    expect(g.bubbleCount, 0);
  });

  test('gökkuşağı komşu kümeye uyup patlatır', () {
    final g = newGame();
    clearGrid(g);
    g.grid[0][3] = 2;
    g.grid[0][4] = 2;
    g.grid[0][0] = 1;
    g.current = 0;
    g.armed = ShotKind.rainbow;
    g.aimAt(g.cellCenter(1, 3) + const Offset(0, 4));
    g.fire();
    settle(g);
    expect(g.grid[0][3], isNull);
    expect(g.grid[0][4], isNull);
  });
}
