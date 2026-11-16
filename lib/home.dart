import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cloud/auth_screen.dart';
import 'cloud/avatar.dart';
import 'audio.dart';
import 'cloud/cloud.dart';
import 'cloud/leaderboard_tab.dart';
import 'cloud/profile_screen.dart';
import 'cloud/team_tab.dart';
import 'cloud/ui_common.dart';
import 'events_tab.dart';
import 'level_intro.dart';
import 'map_screen.dart';
import 'progress.dart';
import 'quests.dart';
import 'shop_tab.dart';
import 'theme.dart';
import 'widgets.dart';

/// Alt menülü ana kabuk: Oyna · Harita · Etkinlik · Takım · Mağaza · Sıralama.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _tab = 1;
  late final Timer _timer;
  bool _greeted = false;

  static const _titles = [
    'Oyna',
    'Harita',
    'Etkinlik',
    'Takım',
    'Mağaza',
    'Sıralama',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Cloud.changes.addListener(_onCloud);
    // Can sayacı için saniyelik yenileme (sadece üst bar).
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _topBarKey.currentState?.refresh();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeWelcome());
  }

  /// İlk açılışta giriş paneli: Google / giriş / kayıt / misafir.
  Future<void> _maybeWelcome() async {
    if (!Cloud.enabled) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('welcomeSeen') ?? false) return;
    await prefs.setBool('welcomeSeen', true);
    if (!mounted || !Cloud.isGuest) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AuthScreen(welcome: true)));
    _refresh();
  }

  /// Buluta ilk bağlanınca: arkadaşları al, takımdan gelen canları topla.
  Future<void> _onCloud() async {
    if (!mounted) return;
    setState(() {});
    if (_greeted || Cloud.me == null) return;
    _greeted = true;
    try {
      await Cloud.friends();
    } catch (_) {}
    final n = await Cloud.claimLifeHelps();
    if (mounted) {
      setState(() {});
      if (n > 0) toast(context, 'Takımından $n can geldi! ❤️');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(Progress.tickLives);
      Sfx.resumeMusic();
    } else if (state == AppLifecycleState.paused) {
      Sfx.pauseMusic();
      Cloud.syncNow();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    Cloud.changes.removeListener(_onCloud);
    _timer.cancel();
    super.dispose();
  }

  final _topBarKey = GlobalKey<_TopBarState>();

  void _refresh() => setState(() {});

  Future<void> _openLevel(int level) async {
    await startLevel(context, level);
    _refresh();
  }

  void _onNav(int i) {
    if (i == 0) {
      _openLevel(Progress.unlocked);
      return;
    }
    setState(() => _tab = i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: bgGradient,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _TopBar(
                key: _topBarKey,
                subtitle: _titles[_tab],
                onCoins: () => setState(() => _tab = 4),
                onProfile: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  );
                  _refresh();
                },
                onLives: () async {
                  await showDialog<bool>(
                    context: context,
                    barrierColor: const Color(0xD9070314),
                    builder: (_) => const LivesDialog(),
                  );
                  _refresh();
                },
              ),
              Expanded(
                child: IndexedStack(
                  index: _tab,
                  children: [
                    const SizedBox(),
                    MapTab(onOpen: _openLevel),
                    EventsTab(
                      onChanged: _refresh,
                      onPlay: () => _openLevel(Progress.unlocked),
                    ),
                    _tab == 3 ? TeamTab(onChanged: _refresh) : const SizedBox(),
                    ShopTab(onChanged: _refresh),
                    _tab == 5 ? const RanksTab() : const SizedBox(),
                  ],
                ),
              ),
              _bottomNav(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomNav() {
    final eventBadge =
        Progress.freeSpinAvailable ||
        Progress.streakClaimable ||
        readyQuestCount > 0;
    final items = [
      (Icons.sports_esports_rounded, 'Oyna', false),
      (Icons.map_rounded, 'Harita', false),
      (Icons.celebration_rounded, 'Etkinlik', eventBadge),
      (Icons.groups_rounded, 'Takım', false),
      (Icons.storefront_rounded, 'Mağaza', Progress.freeGiftAvailable),
      (Icons.leaderboard_rounded, 'Sıralama', false),
    ];
    return Container(
      padding: EdgeInsets.only(
        top: 8,
        bottom: 8 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: LP.bgDeep.withValues(alpha: 0.85),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _onNav(i),
                child: _navItem(
                  items[i].$1,
                  items[i].$2,
                  i == _tab,
                  items[i].$3,
                  i == 0,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _navItem(
    IconData icon,
    String label,
    bool active,
    bool badge,
    bool play,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient:
                    play
                        ? const RadialGradient(
                          center: Alignment(-0.3, -0.4),
                          colors: [Color(0xFFFF7FA8), LP.ruby, LP.rubyLedge],
                        )
                        : null,
                color:
                    play
                        ? null
                        : active
                        ? LP.surfaceHighest
                        : LP.surface.withValues(alpha: 0.6),
                boxShadow:
                    play
                        ? [
                          BoxShadow(
                            color: LP.ruby.withValues(alpha: 0.5),
                            blurRadius: 14,
                          ),
                        ]
                        : null,
              ),
              child: Icon(
                icon,
                size: 22,
                color:
                    play
                        ? Colors.white
                        : active
                        ? LP.pink
                        : LP.muted,
              ),
            ),
            if (badge)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: LP.ruby,
                    border: Border.all(color: LP.bgDeep, width: 2),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        FittedBox(
          child: Text(
            label,
            style: outfit(11, color: play || active ? LP.pink : LP.muted),
          ),
        ),
      ],
    );
  }
}

class _TopBar extends StatefulWidget {
  const _TopBar({
    super.key,
    required this.subtitle,
    required this.onCoins,
    required this.onLives,
    required this.onProfile,
  });
  final String subtitle;
  final VoidCallback onCoins, onLives, onProfile;

  @override
  State<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<_TopBar> {
  void refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final me = Cloud.me;
    final warn = Cloud.enabled && me != null && Cloud.isGuest;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onProfile,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                me == null
                    ? SizedBox(
                      width: 40,
                      height: 40,
                      child: CustomPaint(painter: LogoPainter()),
                    )
                    : AvatarImage(me.avatar, size: 42, name: me.username),
                if (warn)
                  Positioned(
                    right: -3,
                    top: -3,
                    child: Container(
                      width: 16,
                      height: 16,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: LP.gold,
                      ),
                      child: Text(
                        '!',
                        style: outfit(
                          11,
                          w: FontWeight.w900,
                          color: const Color(0xFF3D2400),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: widget.onProfile,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    child: Text(
                      me?.username ?? 'BALON',
                      style: outfit(
                        me == null ? 22 : 17,
                        w: FontWeight.w900,
                        color: LP.pink,
                        shadows: embossShadow,
                      ),
                    ),
                  ),
                  Text(
                    widget.subtitle,
                    style: outfit(12, w: FontWeight.w700, color: LP.muted),
                  ),
                ],
              ),
            ),
          ),
          LivesPill(onTap: widget.onLives),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: widget.onCoins,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CoinPill(coins: Progress.coins),
                Positioned(
                  right: -4,
                  top: -2,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: LP.cyan,
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      size: 14,
                      color: Color(0xFF00363D),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
