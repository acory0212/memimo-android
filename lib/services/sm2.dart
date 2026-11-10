/// 单个单词的记忆状态（SM-2 算法的数据载体）
class WordProgress {
  /// 再次出现间隔（天）
  final double interval;

  /// 简单难度因子（SM-2 的 EF，最小 1.3）
  final double easeFactor;

  /// 连续答对次数
  final int repetitions;

  /// 下次复习时间
  final DateTime dueDate;

  /// 累计复习次数
  final int reviewCount;

  /// 累计遗忘（答"忘记"）次数
  final int lapseCount;

  /// 最近一次评价：0=忘记 1=模糊 2=一般 3=熟悉 4=秒杀
  final int lastGrade;

  const WordProgress({
    required this.interval,
    required this.easeFactor,
    required this.repetitions,
    required this.dueDate,
    required this.reviewCount,
    required this.lapseCount,
    required this.lastGrade,
  });

  factory WordProgress.initial(DateTime now) => WordProgress(
        interval: 0,
        easeFactor: 2.5,
        repetitions: 0,
        dueDate: now,
        reviewCount: 0,
        lapseCount: 0,
        lastGrade: -1,
      );

  factory WordProgress.fromJson(Map<String, dynamic> j) => WordProgress(
        interval: (j['i'] as num).toDouble(),
        easeFactor: (j['e'] as num).toDouble(),
        repetitions: (j['r'] as num).toInt(),
        dueDate: DateTime.fromMillisecondsSinceEpoch((j['d'] as num).toInt()),
        reviewCount: (j['rc'] as num).toInt(),
        lapseCount: (j['lc'] as num?)?.toInt() ?? 0,
        lastGrade: (j['g'] as num?)?.toInt() ?? -1,
      );

  Map<String, dynamic> toJson() => {
        'i': interval,
        'e': easeFactor,
        'r': repetitions,
        'd': dueDate.millisecondsSinceEpoch,
        'rc': reviewCount,
        'lc': lapseCount,
        'g': lastGrade,
      };

  WordProgress copyWith({
    double? interval,
    double? easeFactor,
    int? repetitions,
    DateTime? dueDate,
    int? reviewCount,
    int? lapseCount,
    int? lastGrade,
  }) =>
      WordProgress(
        interval: interval ?? this.interval,
        easeFactor: easeFactor ?? this.easeFactor,
        repetitions: repetitions ?? this.repetitions,
        dueDate: dueDate ?? this.dueDate,
        reviewCount: reviewCount ?? this.reviewCount,
        lapseCount: lapseCount ?? this.lapseCount,
        lastGrade: lastGrade ?? this.lastGrade,
      );
}

class Sm2Result {
  final WordProgress progress;
  final DateTime now;

  Sm2Result(this.progress, this.now);
}

/// SM-2 间隔重复算法（改进版，参考墨墨/Anki 的 5 档评分）
class Sm2 {
  /// [grade] 0..4
  /// 0=忘记 1=模糊 2=一般 3=熟悉 4=秒杀
  static Sm2Result review(WordProgress p, int grade, DateTime now) {
    double ef = p.easeFactor;
    int reps = p.repetitions;
    double interval;

    // 难度因子调整（SM-2 标准公式，映射到 0..5 量表）
    // grade 0 -> q=0, 1->q=2, 2->q=3, 3->q=4, 4->q=5
    final int q = switch (grade) {
      0 => 0,
      1 => 2,
      2 => 3,
      3 => 4,
      _ => 5,
    };
    ef = ef + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02));
    if (ef < 1.3) ef = 1.3;

    if (grade == 0) {
      // 忘记：重置
      reps = 0;
      interval = 0; // 当天再来
    } else if (grade == 1) {
      // 模糊：短间隔重复，不推进
      reps = 0;
      interval = 0.04; // 约 1 小时后再出现（学习日内）
    } else {
      reps += 1;
      if (reps == 1) {
        interval = grade >= 3 ? 1.0 : 0.5;
      } else if (reps == 2) {
        interval = grade >= 3 ? 3.0 : 2.0;
      } else {
        interval = p.interval <= 0 ? 1.0 : p.interval * ef;
        // 上限一年
        if (interval > 365) interval = 365;
      }
    }

    final DateTime due = interval <= 0
        ? now.add(const Duration(minutes: 10))
        : now.add(Duration(minutes: (interval * 24 * 60).round()));

    return Sm2Result(
      p.copyWith(
        interval: interval,
        easeFactor: ef,
        repetitions: reps,
        dueDate: due,
        reviewCount: p.reviewCount + 1,
        lapseCount: grade == 0 ? p.lapseCount + 1 : p.lapseCount,
        lastGrade: grade,
      ),
      now,
    );
  }

  /// 预测下次间隔（用于按钮上的提示文字）
  static String predictLabel(WordProgress p, int grade) {
    final r = review(p, grade, DateTime.now());
    final d = r.progress.interval;
    if (d <= 0) return '10分钟';
    if (d < 1) return '${(d * 24).round()}小时';
    if (d < 30) return '${d.round()}天';
    if (d < 365) return '${(d / 30).round()}个月';
    return '${(d / 365).toStringAsFixed(1)}年';
  }
}
