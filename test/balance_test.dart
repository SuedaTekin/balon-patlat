import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:balon_patlat/game.dart';

/// Açgözlü bot: her açıyı (ve takası) dener, en çok balon eksilten atışı seçer.
int botPlay(BubbleGame g, {int limit = 400}) {
  var used = 0;
  while (g.bubbleCount > 0 && used < limit) {
    var bestScore = -1e9;
    var bestAngle = -pi / 2;
    var bestSwap = false;
    for (final swap in [false, true]) {
      for (var i = 0; i <= 48; i++) {
        final a = -pi + 0.12 + (pi - 0.24) * i / 48;
        final s = g.clone();
        s.movesLeft = 999;
        if (swap) s.swap();
        final before = s.bubbleCount;
        s.aimAngle = a;
        s.fire();
        for (var k = 0; k < 400 && s.ballPos != null; k++) {
          s.update(1 / 60);
        }
        var val = (before - s.bubbleCount).toDouble();
        if (s.state == GameState.lostDanger) val -= 1000;
        if (val > bestScore) {
          bestScore = val;
          bestAngle = a;
          bestSwap = swap;
        }
      }
    }
    g.movesLeft = 999;
    if (bestSwap) g.swap();
    g.aimAngle = bestAngle;
    g.fire();
    for (var k = 0; k < 400 && g.ballPos != null; k++) {
      g.update(1 / 60);
    }
    used++;
    if (g.state == GameState.lostDanger) return 9999;
  }
  return used;
}

void main() {
  test(
    'bölümler verilen hamleyle bitirilebilir',
    () {
      final env = const String.fromEnvironment('LEVELS');
      final levels =
          env.isEmpty
              ? [for (var l = 1; l <= 40; l++) l]
              : env.split(',').map(int.parse).toList();
      final lines = <String>[];
      var fails = 0;
      for (final level in levels) {
        final runs = <int>[];
        int total = 0, count = 0, stones = 0;
        for (var run = 0; run < 3; run++) {
          final g = BubbleGame(LevelConfig.forLevel(level))
            ..layout(const Size(392, 640));
          total = g.totalMoves;
          count = g.initialCount;
          stones = g.stoneCount;
          runs.add(botPlay(g));
        }
        runs.sort();
        final median = runs[1];
        if (median > total) fails++;
        lines.add(
          'L$level balon=$count tas=$stones renk=${LevelConfig.forLevel(level).colors} '
          'hamle=$total bot=$runs ${median > total ? "ZOR" : ""}',
        );
      }
      // ignore: avoid_print
      print(lines.join('\n'));
      // ignore: avoid_print
      print('Botun bitiremediği bölüm: $fails/${levels.length}');
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
