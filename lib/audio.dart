import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ses efektleri, müzik ve titreşim. Ayarlar cihazda saklanır.
class Sfx {
  static bool sound = true, music = true, vibration = true;
  static bool _ready = false;
  static final _music = AudioPlayer(playerId: 'music');
  static final Map<String, AudioPool> _pools = {};
  static String? _track;
  static SharedPreferences? _prefs;

  static const _effects = [
    'pop0', 'pop1', 'pop2', 'pop3', 'shoot', 'bounce', 'stick', 'drop', //
    'stone', 'click', 'coin', 'fire', 'laser', 'rainbow', 'row', 'win',
    'lose', 'star', 'combo',
  ];

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    sound = _prefs!.getBool('snd') ?? true;
    music = _prefs!.getBool('mus') ?? true;
    vibration = _prefs!.getBool('vib') ?? true;
    if (kIsWeb || const bool.fromEnvironment('FLUTTER_TEST')) return;
    try {
      AudioCache.instance = AudioCache(prefix: 'assets/audio/');
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(
          focus: AudioContextConfigFocus.mixWithOthers,
        ).build(),
      );
      for (final e in _effects) {
        _pools[e] = await AudioPool.createFromAsset(
          path: '$e.wav',
          maxPlayers: e.startsWith('pop') ? 4 : 2,
        );
      }
      await _music.setReleaseMode(ReleaseMode.loop);
      await _music.setVolume(0.45);
      _ready = true;
      // yüklenirken istenen müziği şimdi başlat
      final t = _track;
      if (t != null) {
        _track = null;
        await playMusic(t);
      }
    } catch (e) {
      debugPrint('Ses başlatılamadı: $e');
    }
  }

  static void play(String name, {double volume = 1}) {
    if (!sound || !_ready) return;
    _pools[name]?.start(volume: volume);
  }

  /// Patlama sesi: kombo arttıkça tizleşir.
  static void pop(int combo) => play('pop${min(3, max(0, combo - 1))}');

  static void haptic([int strength = 1]) {
    if (!vibration) return;
    switch (strength) {
      case 0:
        HapticFeedback.selectionClick();
      case 1:
        HapticFeedback.lightImpact();
      case 2:
        HapticFeedback.mediumImpact();
      default:
        HapticFeedback.heavyImpact();
    }
  }

  /// 'menu' ya da 'game' müziğini başlatır (zaten çalıyorsa dokunmaz).
  static Future<void> playMusic(String track) async {
    if (_track == track && _music.state == PlayerState.playing) return;
    _track = track;
    if (!music || !_ready) return;
    try {
      await _music.stop();
      await _music.play(AssetSource('music_$track.wav'));
    } catch (_) {}
  }

  static Future<void> pauseMusic() async {
    if (_ready) await _music.pause();
  }

  static Future<void> resumeMusic() async {
    if (_ready && music && _track != null) await _music.resume();
  }

  static Future<void> set({bool? sound, bool? music, bool? vibration}) async {
    if (sound != null) Sfx.sound = sound;
    if (vibration != null) Sfx.vibration = vibration;
    if (music != null) {
      Sfx.music = music;
      if (music && _track != null) {
        await playMusic(_track!);
      } else if (!music && _ready) {
        await _music.stop();
      }
    }
    await _prefs?.setBool('snd', Sfx.sound);
    await _prefs?.setBool('mus', Sfx.music);
    await _prefs?.setBool('vib', Sfx.vibration);
  }
}
