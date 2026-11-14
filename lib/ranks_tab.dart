import 'package:flutter/material.dart';

import 'progress.dart';
import 'theme.dart';

class LocalRecords extends StatelessWidget {
  const LocalRecords({super.key});

  @override
  Widget build(BuildContext context) {
    final records =
        Progress.bestScores.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    final completed = Progress.stars.length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: _stat(
                Icons.star_rounded,
                LP.gold,
                'Toplam Yıldız',
                '${Progress.totalStars}',
                '/ ${completed * 3}',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _stat(
                Icons.flag_rounded,
                LP.cyan,
                'Ulaşılan Seviye',
                '${Progress.unlocked}',
                '',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _stat(
          Icons.military_tech_rounded,
          LP.pink,
          'Toplam Rekor Puanı',
          formatNum(Progress.totalScore),
          '',
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: glassCard(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('BUGÜN', style: outfit(13, color: LP.cyan, spacing: 1.5)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _mini('Patlatılan', Progress.stat('pop')),
                  _mini('Düşürülen', Progress.stat('drop')),
                  _mini('Kazanılan', Progress.stat('win')),
                  _mini('3 Yıldız', Progress.stat('star3')),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const Icon(Icons.leaderboard_rounded, color: LP.gold),
            const SizedBox(width: 8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Bölüm Rekorların',
                  style: outfit(22, w: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (records.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: glassCard(),
            child: Text(
              'Henüz rekor yok — ilk bölümü oyna!',
              textAlign: TextAlign.center,
              style: jakarta(15, color: LP.muted),
            ),
          ),
        for (var i = 0; i < records.length && i < 30; i++)
          _row(i + 1, records[i].key, records[i].value),
      ],
    );
  }

  Widget _stat(
    IconData icon,
    Color color,
    String label,
    String value,
    String suffix,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: glassCard(),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.18),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  child: Text(label, style: jakarta(12, color: LP.muted)),
                ),
                FittedBox(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: value,
                          style: outfit(24, w: FontWeight.w900),
                        ),
                        TextSpan(
                          text: ' $suffix',
                          style: outfit(13, color: LP.muted),
                        ),
                      ],
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

  Widget _mini(String label, int v) => Expanded(
    child: Column(
      children: [
        Text(formatNum(v), style: outfit(20, w: FontWeight.w900)),
        FittedBox(child: Text(label, style: jakarta(11, color: LP.muted))),
      ],
    ),
  );

  Widget _row(int rank, int level, int score) {
    final s = Progress.stars[level] ?? 0;
    final medal = switch (rank) {
      1 => LP.gold,
      2 => const Color(0xFFC9D3E6),
      3 => const Color(0xFFE09A5C),
      _ => LP.surfaceHighest,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: glassCard(radius: 20),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: medal),
            child: Text(
              '$rank',
              style: outfit(
                15,
                w: FontWeight.w900,
                color: rank <= 3 ? const Color(0xFF2A1A00) : LP.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text('Seviye $level', style: outfit(17))),
          for (var i = 0; i < 3; i++)
            Icon(
              Icons.star_rounded,
              size: 18,
              color: i < s ? LP.gold : LP.surfaceHighest,
            ),
          const SizedBox(width: 10),
          SizedBox(
            width: 84,
            child: Text(
              formatNum(score),
              textAlign: TextAlign.right,
              style: outfit(17, color: LP.gold),
            ),
          ),
        ],
      ),
    );
  }
}
