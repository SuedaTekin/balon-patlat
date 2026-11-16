import 'package:flutter/material.dart';

import '../progress.dart';
import '../theme.dart';
import '../widgets.dart';
import 'avatar.dart';
import 'cloud.dart';
import 'ui_common.dart';

enum AuthMode { register, login }

enum _Step { form, code, forgotEmail, forgotCode }

/// Giriş yap / Kayıt ol (misafir hesabına e-posta bağlama) / Şifremi unuttum.
class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    this.mode = AuthMode.register,
    this.welcome = false,
  });
  final AuthMode mode;

  /// İlk açılış karşılama paneli: altta "Misafir Olarak Oyna" çıkar.
  final bool welcome;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late AuthMode _mode = widget.mode;
  _Step _step = _Step.form;
  bool _busy = false;
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _code = TextEditingController();
  final _newPass = TextEditingController();

  @override
  void dispose() {
    for (final c in [_email, _pass, _code, _newPass]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _run(Future<void> Function() f) async {
    if (_busy) return;
    setState(() => _busy = true);
    await runCloud(context, f);
    if (mounted) setState(() => _busy = false);
  }

  bool _validEmail() {
    final ok = RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    ).hasMatch(_email.text.trim());
    if (!ok) toast(context, 'Geçerli bir e-posta adresi gir.', error: true);
    return ok;
  }

  bool _validPass(TextEditingController c) {
    if (c.text.length < 6) {
      toast(context, 'Şifre en az 6 karakter olmalı.', error: true);
      return false;
    }
    return true;
  }

  void _submitForm() {
    if (!_validEmail() || !_validPass(_pass)) return;
    if (_mode == AuthMode.login) {
      _run(() async {
        await Cloud.login(_email.text, _pass.text);
        if (mounted) {
          toast(context, 'Hoş geldin, ${Cloud.me?.username}!');
          Navigator.pop(context, true);
        }
      });
    } else {
      _run(() async {
        await Cloud.linkEmailStart(_email.text);
        if (mounted) setState(() => _step = _Step.code);
      });
    }
  }

  void _google() {
    _run(() async {
      final hadWelcome = Progress.welcomeGiven;
      final ok = await Cloud.signInWithGoogle();
      if (!ok || !mounted) return;
      if (!hadWelcome && Progress.welcomeGiven) {
        await showRewardDialog(
          context,
          'HOŞ GELDİN!',
          welcomeReward,
          subtitle: 'Google hesabın bağlandı, ilerlemen artık bulutta güvende.',
        );
      } else {
        toast(context, 'Hoş geldin, ${Cloud.me?.username ?? 'oyuncu'}!');
      }
      if (mounted) Navigator.pop(context, true);
    });
  }

  Widget _googleButton() => _busyOr(
    GestureDetector(
      onTap: _google,
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [
            BoxShadow(color: Color(0xFFB9B4CC), offset: Offset(0, 5)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ShaderMask(
              shaderCallback:
                  (r) => const SweepGradient(
                    colors: [
                      Color(0xFFEA4335),
                      Color(0xFFFBBC05),
                      Color(0xFF34A853),
                      Color(0xFF4285F4),
                      Color(0xFFEA4335),
                    ],
                  ).createShader(r),
              child: Text(
                'G',
                style: outfit(28, w: FontWeight.w900, color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Google ile Devam Et',
                  style: outfit(
                    19,
                    w: FontWeight.w900,
                    color: const Color(0xFF1A0E45),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _orDivider(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Row(
      children: [
        const Expanded(child: Divider(color: LP.surfaceHighest)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(text, style: outfit(12, color: LP.muted, spacing: 1)),
        ),
        const Expanded(child: Divider(color: LP.surfaceHighest)),
      ],
    ),
  );

  void _submitCode() {
    if (_code.text.trim().length < 6) {
      toast(context, '6 haneli kodu gir.', error: true);
      return;
    }
    _run(() async {
      await Cloud.linkEmailVerify(_email.text, _code.text, _pass.text);
      if (!mounted) return;
      await showRewardDialog(
        context,
        'HOŞ GELDİN!',
        welcomeReward,
        subtitle: 'Hesabın oluşturuldu, ilerlemen artık bulutta güvende.',
      );
      if (mounted) Navigator.pop(context, true);
    });
  }

  @override
  Widget build(BuildContext context) {
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
                      onPressed: () {
                        if (_step == _Step.form) {
                          Navigator.pop(context);
                        } else {
                          setState(() => _step = _Step.form);
                        }
                      },
                      icon: Icon(
                        _step == _Step.form
                            ? Icons.close_rounded
                            : Icons.arrow_back_rounded,
                        color: LP.onSurface,
                      ),
                    ),
                    Text(
                      'Hesap Merkezi',
                      style: outfit(22, w: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
                  children: switch (_step) {
                    _Step.form => _form(),
                    _Step.code => _codeStep(),
                    _Step.forgotEmail => _forgotEmail(),
                    _Step.forgotCode => _forgotCode(),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hero(String subtitle) => Column(
    children: [
      const Center(child: AvatarImage(0, size: 120)),
      const SizedBox(height: 12),
      Text(
        'BALON POP',
        textAlign: TextAlign.center,
        style: outfit(
          36,
          w: FontWeight.w900,
          color: LP.cyan,
          shadows: embossShadow,
        ),
      ),
      Text(
        subtitle,
        textAlign: TextAlign.center,
        style: jakarta(14, color: LP.muted),
      ),
      const SizedBox(height: 18),
    ],
  );

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(left: 6, bottom: 6, top: 10),
    child: Text(t, style: outfit(13, color: LP.muted, spacing: 1)),
  );

  Widget _busyOr(Widget w) =>
      _busy
          ? const Padding(
            padding: EdgeInsets.all(14),
            child: Center(child: CircularProgressIndicator(color: LP.cyan)),
          )
          : w;

  Widget _primary(String text, VoidCallback onTap) => _busyOr(
    JuicyButton.ruby(
      onTap: onTap,
      child: FittedBox(
        child: Text(
          text,
          style: outfit(22, w: FontWeight.w900, color: Colors.white),
        ),
      ),
    ),
  );

  List<Widget> _form() {
    final register = _mode == AuthMode.register;
    return [
      _hero('Puanlarını ve hediyelerini buluta kaydet!'),
      if (register)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: glassCard(border: LP.gold.withValues(alpha: 0.5)),
          child: Row(
            children: [
              const Icon(Icons.redeem_rounded, color: LP.gold, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hoş Geldin Paketi!',
                      style: outfit(16, color: LP.gold),
                    ),
                    Text('500 Altın + 1x Gökkuşağı hediye', style: jakarta(12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: LP.bgDeep.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            _modeTab(AuthMode.login, Icons.login_rounded, 'GİRİŞ YAP'),
            _modeTab(AuthMode.register, Icons.person_add_rounded, 'KAYIT OL'),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _googleButton(),
      _orDivider('VEYA E-POSTA İLE'),
      _label('E-POSTA ADRESİ'),
      LpField(
        controller: _email,
        hint: 'ornek@mail.com',
        icon: Icons.mail_outline_rounded,
        keyboard: TextInputType.emailAddress,
      ),
      Row(
        children: [
          Expanded(child: _label(register ? 'ŞİFRE BELİRLE' : 'ŞİFRE')),
          if (!register)
            TextButton(
              onPressed: () => setState(() => _step = _Step.forgotEmail),
              child: Text(
                'Şifremi Unuttum?',
                style: outfit(13, color: LP.cyan),
              ),
            ),
        ],
      ),
      LpField(
        controller: _pass,
        hint: 'En az 6 karakter',
        icon: Icons.lock_outline_rounded,
        password: true,
        onSubmitted: (_) => _submitForm(),
      ),
      const SizedBox(height: 22),
      _primary(
        register ? '▶ HESABIMI OLUŞTUR' : '▶ OYUNA GİRİŞ YAP',
        _submitForm,
      ),
      const SizedBox(height: 12),
      Text(
        register
            ? 'Şu anki ilerlemen bu hesaba aktarılır.'
            : 'Giriş yapınca hesabındaki ilerleme bu cihaza yüklenir.',
        textAlign: TextAlign.center,
        style: jakarta(12, color: LP.muted),
      ),
      if (widget.welcome) ...[
        const SizedBox(height: 18),
        Center(
          child: GestureDetector(
            onTap: () => Navigator.pop(context, false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: LP.bgDeep.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bolt_rounded, color: LP.gold),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Misafir Olarak Oyna (Hızlı Başla)',
                      style: outfit(15, color: LP.onSurface),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_rounded, color: LP.gold),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'İlerlemen bu cihaza kaydedilir; istediğin zaman Profil\'den '
          'hesap oluşturabilirsin.',
          textAlign: TextAlign.center,
          style: jakarta(11, color: LP.muted),
        ),
      ],
    ];
  }

  Widget _modeTab(AuthMode m, IconData icon, String text) {
    final on = _mode == m;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _mode = m),
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
                    text,
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

  Widget _codeInfo(String title, String text) => Column(
    children: [
      const SizedBox(height: 20),
      Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: LP.cyan.withValues(alpha: 0.15),
        ),
        child: const Icon(
          Icons.mark_email_read_rounded,
          color: LP.cyan,
          size: 50,
        ),
      ),
      const SizedBox(height: 16),
      Text(
        title,
        textAlign: TextAlign.center,
        style: outfit(26, w: FontWeight.w900),
      ),
      const SizedBox(height: 6),
      Text(
        text,
        textAlign: TextAlign.center,
        style: jakarta(14, color: LP.muted),
      ),
      const SizedBox(height: 22),
    ],
  );

  List<Widget> _codeStep() => [
    _codeInfo(
      'Doğrulama Kodu',
      '${_email.text.trim()} adresine 6 haneli bir kod gönderdik. Gelen kutunu (ve spam klasörünü) kontrol et.',
    ),
    LpField(
      controller: _code,
      hint: '······',
      icon: Icons.pin_rounded,
      keyboard: TextInputType.number,
      maxLength: 6,
      center: true,
      onSubmitted: (_) => _submitCode(),
    ),
    const SizedBox(height: 22),
    _primary('ONAYLA', _submitCode),
    TextButton(
      onPressed:
          _busy
              ? null
              : () => _run(() async {
                await Cloud.linkEmailStart(_email.text);
                if (mounted) toast(context, 'Kod tekrar gönderildi.');
              }),
      child: Text('Kodu tekrar gönder', style: outfit(14, color: LP.cyan)),
    ),
  ];

  List<Widget> _forgotEmail() => [
    _codeInfo(
      'Şifremi Unuttum',
      'Hesabının e-posta adresini gir, sana bir sıfırlama kodu gönderelim.',
    ),
    LpField(
      controller: _email,
      hint: 'ornek@mail.com',
      icon: Icons.mail_outline_rounded,
      keyboard: TextInputType.emailAddress,
    ),
    const SizedBox(height: 22),
    _primary('KOD GÖNDER', () {
      if (!_validEmail()) return;
      _run(() async {
        await Cloud.sendReset(_email.text);
        if (mounted) setState(() => _step = _Step.forgotCode);
      });
    }),
  ];

  List<Widget> _forgotCode() => [
    _codeInfo(
      'Yeni Şifre Belirle',
      '${_email.text.trim()} adresine gelen 6 haneli kodu ve yeni şifreni gir.',
    ),
    LpField(
      controller: _code,
      hint: '······',
      icon: Icons.pin_rounded,
      keyboard: TextInputType.number,
      maxLength: 6,
      center: true,
    ),
    const SizedBox(height: 12),
    LpField(
      controller: _newPass,
      hint: 'Yeni şifre (en az 6 karakter)',
      icon: Icons.lock_reset_rounded,
      password: true,
    ),
    const SizedBox(height: 22),
    _primary('ŞİFREYİ GÜNCELLE', () {
      if (_code.text.trim().length < 6) {
        toast(context, '6 haneli kodu gir.', error: true);
        return;
      }
      if (!_validPass(_newPass)) return;
      _run(() async {
        await Cloud.verifyReset(_email.text, _code.text, _newPass.text);
        if (mounted) {
          toast(context, 'Şifren güncellendi, giriş yapıldı!');
          Navigator.pop(context, true);
        }
      });
    }),
  ];
}
