import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../progress.dart';
import '../ranks_tab.dart';
import '../theme.dart';
import 'avatar.dart';
import 'cloud.dart';
import 'team_tab.dart';
import 'ui_common.dart';

/// Sıralama sekmesi: Haftalık Lig · Genel · Arkadaşlar · Rekorlarım
class RanksTab extends StatefulWidget {
  const RanksTab({super.key});

  @override
  State<RanksTab> createState() => _RanksTabState();
}

class _RanksTabState extends State<RanksTab> {
  int _page = 0;
  bool _loading = false;
  String? _error;
  List<Profile> _rows = [];
  (int, int)? _ranks;
  FriendsData? _friends;
  final _code = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_page == 3) return setState(() {});
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!Cloud.enabled) throw CloudError('Sunucu ayarlanmamış.');
      if (_page == 0) {
        _rows = await Cloud.weeklyBoard();
        _ranks = await Cloud.myRanks();
      } else if (_page == 1) {
        _rows = await Cloud.globalBoard();
        _ranks = await Cloud.myRanks();
      } else {
        _friends = await Cloud.friends();
      }
    } on CloudError catch (e) {
      _error = e.message;
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: LP.bgDeep.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                _seg(0, 'Lig'),
                _seg(1, 'Genel'),
                _seg(2, 'Arkadaş'),
                _seg(3, 'Rekorlarım'),
              ],
            ),
          ),
        ),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _seg(int i, String t) {
    final on = _page == i;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _page = i);
          _load();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: on ? LP.surfaceHighest : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Center(
            child: FittedBox(
              child: Text(t, style: outfit(14, color: on ? LP.pink : LP.muted)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_page == 3) return const LocalRecords();
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: LP.cyan));
    }
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [OfflineCard(onRetry: _load)],
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: _page == 2 ? _friendsList() : _board(),
      ),
    );
  }

  String _league(int rank) {
    if (rank <= 0) return 'Bronz';
    if (rank <= 3) return 'Elmas';
    if (rank <= 10) return 'Altın';
    if (rank <= 30) return 'Gümüş';
    return 'Bronz';
  }

  List<Widget> _board() {
    final weekly = _page == 0;
    final myRank = weekly ? _ranks?.$2 ?? 0 : _ranks?.$1 ?? 0;
    final now = DateTime.now().toUtc();
    final weekEnd = DateTime.utc(
      now.year,
      now.month,
      now.day,
    ).add(Duration(days: 8 - now.weekday));
    final left = weekEnd.difference(now);
    String val(Profile p) =>
        weekly ? formatNum(p.weeklyScore) : '⭐ ${p.totalStars}';
    final me = Cloud.me;
    final meInList = _rows.any((p) => p.id == Cloud.uid);
    return [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: glassCard(border: LP.gold.withValues(alpha: 0.4)),
        child: Row(
          children: [
            Icon(
              weekly ? Icons.emoji_events_rounded : Icons.public_rounded,
              color: LP.gold,
              size: 36,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    weekly
                        ? '${_league(Progress.currentWeeklyScore > 0 ? myRank : 0)} Ligi'
                        : 'Genel Sıralama',
                    style: outfit(20, w: FontWeight.w900),
                  ),
                  Text(
                    weekly
                        ? 'Bu hafta ${formatNum(Progress.currentWeeklyScore)} puan · Bitişe ${left.inDays}g ${left.inHours % 24}s'
                        : 'Toplam yıldıza göre tüm oyuncular',
                    style: jakarta(12, color: LP.muted),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Text('SIRAN', style: outfit(11, color: LP.muted)),
                Text(
                  weekly && Progress.currentWeeklyScore == 0 ? '-' : '#$myRank',
                  style: outfit(24, w: FontWeight.w900, color: LP.cyan),
                ),
              ],
            ),
          ],
        ),
      ),
      if (weekly)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'İlk 3: Elmas · İlk 10: Altın · İlk 30: Gümüş. Bölüm kazandıkça puanın eklenir; her pazartesi sıfırlanır.',
            textAlign: TextAlign.center,
            style: jakarta(11, color: LP.muted),
          ),
        ),
      const SizedBox(height: 12),
      if (_rows.isEmpty)
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            weekly
                ? 'Bu hafta henüz kimse puan almadı. Bir bölüm kazan, zirveye yerleş!'
                : 'Henüz oyuncu yok.',
            textAlign: TextAlign.center,
            style: jakarta(14, color: LP.muted),
          ),
        ),
      if (_rows.length >= 3) Podium(_rows.take(3).toList(), value: val),
      const SizedBox(height: 10),
      for (var i = 0; i < _rows.length; i++)
        PersonRow(
          rank: i + 1,
          p: _rows[i],
          value: val(_rows[i]),
          highlight: _rows[i].id == Cloud.uid,
        ),
      if (!meInList && me != null && myRank > 0)
        PersonRow(rank: myRank, p: me, value: val(me), highlight: true),
    ];
  }

  List<Widget> _friendsList() {
    final f = _friends;
    final me = Cloud.me;
    return [
      if (me != null)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: glassCard(border: LP.cyan.withValues(alpha: 0.5)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Senin kodun',
                          style: jakarta(12, color: LP.muted),
                        ),
                        Text(
                          me.friendCode,
                          style: outfit(
                            28,
                            w: FontWeight.w900,
                            color: LP.cyan,
                            spacing: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: me.friendCode));
                      toast(context, 'Kod kopyalandı! Arkadaşına gönder.');
                    },
                    icon: const Icon(Icons.copy_rounded, color: LP.cyan),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: LpField(
                      controller: _code,
                      hint: 'Arkadaş kodu',
                      icon: Icons.person_add_rounded,
                      maxLength: 6,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 90,
                    child: JuicyButton.cyan(
                      height: 52,
                      padding: EdgeInsets.zero,
                      onTap: () async {
                        String? msg;
                        final ok = await runCloud(context, () async {
                          msg = await Cloud.addFriend(_code.text);
                        });
                        if (ok && mounted) {
                          _code.clear();
                          toast(context, msg!);
                          _load();
                        }
                      },
                      child: FittedBox(
                        child: Text(
                          'EKLE',
                          style: outfit(
                            17,
                            w: FontWeight.w900,
                            color: const Color(0xFF00363D),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      const SizedBox(height: 16),
      if (f != null && f.incoming.isNotEmpty) ...[
        Text('Gelen İstekler', style: outfit(18, w: FontWeight.w900)),
        const SizedBox(height: 8),
        for (final p in f.incoming)
          PersonRow(
            rank: 0,
            p: p,
            value: '',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () async {
                    await runCloud(context, () => Cloud.acceptFriend(p.id));
                    _load();
                  },
                  icon: const Icon(
                    Icons.check_circle_rounded,
                    color: LP.emerald,
                    size: 30,
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    await runCloud(context, () => Cloud.removeFriend(p.id));
                    _load();
                  },
                  icon: const Icon(
                    Icons.cancel_rounded,
                    color: LP.pink,
                    size: 30,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
      ],
      Text(
        'Arkadaşların (${f?.friends.length ?? 0})',
        style: outfit(18, w: FontWeight.w900),
      ),
      const SizedBox(height: 8),
      if (f == null || f.friends.isEmpty)
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Henüz arkadaşın yok. Kodunu paylaş ya da arkadaşının kodunu ekle — haritada nerede olduklarını görürsün!',
            textAlign: TextAlign.center,
            style: jakarta(13, color: LP.muted),
          ),
        ),
      if (f != null)
        for (final p in [...f.friends, if (me != null) me]
          ..sort((a, b) => b.totalStars.compareTo(a.totalStars)))
          GestureDetector(
            onLongPress: p.id == Cloud.uid ? null : () => _removeFriend(p),
            child: PersonRow(
              rank: 0,
              p: p,
              value: '⭐ ${p.totalStars}',
              highlight: p.id == Cloud.uid,
            ),
          ),
      if (f != null && f.outgoing.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text('Bekleyen İsteklerin', style: outfit(15, color: LP.muted)),
        const SizedBox(height: 6),
        for (final p in f.outgoing)
          Opacity(
            opacity: 0.6,
            child: PersonRow(rank: 0, p: p, value: 'bekliyor'),
          ),
      ],
      if (f != null && f.friends.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'Arkadaşı silmek için üzerine basılı tut.',
            textAlign: TextAlign.center,
            style: jakarta(11, color: LP.muted),
          ),
        ),
    ];
  }

  Future<void> _removeFriend(Profile p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: LP.surfaceHigh,
            title: Text('${p.username} silinsin mi?', style: outfit(18)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Vazgeç', style: outfit(15, color: LP.muted)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Sil', style: outfit(15, color: LP.pink)),
              ),
            ],
          ),
    );
    if (ok == true && mounted) {
      await runCloud(context, () => Cloud.removeFriend(p.id));
      _load();
    }
  }
}

/// Haritada arkadaşın bulunduğu bölümün yanında gösterilen etiket.
class FriendChip extends StatelessWidget {
  const FriendChip(this.p, {super.key});
  final Profile p;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(3, 3, 10, 3),
      decoration: BoxDecoration(
        color: LP.surfaceHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AvatarImage(p.avatar, size: 24, name: p.username, ring: LP.cyan),
          const SizedBox(width: 5),
          Text(
            p.username.length > 9
                ? '${p.username.substring(0, 9)}…'
                : p.username,
            style: outfit(12),
          ),
        ],
      ),
    );
  }
}
