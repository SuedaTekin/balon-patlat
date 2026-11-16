import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'audio.dart';
import 'billing.dart';
import 'cloud/cloud.dart';
import 'cloud/config.dart';
import 'cloud/ui_common.dart';
import 'theme.dart';
import 'widgets.dart';

const appVersion = '1.5.2';

Future<void> showSettings(BuildContext context) =>
    showDialog(context: context, builder: (_) => const _SettingsDialog());

class _SettingsDialog extends StatefulWidget {
  const _SettingsDialog();

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  Widget _switch(IconData icon, String label, bool value, Function(bool) set) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: LP.bgDeep.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: LP.cyan),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: outfit(17))),
          Switch(
            value: value,
            activeColor: LP.cyan,
            onChanged: (v) async {
              await set(v);
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget _link(
    IconData icon,
    String label,
    VoidCallback onTap, {
    Color? color,
  }) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 6),
      leading: Icon(icon, color: color ?? LP.muted),
      title: Text(label, style: outfit(15, color: color ?? LP.onSurface)),
      onTap: onTap,
    );
  }

  Future<void> _deleteAccount() async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => ModalCard(
            title: 'HESABI SİL',
            titleColor: LP.ruby,
            children: [
              Text(
                'Hesabın, buluttaki ilerlemen, takım üyeliğin, arkadaşların ve '
                'sıralamadaki yerin kalıcı olarak silinir. Bu işlem geri alınamaz.',
                textAlign: TextAlign.center,
                style: jakarta(14, color: LP.onSurface),
              ),
              const SizedBox(height: 18),
              JuicyButton.ruby(
                onTap: () => Navigator.pop(ctx, true),
                child: Text(
                  'KALICI OLARAK SİL',
                  style: outfit(18, w: FontWeight.w900, color: Colors.white),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Vazgeç', style: outfit(16, color: LP.muted)),
              ),
            ],
          ),
    );
    if (ok != true || !mounted) return;
    final done = await runCloud(context, Cloud.deleteAccount);
    if (done && mounted) {
      toast(context, 'Hesabın silindi.');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ModalCard(
      title: 'AYARLAR',
      titleColor: LP.cyan,
      children: [
        _switch(
          Icons.volume_up_rounded,
          'Ses Efektleri',
          Sfx.sound,
          (v) => Sfx.set(sound: v),
        ),
        _switch(
          Icons.music_note_rounded,
          'Müzik',
          Sfx.music,
          (v) => Sfx.set(music: v),
        ),
        _switch(
          Icons.vibration_rounded,
          'Titreşim',
          Sfx.vibration,
          (v) => Sfx.set(vibration: v),
        ),
        const SizedBox(height: 6),
        _link(Icons.restore_rounded, 'Satın Alımları Geri Yükle', () async {
          await Billing.restore();
          if (context.mounted) toast(context, 'Satın alımlar kontrol edildi.');
        }),
        _link(
          Icons.privacy_tip_outlined,
          'Gizlilik Politikası',
          () => launchUrl(
            Uri.parse(privacyUrl),
            mode: LaunchMode.externalApplication,
          ),
        ),
        if (Cloud.enabled && Cloud.me != null)
          _link(
            Icons.delete_forever_rounded,
            'Hesabımı Sil',
            _deleteAccount,
            color: LP.pink,
          ),
        const SizedBox(height: 4),
        Text(
          'Balon Patlat v$appVersion',
          textAlign: TextAlign.center,
          style: jakarta(11, color: LP.muted),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Kapat', style: outfit(16, color: LP.muted)),
        ),
      ],
    );
  }
}
