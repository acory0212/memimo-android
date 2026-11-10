import 'word.dart';

/// 一道自我检查题：给英文单词，从 4 个中文释义里选正确的
class SelfCheckQuestion {
  final Word word;

  /// 4 个选项（已打乱）
  final List<String> options;

  /// 正确选项的文本
  final String answer;

  const SelfCheckQuestion({
    required this.word,
    required this.options,
    required this.answer,
  });
}

/// 自检结果
class SelfCheckResult {
  final int total;
  final int correct;
  final List<Word> missed;

  const SelfCheckResult({
    required this.total,
    required this.correct,
    required this.missed,
  });

  double get accuracy => total == 0 ? 0 : correct / total;
  int get percent => (accuracy * 100).round();
}
