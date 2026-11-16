import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'game.dart';

/// Oyuncuya verilen ödül paketi (çark, görev, seri, mağaza).
class Reward {
  const Reward({
    this.coins = 0,
    this.boosters = const {},
    this.infiniteMinutes = 0,
    this.refillLives = false,
  });
  final int coins;
  final Map<Booster, int> boosters;
  final int infiniteMinutes;
  final bool refillLives;
}

String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String get todayKey => dayKey(DateTime.now());

/// ISO hafta anahtarı (UTC), Postgres `to_char(.., 'IYYY-"W"IW')` ile aynı.
String isoWeekKey(DateTime d) {
  final date = DateTime.utc(d.year, d.month, d.day);
  final thursday = date.add(Duration(days: 4 - date.weekday));
  final week =
      thursday.difference(DateTime.utc(thursday.year, 1, 1)).inDays ~/ 7 + 1;
  return '${thursday.year}-W${week.toString().padLeft(2, '0')}';
}

String get yesterdayKey =>
    dayKey(DateTime.now().subtract(const Duration(days: 1)));

/// Oyuncu ilerlemesi ve ekonomi: altın, bölümler, güçlendiriciler, canlar,
/// günlük çark, giriş serisi, görev istatistikleri, mağaza.
class Progress {
  static SharedPreferences? _p;

  // ---- bölümler ----
  static int coins = 500;
  static int unlocked = 1;
  static final Map<int, int> stars = {};
  static final Map<int, int> bestScores = {};
  static final Map<Booster, int> boosters = {
    for (final b in Booster.values) b: 1,
  };

  // ---- canlar ----
  static const maxLives = 5;
  static const lifeRegen = Duration(minutes: 30);
  static int lives = maxLives;
  static int lifeTs = 0; // bir sonraki canın sayılmaya başladığı an (ms)
  static int infiniteUntil = 0; // sonsuz can bitiş anı (ms)

  // ---- günlük ----
  static String lastSpinDay = '';
  static int streakCount = 0;
  static String lastStreakDay = '';
  static String freeGiftDay = '';
  static bool starterBought = false;
  static String statsDay = '';
  static final Map<String, int> stats = {};
  static final Set<String> claimedQuests = {};

  /// Atıcı temaları (kozmetik) ve günün fırsatının alındığı gün.
  static String skin = 'altin';
  static final Set<String> ownedSkins = {'altin'};
  static String dealDay = '';

  /// Kazanma serisi: art arda kazanılan bölüm sayısı. Kaybedince sıfırlanır.
  /// 1: +3 hamle, 2: + Gökkuşağı, 3+: + Bomba (bölüm başında ücretsiz).
  static int winStreak = 0;
  static int get streakTier => min(3, winStreak);

  /// Sonsuz mod rekoru ve oyun sayısı.
  static int endlessBest = 0, endlessGames = 0;

  /// Sonsuz mod açılış bölümü.
  static const endlessUnlock = 10;

  /// Sonsuz mod oyununu kaydeder; kazanılan altını döner (puan/200, en çok
  /// 100) ve yeni rekorsa [endlessBest] güncellenir.
  static int recordEndless(int score) {
    endlessGames++;
    if (score > endlessBest) endlessBest = score;
    final coinsWon = min(100, score ~/ 200);
    coins += coinsWon;
    addStat('endless');
    save();
    return coinsWon;
  }

  /// Günün meydan okumasının en son bitirildiği gün ve açılan bölge sandıkları.
  static String dailyDoneDay = '';
  static final Set<int> regionChests = {};

  static bool get dailyAvailable => dailyDoneDay != todayKey;

  /// Günlük meydan okuma ödülü (haftanın gününe göre güçlendirici değişir).
  static Reward get dailyReward {
    const cycle = [Booster.rainbow, Booster.fire, Booster.laser, Booster.moves];
    return Reward(
      coins: 300,
      boosters: {cycle[DateTime.now().weekday % cycle.length]: 1},
    );
  }

  /// Günlük meydan okuma kazanıldı: ödülü ver, bilet XP'si ekle.
  static Reward completeDaily() {
    final r = dailyReward;
    dailyDoneDay = todayKey;
    grant(r);
    addStat('daily');
    addPassXp(40);
    save();
    return r;
  }

  /// Bölge sandığı: bölgenin 10 bölümü bitince açılır.
  static bool regionChestReady(int region) =>
      unlocked > (region + 1) * 10 && !regionChests.contains(region);

  static Reward regionChestReward(int region) => Reward(
    coins: 200 + region * 25,
    boosters: {
      [Booster.rainbow, Booster.fire, Booster.laser][region % 3]: 1,
      if (region % 2 == 1) Booster.moves: 1,
    },
  );

  static Reward? openRegionChest(int region) {
    if (!regionChestReady(region)) return null;
    regionChests.add(region);
    final r = regionChestReward(region);
    grant(r);
    save();
    return r;
  }

  /// Ömür boyu sayaçlar ve alınmış başarım ödülleri.
  static final Map<String, int> lifetime = {};
  static final Set<String> claimedAch = {};

  // ---- fiyatlar ----
  static const boosterPrice = 200;
  static const extraMovesPrice = 300;
  static const rescuePrice = 300;
  static const refillPrice = 900;
  static const extraSpinPrice = 150;

  static int get _now => DateTime.now().millisecondsSinceEpoch;

  // ---- haftalık (lig + takım sandığı) ----
  static String weekKey = '';
  static int weeklyScore = 0;
  static int weeklyStars = 0;

  /// Hesap bağlama hoş geldin paketi verildi mi?
  static bool welcomeGiven = false;

  /// Bubble Pass (aylık sezon bileti).
  static String passSeason = '';
  static int passXp = 0;
  static bool passGold = false;
  static final Set<int> passFreeClaimed = {};
  static final Set<int> passGoldClaimed = {};

  /// Son bölüm galibiyetinde kazanılan bilet XP'si (zafer ekranında gösterilir).
  static int lastPassXp = 0;

  /// Son kaydın zamanı (ms) — bulut eşitlemesinde hangisinin yeni olduğunu belirler.
  static int savedAt = 0;

  /// Her kayıttan sonra çağrılır (bulut eşitlemesi buraya bağlanır).
  static void Function()? onSaved;

  static Future<void> load() async {
    final p = _p = await SharedPreferences.getInstance();
    final raw = p.getString('state');
    if (raw != null) {
      fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } else {
      _loadLegacy(p);
    }
    tickLives();
  }

  /// Tüm ilerleme tek bir JSON nesnesi olarak (telefon + bulut).
  static Map<String, dynamic> toJson() => {
    'v': 1,
    'savedAt': savedAt,
    'coins': coins,
    'unlocked': unlocked,
    'stars': {for (final e in stars.entries) '${e.key}': e.value},
    'best': {for (final e in bestScores.entries) '${e.key}': e.value},
    'boosters': {for (final e in boosters.entries) e.key.name: e.value},
    'lives': lives,
    'lifeTs': lifeTs,
    'infiniteUntil': infiniteUntil,
    'lastSpinDay': lastSpinDay,
    'streakCount': streakCount,
    'lastStreakDay': lastStreakDay,
    'freeGiftDay': freeGiftDay,
    'starterBought': starterBought,
    'statsDay': statsDay,
    'stats': Map.of(stats),
    'claimedQuests': claimedQuests.toList(),
    'weekKey': weekKey,
    'weeklyScore': weeklyScore,
    'weeklyStars': weeklyStars,
    'welcomeGiven': welcomeGiven,
    'passSeason': passSeason,
    'passXp': passXp,
    'passGold': passGold,
    'winStreak': winStreak,
    'endlessBest': endlessBest,
    'endlessGames': endlessGames,
    'skin': skin,
    'ownedSkins': ownedSkins.toList(),
    'dealDay': dealDay,
    'dailyDoneDay': dailyDoneDay,
    'regionChests': regionChests.toList(),
    'lifetime': Map.of(lifetime),
    'claimedAch': claimedAch.toList(),
    'passFree': passFreeClaimed.toList(),
    'passGoldClaimed': passGoldClaimed.toList(),
  };

  static void fromJson(Map<String, dynamic> j) {
    int i(String k, int d) => (j[k] as num?)?.toInt() ?? d;
    String s(String k) => j[k] as String? ?? '';
    savedAt = i('savedAt', 0);
    coins = i('coins', 500);
    unlocked = i('unlocked', 1);
    stars
      ..clear()
      ..addAll({
        for (final e in (j['stars'] as Map? ?? {}).entries)
          int.parse('${e.key}'): (e.value as num).toInt(),
      });
    bestScores
      ..clear()
      ..addAll({
        for (final e in (j['best'] as Map? ?? {}).entries)
          int.parse('${e.key}'): (e.value as num).toInt(),
      });
    final b = j['boosters'] as Map? ?? {};
    for (final x in Booster.values) {
      boosters[x] = (b[x.name] as num?)?.toInt() ?? 1;
    }
    lives = i('lives', maxLives);
    lifeTs = i('lifeTs', 0);
    infiniteUntil = i('infiniteUntil', 0);
    lastSpinDay = s('lastSpinDay');
    streakCount = i('streakCount', 0);
    lastStreakDay = s('lastStreakDay');
    freeGiftDay = s('freeGiftDay');
    starterBought = j['starterBought'] as bool? ?? false;
    statsDay = s('statsDay');
    stats
      ..clear()
      ..addAll({
        for (final e in (j['stats'] as Map? ?? {}).entries)
          '${e.key}': (e.value as num).toInt(),
      });
    claimedQuests
      ..clear()
      ..addAll([for (final x in (j['claimedQuests'] as List? ?? [])) '$x']);
    weekKey = s('weekKey');
    weeklyScore = i('weeklyScore', 0);
    weeklyStars = i('weeklyStars', 0);
    welcomeGiven = j['welcomeGiven'] as bool? ?? false;
    winStreak = i('winStreak', 0);
    endlessBest = i('endlessBest', 0);
    endlessGames = i('endlessGames', 0);
    skin = j['skin'] as String? ?? 'altin';
    ownedSkins
      ..clear()
      ..add('altin')
      ..addAll([for (final x in (j['ownedSkins'] as List? ?? [])) '$x']);
    dealDay = s('dealDay');
    dailyDoneDay = s('dailyDoneDay');
    regionChests
      ..clear()
      ..addAll([
        for (final x in (j['regionChests'] as List? ?? [])) (x as num).toInt(),
      ]);
    lifetime
      ..clear()
      ..addAll({
        for (final e in (j['lifetime'] as Map? ?? {}).entries)
          '${e.key}': (e.value as num).toInt(),
      });
    claimedAch
      ..clear()
      ..addAll([for (final x in (j['claimedAch'] as List? ?? [])) '$x']);
    passSeason = s('passSeason');
    passXp = i('passXp', 0);
    passGold = j['passGold'] as bool? ?? false;
    passFreeClaimed
      ..clear()
      ..addAll([
        for (final x in (j['passFree'] as List? ?? [])) (x as num).toInt(),
      ]);
    passGoldClaimed
      ..clear()
      ..addAll([
        for (final x in (j['passGoldClaimed'] as List? ?? []))
          (x as num).toInt(),
      ]);
  }

  // ================= Bubble Pass =================

  static const passTiers = 30;
  static const passXpPerTier = 60;

  static String get currentSeasonKey {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}';
  }

  /// Yeni ay başladıysa bileti sıfırlar.
  static void rollPass() {
    final k = currentSeasonKey;
    if (passSeason == k) return;
    passSeason = k;
    passXp = 0;
    passGold = false;
    passFreeClaimed.clear();
    passGoldClaimed.clear();
  }

  /// Ulaşılan kademe (0–30).
  static int get passTier {
    rollPass();
    return min(passTiers, passXp ~/ passXpPerTier);
  }

  static void addPassXp(int xp) {
    rollPass();
    passXp += xp;
    lastPassXp = xp;
  }

  static bool passClaimable(int tier, {required bool gold}) =>
      tier <= passTier &&
      (gold
          ? passGold && !passGoldClaimed.contains(tier)
          : !passFreeClaimed.contains(tier));

  static int get passReadyCount {
    var n = 0;
    for (var t = 1; t <= passTier; t++) {
      if (passClaimable(t, gold: false)) n++;
      if (passClaimable(t, gold: true)) n++;
    }
    return n;
  }

  static void activateGoldPass() {
    rollPass();
    passGold = true;
    save();
  }

  /// Telefondaki kaydı sıfırlar (çıkış yapınca yeni misafir için).
  static void resetLocal() {
    fromJson({});
    savedAt = 0;
    save();
  }

  static void _rollWeek() {
    final w = isoWeekKey(DateTime.now().toUtc());
    if (weekKey == w) return;
    weekKey = w;
    weeklyScore = 0;
    weeklyStars = 0;
  }

  static int get currentWeeklyScore {
    _rollWeek();
    return weeklyScore;
  }

  static int get currentWeeklyStars {
    _rollWeek();
    return weeklyStars;
  }

  static void _loadLegacy(SharedPreferences p) {
    fromJson({}); // eski kayıtta olmayan alanlar varsayılana dönsün
    coins = p.getInt('coins') ?? 500;
    unlocked = p.getInt('unlocked') ?? 1;
    stars.clear();
    bestScores.clear();
    for (final s in p.getStringList('stars') ?? const <String>[]) {
      final parts = s.split(':');
      if (parts.length == 3) {
        stars[int.parse(parts[0])] = int.parse(parts[1]);
        bestScores[int.parse(parts[0])] = int.parse(parts[2]);
      }
    }
    for (final b in Booster.values) {
      boosters[b] = p.getInt('booster_${b.name}') ?? 1;
    }
    lives = p.getInt('lives') ?? maxLives;
    lifeTs = p.getInt('lifeTs') ?? 0;
    infiniteUntil = p.getInt('infiniteUntil') ?? 0;
    lastSpinDay = p.getString('lastSpinDay') ?? '';
    streakCount = p.getInt('streakCount') ?? 0;
    lastStreakDay = p.getString('lastStreakDay') ?? '';
    freeGiftDay = p.getString('freeGiftDay') ?? '';
    starterBought = p.getBool('starterBought') ?? false;
    statsDay = p.getString('statsDay') ?? '';
    stats.clear();
    for (final s in p.getStringList('stats') ?? const <String>[]) {
      final i = s.indexOf('=');
      if (i > 0) stats[s.substring(0, i)] = int.parse(s.substring(i + 1));
    }
    claimedQuests
      ..clear()
      ..addAll(p.getStringList('claimedQuests') ?? const []);
  }

  static void save({bool notify = true}) {
    savedAt = _now;
    _p?.setString('state', jsonEncode(toJson()));
    if (notify) onSaved?.call();
  }

  // ================= bölümler =================

  /// Bölüm kazanıldığında çağrılır; kazanılan altını döndürür.
  static int recordWin(int level, int starCount, int score) {
    final firstTime = !stars.containsKey(level);
    stars[level] = max(stars[level] ?? 0, starCount);
    bestScores[level] = max(bestScores[level] ?? 0, score);
    if (level >= unlocked) unlocked = min(level + 1, maxLevel);
    final reward =
        (firstTime ? 40 + LevelConfig.forLevel(level).bonusCoins : 10) +
        starCount * 10;
    coins += reward;
    addStat('win');
    if (starCount == 3) addStat('star3');
    _rollWeek();
    weeklyScore += score;
    weeklyStars += starCount;
    // bilet XP: galibiyet 10 + yıldız başına 10
    addPassXp(10 + starCount * 10);
    winStreak++;
    save();
    return reward;
  }

  static int get totalStars => stars.values.fold(0, (a, b) => a + b);
  static int get totalScore => bestScores.values.fold(0, (a, b) => a + b);

  static bool spend(int amount) {
    if (coins < amount) return false;
    coins -= amount;
    save();
    return true;
  }

  static void useBooster(Booster b) {
    boosters[b] = max(0, boosters[b]! - 1);
    addStat('booster');
    save();
  }

  static bool buyBooster(Booster b, {int count = 1, int? price}) {
    if (!spend(price ?? boosterPrice)) return false;
    boosters[b] = boosters[b]! + count;
    save();
    return true;
  }

  static void grant(Reward r) {
    coins += r.coins;
    r.boosters.forEach((b, n) => boosters[b] = boosters[b]! + n);
    if (r.infiniteMinutes > 0) {
      infiniteUntil = max(_now, infiniteUntil) + r.infiniteMinutes * 60 * 1000;
    }
    if (r.refillLives) lives = maxLives;
    save();
  }

  // ================= canlar =================

  static bool get infinite => _now < infiniteUntil;

  static Duration get infiniteLeft =>
      Duration(milliseconds: max(0, infiniteUntil - _now));

  /// Geçen süreye göre dolan canları ekler.
  static void tickLives() {
    if (lives >= maxLives) return;
    final regen = lifeRegen.inMilliseconds;
    var changed = false;
    while (lives < maxLives && _now - lifeTs >= regen) {
      lives++;
      lifeTs += regen;
      changed = true;
    }
    if (changed) save();
  }

  /// Sonraki canın dolmasına kalan süre (canlar doluysa null).
  static Duration? get nextLifeIn {
    tickLives();
    if (lives >= maxLives) return null;
    return Duration(
      milliseconds: max(0, lifeRegen.inMilliseconds - (_now - lifeTs)),
    );
  }

  static bool get canPlay {
    if (infinite) return true;
    tickLives();
    return lives > 0;
  }

  static void loseLife() {
    if (infinite) return;
    tickLives();
    if (lives >= maxLives) lifeTs = _now;
    lives = max(0, lives - 1);
    save();
  }

  static bool refillLives() {
    if (lives >= maxLives || !spend(refillPrice)) return false;
    lives = maxLives;
    save();
    return true;
  }

  // ================= günlük çark =================

  static bool get freeSpinAvailable => lastSpinDay != todayKey;

  static void useFreeSpin() {
    lastSpinDay = todayKey;
    save();
  }

  // ================= giriş serisi =================

  static bool get streakClaimable => lastStreakDay != todayKey;

  /// Bugün alınacak (ya da alınmış) seri günü, 1..7.
  static int get streakDayToday {
    if (!streakClaimable) return streakCount;
    final continues = lastStreakDay == yesterdayKey && streakCount < 7;
    return continues ? streakCount + 1 : 1;
  }

  static Reward streakReward(int day) => switch (day) {
    1 => const Reward(coins: 50),
    2 => const Reward(coins: 75),
    3 => const Reward(coins: 100, boosters: {Booster.laser: 1}),
    4 => const Reward(coins: 150),
    5 => const Reward(coins: 200, boosters: {Booster.fire: 1}),
    6 => const Reward(coins: 250, boosters: {Booster.moves: 1}),
    _ => const Reward(
      coins: 500,
      infiniteMinutes: 60,
      boosters: {
        Booster.moves: 1,
        Booster.rainbow: 1,
        Booster.fire: 1,
        Booster.laser: 1,
      },
    ),
  };

  static Reward? claimStreak() {
    if (!streakClaimable) return null;
    final day = streakDayToday;
    streakCount = day;
    lastStreakDay = todayKey;
    final r = streakReward(day);
    grant(r);
    return r;
  }

  // ================= görev istatistikleri =================

  static void _rollDay() {
    if (statsDay == todayKey) return;
    statsDay = todayKey;
    stats.clear();
    claimedQuests.clear();
  }

  static void addStat(String key, [int v = 1]) {
    _rollDay();
    stats[key] = (stats[key] ?? 0) + v;
    if (!key.startsWith('pop_c') && key != 'ad_coins') {
      lifetime[key] = (lifetime[key] ?? 0) + v;
    }
  }

  /// Hiç sıfırlanmayan toplam sayaçlar (başarımlar için).
  static int life(String key) => lifetime[key] ?? 0;

  static int stat(String key) {
    _rollDay();
    return stats[key] ?? 0;
  }

  static bool isClaimed(String id) {
    _rollDay();
    return claimedQuests.contains(id);
  }

  static void markClaimed(String id) {
    _rollDay();
    claimedQuests.add(id);
    save();
  }

  // ================= mağaza =================

  static bool get freeGiftAvailable => freeGiftDay != todayKey;

  static void claimFreeGift() {
    freeGiftDay = todayKey;
    grant(const Reward(coins: 100));
  }
}
