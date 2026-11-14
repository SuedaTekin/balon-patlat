import 'dart:math';

import 'package:balon_patlat/events_tab.dart';
import 'package:balon_patlat/game.dart';
import 'package:balon_patlat/progress.dart';
import 'package:balon_patlat/quests.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

int get now => DateTime.now().millisecondsSinceEpoch;

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Progress.load();
  });

  test('can kaybı ve 30 dakikada dolma', () {
    expect(Progress.lives, 5);
    Progress.loseLife();
    expect(Progress.lives, 4);
    expect(Progress.nextLifeIn!.inMinutes, inInclusiveRange(29, 30));
    // 61 dakika geçmiş gibi
    Progress.lifeTs = now - 61 * 60 * 1000;
    Progress.lives = 3;
    Progress.tickLives();
    expect(Progress.lives, 5);
  });

  test('can 0 iken oynanamaz, altınla dolar', () {
    Progress.lives = 0;
    Progress.lifeTs = now;
    expect(Progress.canPlay, isFalse);
    Progress.coins = 1000;
    expect(Progress.refillLives(), isTrue);
    expect(Progress.lives, 5);
    expect(Progress.coins, 100);
  });

  test('sonsuz can varken can gitmez', () {
    Progress.grant(const Reward(infiniteMinutes: 30));
    expect(Progress.infinite, isTrue);
    Progress.loseLife();
    expect(Progress.lives, 5);
  });

  test('giriş serisi: dün alındıysa devam, alınmadıysa sıfırlanır', () {
    expect(Progress.streakDayToday, 1);
    Progress.lastStreakDay = yesterdayKey;
    Progress.streakCount = 3;
    expect(Progress.streakDayToday, 4);
    final coins = Progress.coins;
    Progress.claimStreak();
    expect(Progress.coins, coins + 150);
    expect(Progress.streakClaimable, isFalse);

    Progress.lastStreakDay = '2000-01-01';
    Progress.streakCount = 5;
    expect(Progress.streakDayToday, 1);
  });

  test('günlük çark tek ücretsiz hak verir', () {
    expect(Progress.freeSpinAvailable, isTrue);
    Progress.useFreeSpin();
    expect(Progress.freeSpinAvailable, isFalse);
    final counts = List.filled(spinSlices.length, 0);
    final rnd = Random(1);
    for (var i = 0; i < 5000; i++) {
      counts[pickSlice(rnd)]++;
    }
    expect(counts.every((c) => c > 0), isTrue);
    expect(counts[0], lessThan(counts.last)); // jackpot nadir
  });

  test('görevler: 3 farklı görev, ilerleme ve ödül', () {
    final qs = dailyQuests();
    expect(qs.length, 3);
    expect(qs.map((q) => q.id).toSet().length, 3);
    final q = qs.first;
    expect(q.ready, isFalse);
    Progress.addStat(q.stat, q.target);
    expect(q.ready, isTrue);
    Progress.markClaimed(q.id);
    expect(q.claimed, isTrue);
    expect(bonusReady, isFalse);
    for (final x in qs) {
      Progress.markClaimed(x.id);
    }
    expect(bonusReady, isTrue);
  });

  test('ISO hafta anahtarı Postgres ile aynı biçimde', () {
    expect(isoWeekKey(DateTime.utc(2026, 11, 13)), '2026-W46');
    expect(isoWeekKey(DateTime.utc(2027, 1, 1)), '2026-W53');
    expect(isoWeekKey(DateTime.utc(2025, 12, 29)), '2026-W01');
  });

  test('haftalık puan bölüm kazanınca birikir', () {
    Progress.recordWin(1, 3, 1200);
    Progress.recordWin(2, 2, 800);
    expect(Progress.currentWeeklyScore, 2000);
    expect(Progress.currentWeeklyStars, 5);
    Progress.weekKey = '2000-W01'; // eski hafta → sıfırlanır
    expect(Progress.currentWeeklyScore, 0);
  });

  test('JSON kaydı gidip gelince aynı kalır (bulut eşitlemesi)', () {
    Progress.coins = 777;
    Progress.stars[3] = 2;
    Progress.bestScores[3] = 4500;
    Progress.boosters[Booster.laser] = 4;
    Progress.welcomeGiven = true;
    final j = Progress.toJson();
    Progress.resetLocal();
    expect(Progress.coins, 500);
    Progress.fromJson(j);
    expect(Progress.coins, 777);
    expect(Progress.stars[3], 2);
    expect(Progress.bestScores[3], 4500);
    expect(Progress.boosters[Booster.laser], 4);
    expect(Progress.welcomeGiven, isTrue);
  });

  test('Bubble Pass: XP, kademe, ödül alma, yeni sezonda sıfırlanma', () {
    expect(Progress.passTier, 0);
    Progress.recordWin(1, 3, 1000); // 10 + 3*10 = 40 XP
    expect(Progress.lastPassXp, 40);
    Progress.recordWin(2, 2, 800); // +30 → 70 XP = kademe 1
    expect(Progress.passTier, 1);
    expect(Progress.passClaimable(1, gold: false), isTrue);
    expect(Progress.passClaimable(1, gold: true), isFalse); // bilet yok
    Progress.activateGoldPass();
    expect(Progress.passClaimable(1, gold: true), isTrue);
    expect(Progress.passReadyCount, 2);
    Progress.passFreeClaimed.add(1);
    expect(Progress.passReadyCount, 1);
    // JSON gidip gelince korunur
    final j = Progress.toJson();
    Progress.resetLocal();
    Progress.fromJson(j);
    expect(Progress.passGold, isTrue);
    expect(Progress.passFreeClaimed, contains(1));
    // eski sezon → sıfırlanır
    Progress.passSeason = '2000-01';
    expect(Progress.passTier, 0);
    expect(Progress.passGold, isFalse);
  });

  test('kayıt yeniden yüklenince korunur', () async {
    Progress.coins = 1234;
    Progress.lives = 2;
    Progress.boosters[Booster.fire] = 7;
    Progress.addStat('pop', 42);
    Progress.save();
    await Progress.load();
    expect(Progress.coins, 1234);
    expect(Progress.boosters[Booster.fire], 7);
    expect(Progress.stat('pop'), 42);
  });
}
