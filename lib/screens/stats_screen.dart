import 'package:flutter/material.dart';

import '../services/ebbinghaus.dart';
import '../services/store.dart';
import '../theme.dart';

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
                      color: AppPalette.primary)),
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
                                        ? AppPalette.primary
                                        : AppPalette.primary
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
          const _CurveCard(),
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

class _CurveCard extends StatelessWidget {
  const _CurveCard();

  @override
  Widget build(BuildContext context) {
    final s = Store.I;
    if (!s.useEbbinghaus) return const SizedBox.shrink();

    final dist = s.stageDistribution;
    final total = dist.fold<int>(0, (a, b) => a + b);
    if (total == 0) return const SizedBox.shrink();

    // 只展示到最后一个有词的阶段，最少展示前 3 级，避免一堆空条
    var last = 2;
    for (var i = 0; i < dist.length; i++) {
      if (dist[i] > 0) last = i;
    }
    final maxV = dist.fold<int>(1, (a, b) => a > b ? a : b);
    final mastered = s.masteredCount;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline, size: 15, color: AppPalette.primary),
              const SizedBox(width: 6),
              const Text('遗忘曲线进度',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('$total 词',
                  style:
                      TextStyle(fontSize: 11.5, color: Colors.grey.shade500)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '已进入长期记忆（30 天及以后）$mastered 词',
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i <= last; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                children: [
                  SizedBox(
                    width: 52,
                    child: Text(
                      Ebbinghaus.stageLabels[i],
                      style: TextStyle(
                        fontSize: 11,
                        color: i >= Ebbinghaus.masteredStage
                            ? AppPalette.primaryDark
                            : Colors.grey.shade600,
                        fontWeight: i >= Ebbinghaus.masteredStage
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: dist[i] / maxV,
                        minHeight: 8,
                        backgroundColor: Colors.grey.shade100,
                        valueColor: AlwaysStoppedAnimation(
                          i >= Ebbinghaus.masteredStage
                              ? AppPalette.primary
                              : AppPalette.primary.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 30,
                    child: Text(
                      dist[i] == 0 ? '' : '${dist[i]}',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600),
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

class _XpTip extends StatelessWidget {
  const _XpTip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.soft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.tips_and_updates_outlined,
              size: 18, color: AppPalette.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              Store.I.useEbbinghaus
                  ? '艾宾浩斯曲线：答「认识」推进一级、「熟悉」跳一级、'
                      '「不认识」回到起点重走。\n'
                      '走到 30 天以上（第 8 级）算「已掌握」。'
                  : 'SM-2 自适应：连续 3 次答对且间隔 ≥ 21 天算「已掌握」。\n'
                      '选择「不认识」的单词会重新进入队列，并在错题本中累计。',
              style: TextStyle(
                  fontSize: 12.5, height: 1.65, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }
}
