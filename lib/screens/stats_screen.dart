import 'package:flutter/material.dart';

import '../services/store.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Store.I;
    final recent = s.recentStats(14);
    final maxCount = recent
        .map((d) => d.newWords + d.reviews)
        .fold<int>(1, (a, b) => a > b ? a : b);
    final totalNew = recent.fold<int>(0, (a, d) => a + d.newWords);
    final totalRev = recent.fold<int>(0, (a, d) => a + d.reviews);
    final totalMin = (recent.fold<int>(0, (a, d) => a + d.studySeconds) / 60).round();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: [
          const Text('学习统计',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                  child: _BigStat(
                      value: '${s.totalLearned}',
                      label: '累计已学',
                      unit: '词',
                      color: const Color(0xFF4A7C59))),
              const SizedBox(width: 12),
              Expanded(
                  child: _BigStat(
                      value: '${s.masteredCount}',
                      label: '已掌握',
                      unit: '词',
                      color: const Color(0xFF1565C0))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _BigStat(
                      value: '${s.streak}',
                      label: '连续打卡',
                      unit: '天',
                      color: const Color(0xFFE65100))),
              const SizedBox(width: 12),
              Expanded(
                  child: _BigStat(
                      value: '${s.allWords.length}',
                      label: '词库总量',
                      unit: '词',
                      color: const Color(0xFF6A1B9A))),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('最近 14 天',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('新词 $totalNew · 复习 $totalRev · 学习 $totalMin 分钟',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 16),
                SizedBox(
                  height: 140,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < recent.length; i++) ...[
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (recent[i].newWords + recent[i].reviews > 0)
                                Text(
                                  '${recent[i].newWords + recent[i].reviews}',
                                  style: TextStyle(
                                      fontSize: 9,
                                      color: Colors.grey.shade500),
                                ),
                              const SizedBox(height: 2),
                              Flexible(
                                child: Container(
                                  constraints: const BoxConstraints(minHeight: 3),
                                  height: ((recent[i].newWords + recent[i].reviews) /
                                          maxCount) *
                                      100 +
                                      3,
                                  decoration: BoxDecoration(
                                    color: i == recent.length - 1
                                        ? const Color(0xFF4A7C59)
                                        : const Color(0xFF4A7C59)
                                            .withValues(alpha: 0.35),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                i == recent.length - 1
                                    ? '今天'
                                    : '${recent[i].date.substring(8)}日',
                                style: TextStyle(
                                    fontSize: 9, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        ),
                        if (i != recent.length - 1) const SizedBox(width: 3),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _XpTip(),
        ],
      ),
    );
  }
}

class _BigStat extends StatelessWidget {
  final String value;
  final String label;
  final String unit;
  final Color color;

  const _BigStat({
    required this.value,
    required this.label,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w700, color: color)),
              const SizedBox(width: 3),
              Text(unit,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

class _XpTip extends StatelessWidget {
  const _XpTip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7F4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.tips_and_updates_outlined,
              size: 18, color: Color(0xFF4A7C59)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '记忆强度 ≥ 3 次复习且间隔 ≥ 21 天时算「已掌握」。\n'
              '选择「忘记」的单词会重新进入队列，并在错题本中累计。',
              style: TextStyle(
                  fontSize: 12.5, height: 1.65, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }
}
