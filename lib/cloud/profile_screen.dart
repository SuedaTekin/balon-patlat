import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../progress.dart';
import '../settings.dart';
import '../theme.dart';
import '../widgets.dart';
import 'auth_screen.dart';
import 'avatar.dart';
import 'cloud.dart';
import 'ui_common.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    Cloud.changes.addListener(_changed);
  }

  @override
  void dispose() {
    Cloud.changes.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _edit() async {
    final me = Cloud.me;
    if (me == null) return;
    final name = TextEditingController(text: me.username);
    var avatar = me.avatar;
    await showDialog<void>(
      context: context,
      barrierColor: const Color(0xD9070314),
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setD) => ModalCard(
                  title: 'PROFİLİ DÜZENLE',
                  titleColor: LP.cyan,
                  children: [
                    LpField(
                      controller: name,
                      hint: 'Oyuncu adı',
                      icon: Icons.badge_rounded,
                      maxLength: 16,
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (var i = 0; i < avatarCount; i++)
                          GestureDetector(
                            onTap: () => setD(() => avatar = i),
                            child: AvatarImage(
                              i,
                              size: 58,
                              name: name.text,
                              ring: i == avatar ? LP.cyan : Colors.transparent,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    JuicyButton.green(
                      onTap: () async {
                        final ok = await runCloud(
                          ctx,
                          () => Cloud.updateProfile(
                            username: name.text,
                            avatar: avatar,
                          ),
                        );
                        if (ok && ctx.mounted) Navigator.pop(ctx);
                      },
                      child: Text(
                        'KAYDET',
                        style: outfit(
                          22,
                          w: FontWeight.w900,
                          color: const Color(0xFF053D1C),
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
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0xD9070314),
      builder:
          (ctx) => ModalCard(
            title: 'ÇIKIŞ YAP',
            titleColor: LP.ruby,
            children: [
              Text(
                'İlerlemen hesabında güvende. Bu cihazda yeni bir misafir oyunu başlayacak. Tekrar giriş yaparak kaldığın yerden devam edebilirsin.',
                textAlign: TextAlign.center,
                style: jakarta(14),
              ),
              const SizedBox(height: 18),
              JuicyButton.ruby(
                onTap: () => Navigator.pop(ctx, true),
                child: Text(
                  'ÇIKIŞ YAP',
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
      await runCloud(context, Cloud.logout);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = Cloud.me;
    return Scaffold(
      body: Container(
        decoration: bgGradient,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: LP.onSurface,
                      ),
                    ),
                    Text('Profil', style: outfit(22, w: FontWeight.w900)),
                    const Spacer(),
                    IconButton(
                      onPressed: () async {
                        await showSettings(context);
                        _changed();
                      },
                      icon: const Icon(
                        Icons.settings_rounded,
                        color: LP.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
                  children:
                      me == null
                          ? [
                            OfflineCard(
                              onRetry: () async {
                                await Cloud.connect();
                                _changed();
                              },
                            ),
                          ]
                          : _content(me),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _content(Profile me) {
    final guest = Cloud.isGuest;
    return [
      Center(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AvatarImage(me.avatar, size: 130, name: me.username),
            Positioned(
              right: -4,
              bottom: 0,
              child: GestureDetector(
                onTap: _edit,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: LP.cyan,
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    color: Color(0xFF00363D),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Text(
        me.username,
        textAlign: TextAlign.center,
        style: outfit(28, w: FontWeight.w900),
      ),
      const SizedBox(height: 6),
      Center(
        child: GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: me.friendCode));
            toast(context, 'Arkadaş kodun kopyalandı: ${me.friendCode}');
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: LP.surfaceHighest,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Arkadaş kodu: ', style: jakarta(13, color: LP.muted)),
                Text(
                  me.friendCode,
                  style: outfit(16, color: LP.cyan, spacing: 2),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.copy_rounded, size: 16, color: LP.muted),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 18),
      Row(
        children: [
          _stat('Seviye', '${Progress.unlocked}', Icons.flag_rounded, LP.cyan),
          const SizedBox(width: 10),
          _stat(
            'Yıldız',
            '${Progress.totalStars}',
            Icons.star_rounded,
            LP.gold,
          ),
          const SizedBox(width: 10),
          _stat(
            'Bu Hafta',
            formatNum(Progress.currentWeeklyScore),
            Icons.bolt_rounded,
            LP.pink,
          ),
        ],
      ),
      const SizedBox(height: 18),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: glassCard(
          border: guest ? LP.gold.withValues(alpha: 0.6) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  guest ? Icons.person_outline_rounded : Icons.verified_rounded,
                  color: guest ? LP.gold : LP.emerald,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    guest ? 'Misafir Hesap' : 'Kayıtlı Hesap',
                    style: outfit(18, w: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              guest
                  ? 'İlerlemen şu an sadece bu cihaza bağlı. Telefonunu değiştirirsen ya da oyunu silersen kaybolur. E-posta bağla, ilerlemen güvende olsun!'
                  : '${Cloud.email ?? ''}\nİlerlemen otomatik olarak buluta kaydediliyor.',
              style: jakarta(13, color: LP.muted),
            ),
            const SizedBox(height: 14),
            if (guest) ...[
              JuicyButton.gold(
                onTap:
                    () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder:
                            (_) => const AuthScreen(mode: AuthMode.register),
                      ),
                    ),
                child: FittedBox(
                  child: Text(
                    'HESABIMI GÜVENCEYE AL',
                    style: outfit(
                      19,
                      w: FontWeight.w900,
                      color: const Color(0xFF3D2400),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed:
                    () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AuthScreen(mode: AuthMode.login),
                      ),
                    ),
                child: Text(
                  'Zaten hesabım var → Giriş yap',
                  style: outfit(15, color: LP.cyan),
                ),
              ),
            ] else
              JuicyButton.ruby(
                height: 56,
                onTap: _logout,
                child: Text(
                  'ÇIKIŞ YAP',
                  style: outfit(19, w: FontWeight.w900, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    ];
  }

  Widget _stat(String label, String value, IconData icon, Color color) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: glassCard(radius: 22),
          child: Column(
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 4),
              FittedBox(
                child: Text(value, style: outfit(20, w: FontWeight.w900)),
              ),
              Text(label, style: jakarta(11, color: LP.muted)),
            ],
          ),
        ),
      );
}
