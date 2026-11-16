import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../game.dart';
import '../progress.dart';
import 'config.dart';

String get currentWeek => isoWeekKey(DateTime.now().toUtc());

class Profile {
  Profile(this.j);
  final Map<String, dynamic> j;

  String get id => j['id'] as String;
  String get username => j['username'] as String? ?? 'Oyuncu';
  int get avatar => (j['avatar'] as num?)?.toInt() ?? 0;
  String get friendCode => j['friend_code'] as String? ?? '';
  int get level => (j['level'] as num?)?.toInt() ?? 1;
  int get totalStars => (j['total_stars'] as num?)?.toInt() ?? 0;
  int get totalScore => (j['total_score'] as num?)?.toInt() ?? 0;
  bool get thisWeek => j['week'] == currentWeek;
  int get weeklyScore =>
      thisWeek ? (j['weekly_score'] as num?)?.toInt() ?? 0 : 0;
  int get weeklyStars =>
      thisWeek ? (j['weekly_stars'] as num?)?.toInt() ?? 0 : 0;
  String? get clanId => j['clan_id'] as String?;
  bool get isLeader => j['clan_role'] == 'leader';
}

class Clan {
  Clan(this.j);
  final Map<String, dynamic> j;
  String get id => j['id'] as String;
  String get name => j['name'] as String? ?? '';
  String get description => j['description'] as String? ?? '';
  int get badge => (j['badge'] as num?)?.toInt() ?? 0;
  int get members => (j['members'] as num?)?.toInt() ?? 0;
  int get weeklyStars => (j['weekly_stars'] as num?)?.toInt() ?? 0;
  String? get ownerId => j['owner_id'] as String?;
}

class ClanMessage {
  ClanMessage(this.j);
  final Map<String, dynamic> j;
  int get id => (j['id'] as num).toInt();
  String? get userId => j['user_id'] as String?;
  String get kind => j['kind'] as String? ?? 'chat';
  String get body => j['body'] as String? ?? '';
  List<String> get helpers => [
    for (final h in (j['helpers'] as List? ?? [])) '$h',
  ];
  DateTime get createdAt =>
      DateTime.tryParse(j['created_at'] as String? ?? '')?.toLocal() ??
      DateTime.now();
}

class FriendsData {
  FriendsData(this.friends, this.incoming, this.outgoing);
  final List<Profile> friends, incoming, outgoing;
}

/// Kullanıcıya gösterilecek Türkçe hata.
class CloudError implements Exception {
  CloudError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Haftalık takım sandığı kademeleri (sunucudaki claim_chest ile aynı).
const chestTiers = [100, 250, 500];
const chestRewards = [
  Reward(coins: 200),
  Reward(coins: 400, boosters: {Booster.rainbow: 1}),
  Reward(
    coins: 800,
    infiniteMinutes: 60,
    boosters: {
      Booster.moves: 1,
      Booster.rainbow: 1,
      Booster.fire: 1,
      Booster.laser: 1,
    },
  ),
];
const clanCreatePrice = 500;
const welcomeReward = Reward(coins: 500, boosters: {Booster.rainbow: 1});

/// Supabase bağlantısı: oturum, bulut kayıt, sıralama, arkadaş, takım.
class Cloud {
  static bool enabled = false;
  static bool online = false;
  static Profile? me;
  static FriendsData? friendsCache;

  /// Arayüzü yenilemek için (profil/oturum değişti).
  static final changes = ValueNotifier<int>(0);
  static Timer? _debounce;

  static SupabaseClient get sb => Supabase.instance.client;
  static User? get user => enabled ? sb.auth.currentUser : null;
  static String? get uid => user?.id;
  static bool get isGuest => user?.isAnonymous ?? true;
  static String? get email => user?.email;

  static void _notify() => changes.value++;

  static Future<void> init() async {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) return;
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseAnonKey,
      );
      enabled = true;
    } catch (e) {
      debugPrint('Supabase başlatılamadı: $e');
      return;
    }
    Progress.onSaved = scheduleSync;
    unawaited(connect());
  }

  /// Oturum aç (yoksa misafir), profili al, kaydı eşitle.
  static Future<bool> connect() async {
    if (!enabled) return false;
    try {
      if (sb.auth.currentSession == null) {
        await sb.auth.signInAnonymously();
      }
      await refreshProfile();
      await _reconcile();
      online = true;
    } catch (e) {
      debugPrint('Bulut bağlantısı yok: $e');
      online = false;
    }
    _notify();
    return online;
  }

  static Future<void> _ensure() async {
    if (!enabled) throw CloudError('Sunucu ayarlanmamış.');
    if (!online || me == null) {
      if (!await connect()) {
        throw CloudError('Sunucuya bağlanılamadı. İnternetini kontrol et.');
      }
    }
  }

  static Future<void> refreshProfile() async {
    var r = await sb.from('profiles').select().eq('id', uid!).maybeSingle();
    if (r == null) {
      await sb.from('profiles').insert({
        'id': uid,
        'username':
            'Oyuncu${uid!.replaceAll('-', '').substring(0, 6).toUpperCase()}',
      });
      r = await sb.from('profiles').select().eq('id', uid!).single();
    }
    me = Profile(r);
  }

  /// Bulut ve telefon kaydından yeni olan kazanır.
  static Future<void> _reconcile() async {
    final row =
        await sb.from('saves').select().eq('user_id', uid!).maybeSingle();
    if (row != null) {
      final data = Map<String, dynamic>.from(row['data'] as Map);
      final cloudAt = (data['savedAt'] as num?)?.toInt() ?? 0;
      if (cloudAt > Progress.savedAt) {
        Progress.fromJson(data);
        Progress.save(notify: false);
        _notify();
        await _pushProfileStats();
        return;
      }
    }
    await syncNow();
  }

  static void scheduleSync() {
    if (!enabled) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 4), () => syncNow());
  }

  static Future<void> syncNow() async {
    if (!enabled || uid == null) return;
    try {
      await sb.from('saves').upsert({
        'user_id': uid,
        'data': Progress.toJson(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      await _pushProfileStats();
      online = true;
    } catch (e) {
      debugPrint('Eşitleme başarısız: $e');
      online = false;
    }
  }

  static Future<void> _pushProfileStats() async {
    final r =
        await sb
            .from('profiles')
            .update({
              'level': Progress.unlocked,
              'total_stars': Progress.totalStars,
              'total_score': Progress.totalScore,
              'week': currentWeek,
              'weekly_score': Progress.currentWeeklyScore,
              'weekly_stars': Progress.currentWeeklyStars,
            })
            .eq('id', uid!)
            .select()
            .maybeSingle();
    if (r != null) me = Profile(r);
  }

  // ======================= HESAP =======================

  static String _authMsg(Object e) {
    final m = e is AuthException ? e.message.toLowerCase() : '$e'.toLowerCase();
    if (m.contains('invalid login')) return 'E-posta veya şifre hatalı.';
    if (m.contains('already') && m.contains('registered')) {
      return 'Bu e-posta zaten kayıtlı. "Giriş Yap" sekmesini kullan.';
    }
    if (m.contains('rate limit') || m.contains('too many')) {
      return 'Çok fazla deneme. Biraz bekleyip tekrar dene.';
    }
    if (m.contains('expired') || m.contains('invalid') && m.contains('token')) {
      return 'Kod hatalı veya süresi dolmuş.';
    }
    if (m.contains('password') && m.contains('6')) {
      return 'Şifre en az 6 karakter olmalı.';
    }
    if (m.contains('email') && m.contains('invalid')) {
      return 'Geçerli bir e-posta adresi gir.';
    }
    if (m.contains('socket') || m.contains('network') || m.contains('host')) {
      return 'İnternet bağlantısı yok.';
    }
    return e is AuthException ? e.message : 'Bir hata oluştu: $e';
  }

  static Future<T> _guard<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on CloudError {
      rethrow;
    } catch (e) {
      throw CloudError(_authMsg(e));
    }
  }

  /// Misafir hesabına e-posta bağla — 1. adım: doğrulama kodu gönder.
  static Future<void> linkEmailStart(String email) => _guard(() async {
    await _ensure();
    await sb.auth.updateUser(UserAttributes(email: email.trim()));
  });

  /// 2. adım: kodu doğrula ve şifreyi belirle.
  static Future<void> linkEmailVerify(
    String email,
    String code,
    String password,
  ) => _guard(() async {
    await sb.auth.verifyOTP(
      type: OtpType.emailChange,
      email: email.trim(),
      token: code.trim(),
    );
    await sb.auth.updateUser(UserAttributes(password: password));
    await refreshProfile();
    if (!Progress.welcomeGiven) {
      Progress.welcomeGiven = true;
      Progress.grant(welcomeReward);
    }
    await syncNow();
    _notify();
  });

  static bool get googleReady => enabled && googleWebClientId.isNotEmpty;

  static bool get isGoogle =>
      user?.identities?.any((i) => i.provider == 'google') ?? false;

  /// Google ile devam et. Misafirsen Google hesabın bu misafir hesabına
  /// bağlanır (ilerleme korunur); Google hesabı zaten kayıtlıysa o hesaba
  /// geçilir ve buluttaki ilerleme yüklenir. İptal edilirse false döner.
  static Future<bool> signInWithGoogle() => _guard(() async {
    if (!googleReady) {
      throw CloudError('Google ile giriş henüz ayarlanmadı.');
    }
    final gs = GoogleSignIn(
      serverClientId: googleWebClientId,
      scopes: const ['email'],
    );
    await gs.signOut(); // her seferinde hesap seçtir
    final acc = await gs.signIn();
    if (acc == null) return false;
    final auth = await acc.authentication;
    final idToken = auth.idToken;
    if (idToken == null) throw CloudError('Google kimliği alınamadı.');
    await _ensure();
    if (isGuest) {
      try {
        await sb.auth.linkIdentityWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
          accessToken: auth.accessToken,
        );
        await sb.auth.refreshSession();
        await refreshProfile();
        if (!Progress.welcomeGiven) {
          Progress.welcomeGiven = true;
          Progress.grant(welcomeReward);
        }
        await syncNow();
        _notify();
        return true;
      } on AuthException catch (e) {
        final m = e.message.toLowerCase();
        if (!(m.contains('already') || m.contains('exists'))) rethrow;
        // bu Google hesabı başka bir oyuncuya ait → o hesaba geç
      }
    }
    await syncNow();
    await sb.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: auth.accessToken,
    );
    await _afterAccountSwitch();
    return true;
  });

  /// Var olan hesaba giriş; buluttaki ilerleme bu cihaza yüklenir.
  static Future<void> login(String email, String password) => _guard(() async {
    if (!enabled) throw CloudError('Sunucu ayarlanmamış.');
    await syncNow(); // misafir ilerlemesini kaybetmeden önce yükle
    await sb.auth.signInWithPassword(email: email.trim(), password: password);
    await _afterAccountSwitch();
  });

  static Future<void> _afterAccountSwitch() async {
    await refreshProfile();
    final row =
        await sb.from('saves').select().eq('user_id', uid!).maybeSingle();
    if (row != null) {
      Progress.fromJson(Map<String, dynamic>.from(row['data'] as Map));
      Progress.save(notify: false);
    } else {
      await syncNow();
    }
    online = true;
    friendsCache = null;
    _notify();
  }

  /// Şifremi unuttum — 1. adım: kod gönder.
  static Future<void> sendReset(String email) => _guard(() async {
    if (!enabled) throw CloudError('Sunucu ayarlanmamış.');
    await sb.auth.resetPasswordForEmail(email.trim());
  });

  /// 2. adım: kodu doğrula + yeni şifre; hesaba giriş yapılmış olur.
  static Future<void> verifyReset(
    String email,
    String code,
    String newPassword,
  ) => _guard(() async {
    await syncNow();
    await sb.auth.verifyOTP(
      type: OtpType.recovery,
      email: email.trim(),
      token: code.trim(),
    );
    await sb.auth.updateUser(UserAttributes(password: newPassword));
    await _afterAccountSwitch();
  });

  /// Çıkış: ilerleme buluta yüklenir, cihazda yeni misafir başlar.
  static Future<void> logout() => _guard(() async {
    await syncNow();
    await sb.auth.signOut();
    Progress.resetLocal();
    me = null;
    friendsCache = null;
    await connect();
  });

  /// Hesabı ve buluttaki tüm verileri kalıcı olarak siler (Play Store
  /// hesap silme şartı). Cihazdaki ilerleme sıfırlanır, yeni misafir başlar.
  static Future<void> deleteAccount() => _guard(() async {
    await _ensure();
    await sb.rpc('delete_my_account');
    await sb.auth.signOut();
    Progress.resetLocal();
    me = null;
    friendsCache = null;
    await connect();
  });

  static Future<void> updateProfile({String? username, int? avatar}) =>
      _guard(() async {
        await _ensure();
        final upd = <String, dynamic>{
          if (username != null) 'username': username.trim(),
          if (avatar != null) 'avatar': avatar,
        };
        try {
          final r =
              await sb
                  .from('profiles')
                  .update(upd)
                  .eq('id', uid!)
                  .select()
                  .single();
          me = Profile(r);
        } on PostgrestException catch (e) {
          if (e.code == '23505') throw CloudError('Bu isim alınmış.');
          if (e.code == '23514') {
            throw CloudError('İsim 3-16 karakter olmalı.');
          }
          rethrow;
        }
        _notify();
      });

  // ======================= SIRALAMA =======================

  static const _cols =
      'id,username,avatar,level,total_stars,total_score,week,weekly_score,weekly_stars,clan_id,clan_role,friend_code';

  static Future<List<Profile>> weeklyBoard() => _guard(() async {
    await _ensure();
    await _pushProfileStats();
    final r = await sb
        .from('profiles')
        .select(_cols)
        .eq('week', currentWeek)
        .gt('weekly_score', 0)
        .order('weekly_score', ascending: false)
        .limit(50);
    return [for (final x in r) Profile(x)];
  });

  static Future<List<Profile>> globalBoard() => _guard(() async {
    await _ensure();
    final r = await sb
        .from('profiles')
        .select(_cols)
        .order('total_stars', ascending: false)
        .order('total_score', ascending: false)
        .limit(50);
    return [for (final x in r) Profile(x)];
  });

  static Future<(int global, int weekly)> myRanks() => _guard(() async {
    await _ensure();
    final r = await sb.rpc('my_ranks') as List;
    if (r.isEmpty) return (0, 0);
    final m = r.first as Map;
    return (
      (m['global_rank'] as num).toInt(),
      (m['weekly_rank'] as num).toInt(),
    );
  });

  // ======================= ARKADAŞLAR =======================

  static Future<FriendsData> friends() => _guard(() async {
    await _ensure();
    final rows = await sb.from('friendships').select();
    final acc = <String>{}, inc = <String>{}, out = <String>{};
    for (final r in rows) {
      final a = r['user_id'] as String, b = r['friend_id'] as String;
      final other = a == uid ? b : a;
      if (r['status'] == 'accepted') {
        acc.add(other);
      } else if (b == uid) {
        inc.add(other);
      } else {
        out.add(other);
      }
    }
    final ids = {...acc, ...inc, ...out}.toList();
    final profiles =
        ids.isEmpty
            ? <Profile>[]
            : [
              for (final x in await sb
                  .from('profiles')
                  .select(_cols)
                  .inFilter('id', ids))
                Profile(x),
            ];
    List<Profile> pick(Set<String> s) =>
        profiles.where((p) => s.contains(p.id)).toList()
          ..sort((a, b) => b.level.compareTo(a.level));
    return friendsCache = FriendsData(pick(acc), pick(inc), pick(out));
  });

  /// Arkadaş kodu ile istek gönder (karşı taraf zaten istek attıysa kabul eder).
  static Future<String> addFriend(String code) => _guard(() async {
    await _ensure();
    final c = code.trim().toUpperCase();
    final p =
        await sb
            .from('profiles')
            .select('id,username')
            .eq('friend_code', c)
            .maybeSingle();
    if (p == null) throw CloudError('Bu kodla bir oyuncu bulunamadı.');
    final other = p['id'] as String;
    if (other == uid) throw CloudError('Bu senin kendi kodun 🙂');
    final reverse =
        await sb
            .from('friendships')
            .select()
            .eq('user_id', other)
            .eq('friend_id', uid!)
            .maybeSingle();
    if (reverse != null) {
      await acceptFriend(other);
      return '${p['username']} ile artık arkadaşsınız!';
    }
    try {
      await sb.from('friendships').insert({'user_id': uid, 'friend_id': other});
    } on PostgrestException catch (e) {
      if (e.code == '23505') throw CloudError('Zaten istek gönderdin.');
      rethrow;
    }
    return '${p['username']} oyuncusuna istek gönderildi.';
  });

  static Future<void> acceptFriend(String other) => _guard(() async {
    await sb
        .from('friendships')
        .update({'status': 'accepted'})
        .eq('user_id', other)
        .eq('friend_id', uid!);
  });

  static Future<void> removeFriend(String other) => _guard(() async {
    await sb
        .from('friendships')
        .delete()
        .or(
          'and(user_id.eq.$uid,friend_id.eq.$other),and(user_id.eq.$other,friend_id.eq.$uid)',
        );
  });

  // ======================= TAKIM =======================

  static Future<List<Clan>> listClans([String search = '']) => _guard(() async {
    await _ensure();
    final r =
        await sb.rpc('list_clans', params: {'p_search': search.trim()}) as List;
    return [for (final x in r) Clan(Map<String, dynamic>.from(x as Map))];
  });

  static String _rpcMsg(Object e) {
    if (e is PostgrestException) {
      if (e.code == '23505') return 'Bu takım adı alınmış.';
      if (e.code == '23514') return 'Takım adı 3-20 karakter olmalı.';
      return e.message;
    }
    return '$e';
  }

  static Future<T> _rpc<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on CloudError {
      rethrow;
    } catch (e) {
      throw CloudError(_rpcMsg(e));
    }
  }

  static Future<void> createClan(String name, String desc, int badge) =>
      _rpc(() async {
        await _ensure();
        await sb.rpc(
          'create_clan',
          params: {'p_name': name, 'p_desc': desc, 'p_badge': badge},
        );
        await refreshProfile();
        _notify();
      });

  static Future<void> joinClan(String id) => _rpc(() async {
    await _ensure();
    await sb.rpc('join_clan', params: {'p_clan': id});
    await refreshProfile();
    _notify();
  });

  static Future<void> leaveClan() => _rpc(() async {
    await _ensure();
    await sb.rpc('leave_clan');
    await refreshProfile();
    _notify();
  });

  static Future<Clan?> myClan() => _rpc(() async {
    await _ensure();
    await _pushProfileStats();
    final cid = me?.clanId;
    if (cid == null) return null;
    final r = await sb.from('clans').select().eq('id', cid).maybeSingle();
    return r == null ? null : Clan(r);
  });

  static Future<List<Profile>> clanMembers(String cid) => _rpc(() async {
    final r = await sb.from('profiles').select(_cols).eq('clan_id', cid);
    return [for (final x in r) Profile(x)]
      ..sort((a, b) => b.weeklyStars.compareTo(a.weeklyStars));
  });

  static Future<int> clanStars(String cid) => _rpc(() async {
    final r = await sb.rpc('clan_weekly_stars', params: {'p_clan': cid});
    return (r as num).toInt();
  });

  static Future<Set<int>> claimedChests() => _rpc(() async {
    final r = await sb
        .from('chest_claims')
        .select('tier')
        .eq('user_id', uid!)
        .eq('week', currentWeek);
    return {for (final x in r) (x['tier'] as num).toInt()};
  });

  static Future<Reward?> claimChest(int tier) => _rpc(() async {
    final ok = await sb.rpc('claim_chest', params: {'p_tier': tier});
    if (ok != true) return null;
    final r = chestRewards[tier - 1];
    Progress.grant(r);
    return r;
  });

  static Stream<List<ClanMessage>> messages(String cid) => sb
      .from('clan_messages')
      .stream(primaryKey: ['id'])
      .eq('clan_id', cid)
      .order('created_at', ascending: false)
      .limit(60)
      .map((rows) => [for (final r in rows) ClanMessage(r)]);

  static Future<void> sendMessage(String text) => _rpc(() async {
    final t = text.trim();
    if (t.isEmpty || me?.clanId == null) return;
    await sb.from('clan_messages').insert({
      'clan_id': me!.clanId,
      'user_id': uid,
      'body': t.substring(0, min(t.length, 200)),
    });
  });

  static Future<void> requestLives() => _rpc(() async {
    await sb.rpc('request_lives');
  });

  /// Takım arkadaşına can gönder; başarılıysa +5 altın teşekkür.
  static Future<bool> helpLife(int msgId) => _rpc(() async {
    final ok = await sb.rpc('help_life', params: {'p_msg': msgId});
    if (ok == true) {
      Progress.coins += 5;
      Progress.save();
      return true;
    }
    return false;
  });

  /// Takımdan gelen canları al; kaç can geldiğini döndürür.
  static Future<int> claimLifeHelps() async {
    if (!enabled || !online || me?.clanId == null) return 0;
    try {
      final n = (await sb.rpc('claim_life_helps') as num).toInt();
      if (n > 0) {
        Progress.tickLives();
        Progress.lives = min(Progress.maxLives, Progress.lives + n);
        Progress.save();
      }
      return n;
    } catch (_) {
      return 0;
    }
  }

  static Future<Map<String, Profile>> profilesById(Iterable<String> ids) async {
    final list = ids.toSet().toList();
    if (list.isEmpty) return {};
    final r = await sb.from('profiles').select(_cols).inFilter('id', list);
    return {for (final x in r) x['id'] as String: Profile(x)};
  }
}
