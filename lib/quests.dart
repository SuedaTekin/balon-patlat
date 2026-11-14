import 'dart:math';

import 'package:flutter/material.dart';

import 'game.dart';
import 'progress.dart';

class QuestDef {
  const QuestDef({
    required this.id,
    required this.icon,
    required this.color,
    required this.title,
    required this.desc,
    required this.stat,
    required this.target,
    required this.reward,
  });
  final String id;
  final IconData icon;
  final Color color;
  final String title, desc, stat;
  final int target;
  final Reward reward;

  int get progress => min(Progress.stat(stat), target);
  bool get done => progress >= target;
  bool get claimed => Progress.isClaimed(id);
  bool get ready => done && !claimed;
}

const questPool = <QuestDef>[
  QuestDef(
    id: 'pop',
    icon: Icons.bubble_chart_rounded,
    color: Color(0xFF00D8F5),
    title: 'Balon Avcısı',
    desc: 'Bölümlerde 150 balon patlat',
    stat: 'pop',
    target: 150,
    reward: Reward(coins: 100),
  ),
  QuestDef(
    id: 'pink',
    icon: Icons.favorite_rounded,
    color: Color(0xFFFF4E7C),
    title: 'Pembe Balon Ustası',
    desc: 'Bölümlerde 40 pembe balon patlat',
    stat: 'pop_c0',
    target: 40,
    reward: Reward(coins: 80),
  ),
  QuestDef(
    id: 'gold',
    icon: Icons.wb_sunny_rounded,
    color: Color(0xFFFFB800),
    title: 'Altın Avı',
    desc: 'Bölümlerde 40 sarı balon patlat',
    stat: 'pop_c2',
    target: 40,
    reward: Reward(coins: 80),
  ),
  QuestDef(
    id: 'win',
    icon: Icons.emoji_events_rounded,
    color: Color(0xFFFFB800),
    title: 'Galibiyet Serisi',
    desc: '3 bölüm kazan',
    stat: 'win',
    target: 3,
    reward: Reward(coins: 120),
  ),
  QuestDef(
    id: 'star3',
    icon: Icons.star_rounded,
    color: Color(0xFFFFB800),
    title: 'Yıldız Toplayıcı',
    desc: '2 bölümü 3 yıldızla bitir',
    stat: 'star3',
    target: 2,
    reward: Reward(coins: 100, boosters: {Booster.rainbow: 1}),
  ),
  QuestDef(
    id: 'booster',
    icon: Icons.rocket_launch_rounded,
    color: Color(0xFF00E5FF),
    title: 'Güç Kullan',
    desc: 'Bölümlerde 3 güçlendirici kullan',
    stat: 'booster',
    target: 3,
    reward: Reward(coins: 60, boosters: {Booster.fire: 1}),
  ),
  QuestDef(
    id: 'combo',
    icon: Icons.bolt_rounded,
    color: Color(0xFFFFB800),
    title: 'Kombo Fırtınası',
    desc: '3 kez X3 veya üstü kombo yap',
    stat: 'combo3',
    target: 3,
    reward: Reward(coins: 120),
  ),
  QuestDef(
    id: 'drop',
    icon: Icons.south_rounded,
    color: Color(0xFF10E56A),
    title: 'Düşür Hepsini',
    desc: 'Tavandan kopararak 40 balon düşür',
    stat: 'drop',
    target: 40,
    reward: Reward(coins: 100),
  ),
  QuestDef(
    id: 'spin',
    icon: Icons.casino_rounded,
    color: Color(0xFFA25CFF),
    title: 'Şansını Dene',
    desc: 'Günlük şans çarkını çevir',
    stat: 'spin',
    target: 1,
    reward: Reward(coins: 50),
  ),
];

/// Her gün tarihe göre aynı 3 görev seçilir.
List<QuestDef> dailyQuests() {
  final now = DateTime.now();
  final seed = now.year * 10000 + now.month * 100 + now.day;
  final list = List.of(questPool)..shuffle(Random(seed));
  return list.take(3).toList();
}

const dailyBonus = Reward(coins: 300, boosters: {Booster.rainbow: 1});
const bonusId = 'bonus';

bool get bonusReady =>
    dailyQuests().every((q) => q.claimed) && !Progress.isClaimed(bonusId);

int get readyQuestCount =>
    dailyQuests().where((q) => q.ready).length + (bonusReady ? 1 : 0);
