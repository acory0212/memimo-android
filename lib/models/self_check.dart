import 'word.dart';

/// 自检题型
enum SelfCheckType {
  /// 看英文单词，选中文意思
  choice,

  /// 看中文意思，写英文单词
  spelling,
}

/// 一道自我检查题
class SelfCheckQuestion {
  final Word word;
  final SelfCheckType type;

  /// 题干：选择题是英文单词，拼写题是中文意思
  final String prompt;

  /// 正确答案：选择题是中文释义，拼写题是英文单词
  final String answer;

  /// 选择题的 4 个选项；拼写题为空
  final List<String> options;

  const SelfCheckQuestion({
    required this.word,
    required this.type,
    required this.prompt,
    required this.answer,
    this.options = const [],
  });

  bool get isSpelling => type == SelfCheckType.spelling;

  /// 判断作答是否正确（忽略大小写和首尾空格）
  bool check(String input) =>
      input.trim().toLowerCase() == answer.trim().toLowerCase();
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
