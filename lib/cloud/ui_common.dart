import 'package:flutter/material.dart';

import '../theme.dart';
import 'cloud.dart';

class LpField extends StatefulWidget {
  const LpField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.password = false,
    this.keyboard,
    this.maxLength,
    this.onSubmitted,
    this.center = false,
  });
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool password, center;
  final TextInputType? keyboard;
  final int? maxLength;
  final ValueChanged<String>? onSubmitted;

  @override
  State<LpField> createState() => _LpFieldState();
}

class _LpFieldState extends State<LpField> {
  bool _hide = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: widget.password && _hide,
      keyboardType: widget.keyboard,
      maxLength: widget.maxLength,
      onSubmitted: widget.onSubmitted,
      textAlign: widget.center ? TextAlign.center : TextAlign.start,
      style:
          widget.center
              ? outfit(28, w: FontWeight.w900, spacing: 8)
              : jakarta(16),
      decoration: InputDecoration(
        counterText: '',
        hintText: widget.hint,
        hintStyle: jakarta(15, color: LP.muted),
        prefixIcon: widget.center ? null : Icon(widget.icon, color: LP.muted),
        suffixIcon:
            widget.password
                ? IconButton(
                  icon: Icon(
                    _hide
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    color: LP.muted,
                  ),
                  onPressed: () => setState(() => _hide = !_hide),
                )
                : null,
        filled: true,
        fillColor: LP.bgDeep.withValues(alpha: 0.6),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: LP.cyan, width: 2),
        ),
      ),
    );
  }
}

void toast(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? LP.rubyLedge : const Color(0xFF15405A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        content: Text(msg, style: jakarta(14)),
      ),
    );
}

/// Hata yakalayıp toast gösteren yardımcı; başarılıysa true.
Future<bool> runCloud(BuildContext context, Future<void> Function() f) async {
  try {
    await f();
    return true;
  } on CloudError catch (e) {
    if (context.mounted) toast(context, e.message, error: true);
  } catch (e) {
    if (context.mounted) toast(context, 'Hata: $e', error: true);
  }
  return false;
}

/// Sunucu kapalı / bağlantı yok kartı.
class OfflineCard extends StatelessWidget {
  const OfflineCard({super.key, this.onRetry});
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final configured = Cloud.enabled;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: glassCard(),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, color: LP.muted, size: 48),
          const SizedBox(height: 10),
          Text(
            configured
                ? 'Sunucuya bağlanılamadı'
                : 'Çevrimiçi özellikler kapalı',
            textAlign: TextAlign.center,
            style: outfit(18, w: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            configured
                ? 'İnternet bağlantını kontrol edip tekrar dene.'
                : 'Sunucu ayarları henüz yapılmadı.',
            textAlign: TextAlign.center,
            style: jakarta(13, color: LP.muted),
          ),
          if (configured && onRetry != null) ...[
            const SizedBox(height: 14),
            JuicyButton.cyan(
              height: 50,
              onTap: onRetry,
              child: Text(
                'TEKRAR DENE',
                style: outfit(
                  17,
                  w: FontWeight.w900,
                  color: const Color(0xFF00363D),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String timeAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'şimdi';
  if (d.inHours < 1) return '${d.inMinutes} dk önce';
  if (d.inDays < 1) return '${d.inHours} sa önce';
  return '${d.inDays} gün önce';
}
