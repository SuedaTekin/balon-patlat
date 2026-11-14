import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../progress.dart';
import '../theme.dart';
import '../widgets.dart';
import 'avatar.dart';
import 'cloud.dart';
import 'ui_common.dart';

class TeamTab extends StatefulWidget {
  const TeamTab({super.key, required this.onChanged});
  final VoidCallback onChanged;

  @override
  State<TeamTab> createState() => _TeamTabState();
}

class _TeamTabState extends State<TeamTab> {
  bool _loading = true;
  String? _error;
  Clan? _clan;
  List<Profile> _members = [];
  int _stars = 0;
  Set<int> _claimed = {};
  List<Clan> _clans = [];
  int _page = 0;
  final _search = TextEditingController();
  final _msg = TextEditingController();
  Stream<List<ClanMessage>>? _stream;
  String? _streamClan;
  Map<String, Profile> _people = {};

  @override
  void initState() {
    super.initState();
    Cloud.changes.addListener(_onCloud);
    _load();
  }

  @override
  void dispose() {
    Cloud.changes.removeListener(_onCloud);
    _search.dispose();
    _msg.dispose();
    super.dispose();
  }

  String? _lastClan = '-';
  void _onCloud() {
    if (Cloud.me?.clanId != _lastClan) _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!Cloud.enabled) throw CloudError('Sunucu ayarlanmamış.');
      final clan = await Cloud.myClan();
      _lastClan = Cloud.me?.clanId;
      if (clan == null) {
        _clan = null;
        _clans = await Cloud.listClans(_search.text);
      } else {
        _clan = clan;
        _members = await Cloud.clanMembers(clan.id);
        _people = {for (final m in _members) m.id: m};
        _stars = await Cloud.clanStars(clan.id);
        _claimed = await Cloud.claimedChests();
        if (_streamClan != clan.id) {
          _streamClan = clan.id;
          _stream = Cloud.messages(clan.id);
        }
        final n = await Cloud.claimLifeHelps();
        if (n > 0 && mounted) {
          widget.onChanged();
          toast(context, 'Takımından $n can geldi! ❤️');
        }
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
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: LP.cyan));
    }
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [OfflineCard(onRetry: _load)],
      );
    }
    return _clan == null ? _browse() : _inClan(_clan!);
  }

  // ===================== TAKIM YOK =====================

  Widget _browse() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: glassCard(border: LP.cyan.withValues(alpha: 0.5)),
            child: Column(
              children: [
                const Icon(Icons.groups_rounded, color: LP.cyan, size: 54),
                const SizedBox(height: 6),
                Text(
                  'Bir Takıma Katıl!',
                  style: outfit(24, w: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  'Takım arkadaşlarından can iste, haftalık takım sandığını birlikte aç, sohbet et.',
                  textAlign: TextAlign.center,
                  style: jakarta(13, color: LP.muted),
                ),
                const SizedBox(height: 14),
                JuicyButton.gold(
                  height: 56,
                  onTap: _createDialog,
                  child: FittedBox(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'TAKIM KUR  ',
                          style: outfit(
                            20,
                            w: FontWeight.w900,
                            color: const Color(0xFF3D2400),
                          ),
                        ),
                        const CoinIcon(size: 24),
                        Text(
                          ' $clanCreatePrice',
                          style: outfit(
                            20,
                            w: FontWeight.w900,
                            color: const Color(0xFF3D2400),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          LpField(
            controller: _search,
            hint: 'Takım ara...',
            icon: Icons.search_rounded,
            onSubmitted: (_) => _load(),
          ),
          const SizedBox(height: 12),
          if (_clans.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Henüz takım yok — ilk takımı sen kur!',
                textAlign: TextAlign.center,
                style: jakarta(14, color: LP.muted),
              ),
            ),
          for (final c in _clans) _clanRow(c),
        ],
      ),
    );
  }

  Widget _clanRow(Clan c) {
    final full = c.members >= 30;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: glassCard(radius: 24),
      child: Row(
        children: [
          ClanBadge(c.badge, size: 50),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.name, style: outfit(17, w: FontWeight.w900)),
                if (c.description.isNotEmpty)
                  Text(
                    c.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: jakarta(12, color: LP.muted),
                  ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.people_rounded, size: 14, color: LP.muted),
                    Text(
                      ' ${c.members}/30   ',
                      style: outfit(12, color: LP.muted),
                    ),
                    const Icon(Icons.star_rounded, size: 14, color: LP.gold),
                    Text(
                      ' ${c.weeklyStars}',
                      style: outfit(12, color: LP.gold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            width: 86,
            child: JuicyButton.cyan(
              height: 42,
              padding: EdgeInsets.zero,
              onTap:
                  full
                      ? null
                      : () async {
                        if (await runCloud(
                          context,
                          () => Cloud.joinClan(c.id),
                        )) {
                          if (mounted) {
                            toast(context, '${c.name} takımına hoş geldin!');
                          }
                          _load();
                        }
                      },
              child: FittedBox(
                child: Text(
                  full ? 'DOLU' : 'KATIL',
                  style: outfit(
                    15,
                    w: FontWeight.w900,
                    color: const Color(0xFF00363D),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createDialog() async {
    final name = TextEditingController();
    final desc = TextEditingController();
    var badge = 0;
    await showDialog<void>(
      context: context,
      barrierColor: const Color(0xD9070314),
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setD) => ModalCard(
                  title: 'TAKIM KUR',
                  titleColor: LP.gold,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var i = 0; i < clanBadgeIcons.length; i++)
                          GestureDetector(
                            onTap: () => setD(() => badge = i),
                            child: Opacity(
                              opacity: badge == i ? 1 : 0.45,
                              child: ClanBadge(i, size: badge == i ? 54 : 46),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    LpField(
                      controller: name,
                      hint: 'Takım adı (3-20)',
                      icon: Icons.shield_rounded,
                      maxLength: 20,
                    ),
                    const SizedBox(height: 10),
                    LpField(
                      controller: desc,
                      hint: 'Kısa açıklama (isteğe bağlı)',
                      icon: Icons.notes_rounded,
                      maxLength: 80,
                    ),
                    const SizedBox(height: 16),
                    JuicyButton.gold(
                      onTap: () async {
                        if (name.text.trim().length < 3) {
                          toast(
                            ctx,
                            'Takım adı en az 3 karakter olmalı.',
                            error: true,
                          );
                          return;
                        }
                        if (Progress.coins < clanCreatePrice) {
                          toast(ctx, 'Yeterli altın yok.', error: true);
                          return;
                        }
                        final ok = await runCloud(
                          ctx,
                          () => Cloud.createClan(name.text, desc.text, badge),
                        );
                        if (ok) {
                          Progress.spend(clanCreatePrice);
                          widget.onChanged();
                          if (ctx.mounted) Navigator.pop(ctx);
                        }
                      },
                      child: FittedBox(
                        child: Text(
                          'KUR ($clanCreatePrice altın)',
                          style: outfit(
                            20,
                            w: FontWeight.w900,
                            color: const Color(0xFF3D2400),
                          ),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('Vazgeç', style: outfit(16, color: LP.muted)),
                    ),
                  ],
                ),
          ),
    );
    name.dispose();
    desc.dispose();
    _load();
  }

  // ===================== TAKIMDA =====================

  Widget _inClan(Clan c) {
    final leader = _members.where((m) => m.isLeader).firstOrNull;
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  sliver: SliverList.list(
                    children: [
                      _header(c, leader),
                      const SizedBox(height: 12),
                      _chest(),
                      const SizedBox(height: 12),
                      _lifeCard(),
                      const SizedBox(height: 12),
                      _segments(),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
                if (_page == 0)
                  _chatSliver()
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    sliver: SliverList.list(children: _contribution()),
                  ),
              ],
            ),
          ),
        ),
        if (_page == 0) _composer(),
      ],
    );
  }

  Widget _header(Clan c, Profile? leader) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: glassCard(),
      child: Row(
        children: [
          ClanBadge(c.badge, size: 66),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.name, style: outfit(22, w: FontWeight.w900)),
                if (c.description.isNotEmpty)
                  Text(
                    c.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: jakarta(12, color: LP.muted),
                  ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 10,
                  children: [
                    Text(
                      '👥 ${_members.length}/30',
                      style: outfit(13, color: LP.muted),
                    ),
                    Text(
                      '⭐ $_stars bu hafta',
                      style: outfit(13, color: LP.gold),
                    ),
                    if (leader != null)
                      Text(
                        '👑 ${leader.username}',
                        style: outfit(13, color: LP.pink),
                      ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: LP.muted),
            color: LP.surfaceHigh,
            onSelected: (_) => _leave(),
            itemBuilder:
                (_) => [
                  PopupMenuItem(
                    value: 'leave',
                    child: Text(
                      'Takımdan ayrıl',
                      style: outfit(15, color: LP.pink),
                    ),
                  ),
                ],
          ),
        ],
      ),
    );
  }

  Future<void> _leave() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0xD9070314),
      builder:
          (ctx) => ModalCard(
            title: 'TAKIMDAN AYRIL',
            titleColor: LP.ruby,
            children: [
              Text(
                Cloud.me?.isLeader == true
                    ? 'Lidersin. Ayrılırsan liderlik en çok katkı yapan üyeye geçer.'
                    : 'Takımdan ayrılmak istediğine emin misin?',
                textAlign: TextAlign.center,
                style: jakarta(14),
              ),
              const SizedBox(height: 16),
              JuicyButton.ruby(
                onTap: () => Navigator.pop(ctx, true),
                child: Text(
                  'AYRIL',
                  style: outfit(20, w: FontWeight.w900, color: Colors.white),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Vazgeç', style: outfit(16, color: LP.muted)),
              ),
            ],
          ),
    );
    if (ok == true && mounted) {
      await runCloud(context, Cloud.leaveClan);
      _streamClan = null;
      _load();
    }
  }

  Widget _chest() {
    final maxT = chestTiers.last;
    final next = chestTiers.indexWhere((t) => _stars < t);
    final now = DateTime.now().toUtc();
    final weekEnd = DateTime.utc(
      now.year,
      now.month,
      now.day,
    ).add(Duration(days: 8 - now.weekday));
    final left = weekEnd.difference(now);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: glassCard(border: LP.gold.withValues(alpha: 0.4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.inventory_2_rounded, color: LP.gold, size: 30),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Haftalık Takım Sandığı',
                      style: outfit(18, w: FontWeight.w900),
                    ),
                    Text(
                      next == -1
                          ? 'TÜM KADEMELER AÇIK!'
                          : 'KADEME ${next + 1} / ${chestTiers.length}',
                      style: outfit(12, color: LP.gold),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: LP.surfaceHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '⏳ ${left.inDays}g ${left.inHours % 24}s',
                  style: outfit(12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Toplanan Yıldız:', style: jakarta(13)),
              const Spacer(),
              Text('$_stars / $maxT', style: outfit(15, color: LP.gold)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (_stars / maxT).clamp(0.0, 1.0),
              minHeight: 12,
              backgroundColor: LP.bgDeep,
              color: LP.cyan,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < chestTiers.length; i++)
                Expanded(child: _tierButton(i)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Takımdaki herkesin bu hafta kazandığı yıldızlar sayılır.',
            style: jakarta(11, color: LP.muted),
          ),
        ],
      ),
    );
  }

  Widget _tierButton(int i) {
    final tier = i + 1;
    final reached = _stars >= chestTiers[i];
    final claimed = _claimed.contains(tier);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: GestureDetector(
        onTap:
            reached && !claimed
                ? () async {
                  Reward? r;
                  final ok = await runCloud(context, () async {
                    r = await Cloud.claimChest(tier);
                  });
                  if (ok && r != null && mounted) {
                    _claimed.add(tier);
                    widget.onChanged();
                    setState(() {});
                    HapticFeedback.mediumImpact();
                    await showRewardDialog(context, 'SANDIK $tier AÇILDI!', r!);
                  }
                }
                : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color:
                claimed
                    ? LP.surface
                    : reached
                    ? LP.gold
                    : LP.bgDeep.withValues(alpha: 0.6),
            border: Border.all(
              color: reached ? LP.gold : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            children: [
              Icon(
                claimed
                    ? Icons.check_circle_rounded
                    : reached
                    ? Icons.redeem_rounded
                    : Icons.lock_rounded,
                color:
                    claimed
                        ? LP.emerald
                        : reached
                        ? const Color(0xFF3D2400)
                        : LP.muted,
                size: 22,
              ),
              FittedBox(
                child: Text(
                  claimed
                      ? 'ALINDI'
                      : reached
                      ? 'AÇ!'
                      : '⭐ ${chestTiers[i]}',
                  style: outfit(
                    12,
                    color:
                        reached && !claimed
                            ? const Color(0xFF3D2400)
                            : LP.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _lifeCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: glassCard(radius: 24),
      child: Row(
        children: [
          HeartIcon(size: 44, infinite: Progress.infinite),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Can Durumu', style: outfit(16, w: FontWeight.w900)),
                Text(
                  'Takıma can ver, +5 altın kazan',
                  style: jakarta(11, color: LP.muted),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 128,
            child: JuicyButton.green(
              height: 46,
              onTap: () async {
                final ok = await runCloud(context, Cloud.requestLives);
                if (ok && mounted) {
                  toast(context, 'Can isteğin takıma gönderildi!');
                  setState(() => _page = 0);
                }
              },
              child: FittedBox(
                child: Text(
                  '♥ CAN İSTE',
                  style: outfit(
                    16,
                    w: FontWeight.w900,
                    color: const Color(0xFF053D1C),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _segments() {
    Widget seg(int i, IconData icon, String t) {
      final on = _page == i;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _page = i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient:
                  on
                      ? const LinearGradient(
                        colors: [Color(0xFFFF5C93), LP.rubyDeep],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      )
                      : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: on ? Colors.white : LP.muted),
                const SizedBox(width: 6),
                Flexible(
                  child: FittedBox(
                    child: Text(
                      t,
                      style: outfit(15, color: on ? Colors.white : LP.muted),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: LP.bgDeep.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          seg(0, Icons.forum_rounded, 'Sohbet & Can'),
          seg(1, Icons.leaderboard_rounded, 'Katkı Sıralaması'),
        ],
      ),
    );
  }

  Widget _chatSliver() {
    return StreamBuilder<List<ClanMessage>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Sohbet yüklenemedi.',
                textAlign: TextAlign.center,
                style: jakarta(13, color: LP.muted),
              ),
            ),
          );
        }
        final msgs = snap.data ?? [];
        final unknown = msgs
            .map((m) => m.userId)
            .whereType<String>()
            .where((id) => !_people.containsKey(id));
        if (unknown.isNotEmpty) {
          Cloud.profilesById(unknown).then((p) {
            if (mounted) setState(() => _people.addAll(p));
          });
        }
        if (msgs.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                snap.connectionState == ConnectionState.waiting
                    ? 'Yükleniyor...'
                    : 'Henüz mesaj yok. İlk mesajı sen yaz!',
                textAlign: TextAlign.center,
                style: jakarta(13, color: LP.muted),
              ),
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          sliver: SliverList.builder(
            itemCount: msgs.length,
            itemBuilder: (_, i) => _message(msgs[i]),
          ),
        );
      },
    );
  }

  Widget _message(ClanMessage m) {
    if (m.kind == 'system') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: LP.surface,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '🎉 ${m.body}',
              textAlign: TextAlign.center,
              style: jakarta(12, color: LP.muted),
            ),
          ),
        ),
      );
    }
    final p = _people[m.userId];
    final mine = m.userId == Cloud.uid;
    final life = m.kind == 'life';
    final helped = m.helpers.contains(Cloud.uid);
    final full = m.helpers.length >= 5;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            mine
                ? const Color(0xFF15405A).withValues(alpha: 0.7)
                : const Color(0xFF1E1040).withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(22),
        border: Border(
          left: BorderSide(color: life ? LP.ruby : LP.cyan, width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarImage(
                p?.avatar ?? 3,
                size: 34,
                name: p?.username ?? '?',
                ring: LP.cyan,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        p?.username ?? '...',
                        overflow: TextOverflow.ellipsis,
                        style: outfit(15, w: FontWeight.w900),
                      ),
                    ),
                    if (p != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: LP.surfaceHighest,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Lvl ${p.level}',
                          style: outfit(10, color: LP.muted),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(timeAgo(m.createdAt), style: jakarta(11, color: LP.muted)),
            ],
          ),
          const SizedBox(height: 6),
          Text(m.body, style: jakarta(14)),
          if (life) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.favorite_border_rounded,
                  color: LP.pink,
                  size: 16,
                ),
                Text(
                  ' ${m.helpers.length}/5 Can Verildi',
                  style: outfit(12, color: LP.pink),
                ),
                const SizedBox(width: 8),
                for (var i = 0; i < 5; i++)
                  Container(
                    margin: const EdgeInsets.only(right: 3),
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < m.helpers.length ? LP.ruby : LP.surfaceHighest,
                    ),
                  ),
                const Spacer(),
                if (!mine && !helped && !full)
                  SizedBox(
                    width: 112,
                    child: JuicyButton.ruby(
                      height: 38,
                      padding: EdgeInsets.zero,
                      onTap: () async {
                        var ok = false;
                        await runCloud(context, () async {
                          ok = await Cloud.helpLife(m.id);
                        });
                        if (ok && mounted) {
                          widget.onChanged();
                          toast(context, 'Can gönderildi! +5 altın');
                        }
                      },
                      child: FittedBox(
                        child: Text(
                          '♥ CAN GÖNDER',
                          style: outfit(
                            13,
                            w: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  )
                else if (helped)
                  Text('✓ Gönderdin', style: outfit(12, color: LP.emerald)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _composer() {
    Future<void> send() async {
      final t = _msg.text;
      if (t.trim().isEmpty) return;
      _msg.clear();
      await runCloud(context, () => Cloud.sendMessage(t));
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      color: LP.bgDeep.withValues(alpha: 0.6),
      child: Row(
        children: [
          Expanded(
            child: LpField(
              controller: _msg,
              hint: 'Takım arkadaşlarına yaz...',
              icon: Icons.chat_bubble_outline_rounded,
              maxLength: 200,
              onSubmitted: (_) => send(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: send,
            child: Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: LP.cyan,
              ),
              child: const Icon(Icons.send_rounded, color: Color(0xFF00363D)),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _contribution() {
    final sorted = List.of(_members)
      ..sort((a, b) => b.weeklyStars.compareTo(a.weeklyStars));
    return [
      if (sorted.length >= 2) _Podium(sorted.take(3).toList(), stars: true),
      const SizedBox(height: 12),
      for (var i = 0; i < sorted.length; i++)
        _PersonRow(
          rank: i + 1,
          p: sorted[i],
          value: '⭐ ${sorted[i].weeklyStars}',
          highlight: sorted[i].id == Cloud.uid,
          badge: sorted[i].isLeader ? 'Lider' : null,
        ),
    ];
  }
}

/// İlk 3 için podyum (sıralama ve takım katkısında ortak).
class _Podium extends StatelessWidget {
  const _Podium(this.top, {this.stars = false});
  final List<Profile> top;
  final bool stars;

  @override
  Widget build(BuildContext context) => Podium(top, stars: stars);
}

class Podium extends StatelessWidget {
  const Podium(this.top, {super.key, this.stars = false, this.value});
  final List<Profile> top;
  final bool stars;
  final String Function(Profile)? value;

  @override
  Widget build(BuildContext context) {
    Widget col(int i, double h, Color c) {
      if (i >= top.length) return const Expanded(child: SizedBox());
      final p = top[i];
      final v =
          value?.call(p) ??
          (stars ? '⭐ ${p.weeklyStars}' : formatNum(p.weeklyScore));
      return Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (i == 0)
              const Icon(
                Icons.workspace_premium_rounded,
                color: LP.gold,
                size: 28,
              ),
            AvatarImage(
              p.avatar,
              size: i == 0 ? 70 : 56,
              name: p.username,
              ring: c,
            ),
            const SizedBox(height: 4),
            Text(
              p.username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: outfit(13, w: FontWeight.w900),
            ),
            Text(v, style: outfit(12, color: LP.gold)),
            const SizedBox(height: 4),
            Container(
              height: h,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [c, c.withValues(alpha: 0.25)],
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '${i + 1}',
                style: outfit(
                  28,
                  w: FontWeight.w900,
                  color: Colors.white,
                  shadows: embossShadow,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 230,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          col(1, 70, const Color(0xFFC9D3E6)),
          col(0, 100, LP.gold),
          col(2, 50, const Color(0xFFE09A5C)),
        ],
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.rank,
    required this.p,
    required this.value,
    this.highlight = false,
    this.badge,
  });
  final int rank;
  final Profile p;
  final String value;
  final bool highlight;
  final String? badge;

  @override
  Widget build(BuildContext context) => PersonRow(
    rank: rank,
    p: p,
    value: value,
    highlight: highlight,
    badge: badge,
  );
}

class PersonRow extends StatelessWidget {
  const PersonRow({
    super.key,
    required this.rank,
    required this.p,
    required this.value,
    this.highlight = false,
    this.badge,
    this.trailing,
  });
  final int rank;
  final Profile p;
  final String value;
  final bool highlight;
  final String? badge;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: glassCard(
        radius: 20,
        border: highlight ? LP.cyan.withValues(alpha: 0.8) : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              rank > 0 ? '$rank' : '',
              textAlign: TextAlign.center,
              style: outfit(
                16,
                w: FontWeight.w900,
                color: rank <= 3 ? LP.gold : LP.muted,
              ),
            ),
          ),
          const SizedBox(width: 6),
          AvatarImage(p.avatar, size: 40, name: p.username, ring: LP.cyan),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        highlight ? '${p.username} (Sen)' : p.username,
                        overflow: TextOverflow.ellipsis,
                        style: outfit(15, w: FontWeight.w900),
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: LP.ruby,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          badge!,
                          style: outfit(10, color: Colors.white),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  'Seviye ${p.level} · ⭐ ${p.totalStars}',
                  style: jakarta(11, color: LP.muted),
                ),
              ],
            ),
          ),
          Text(value, style: outfit(15, color: LP.gold)),
          if (trailing != null) ...[const SizedBox(width: 4), trailing!],
        ],
      ),
    );
  }
}
