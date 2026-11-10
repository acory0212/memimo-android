import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import '../models/word.dart';
import 'sm2.dart';

class DailyStat {
  final String date; // yyyy-MM-dd
  int newWords;
  int reviews;
  int studySeconds;

  DailyStat({required this.date, this.newWords = 0, this.reviews = 0, this.studySeconds = 0});

  Map<String, dynamic> toJson() =>
      {'d': date, 'n': newWords, 'r': reviews, 's': studySeconds};

  factory DailyStat.fromJson(Map<String, dynamic> j) => DailyStat(
        date: j['d'] as String,
        newWords: (j['n'] as num?)?.toInt() ?? 0,
        reviews: (j['r'] as num?)?.toInt() ?? 0,
        studySeconds: (j['s'] as num?)?.toInt() ?? 0,
      );
}

/// 本地存储：词库 + 学习进度 + 设置 + 统计
class Store {
  static final Store I = Store._();
  Store._();

  final Map<int, WordProgress> progress = {};
  final Map<String, DailyStat> stats = {};
  final Set<int> favorites = {};
  final List<int> customBook = [];

  List<Word> allWords = [];
  final Map<int, Word> _byId = {};
  final Map<String, int> _byWord = {};

  Directory? _dir;
  bool ready = false;

  int dailyNewLimit = 20;
  double dailyGoalHours = 1.0;

  /// 是否对每日新词做随机抽取（否则按词库原顺序）
  bool randomNewWords = true;

  /// 随机种子：每天固定，点「随机抽取」会换一个新的，
  /// 这样同一天内多次进入 App 抽到的词保持一致。
  int shuffleSeed = 0;

  Word? wordById(int id) => _byId[id];
  Word? wordByText(String w) => _byId[_byWord[w.toLowerCase()]];

  File? _f(String name) => _dir == null ? null : File('${_dir!.path}/$name');

  Future<void> init() async {
    if (ready) return;
    _dir = await getApplicationSupportDirectory();
    if (!_dir!.existsSync()) _dir!.createSync(recursive: true);

    await _loadWords();
    _loadProgress();
    _loadStats();
    _loadMeta();
    ready = true;
  }

  Future<void> _loadWords() async {
    final raw = await rootBundle.loadString('assets/data/words_cet4.json');
    final list = jsonDecode(raw) as List<dynamic>;
    allWords = list.whereType<Map<String, dynamic>>().map(Word.fromJson).toList();
    _byId.clear();
    _byWord.clear();
    for (final w in allWords) {
      _byId[w.id] = w;
      _byWord[w.word.toLowerCase()] = w.id;
    }
  }

  String? _read(String name) {
    final f = _f(name);
    if (f == null || !f.existsSync()) return null;
    try {
      return f.readAsStringSync();
    } catch (_) {
      return null;
    }
  }

  void _write(String name, Object value) {
    try {
      _f(name)?.writeAsStringSync(jsonEncode(value), flush: true);
    } catch (_) {}
  }

  void _loadProgress() {
    progress.clear();
    final raw = _read('progress.json');
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      j.forEach((k, v) {
        final id = int.tryParse(k);
        if (id != null && v is Map<String, dynamic>) {
          progress[id] = WordProgress.fromJson(v);
        }
      });
    } catch (_) {}
  }

  void _loadStats() {
    stats.clear();
    final raw = _read('stats.json');
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      j.forEach((k, v) {
        if (v is Map<String, dynamic>) stats[k] = DailyStat.fromJson(v);
      });
    } catch (_) {}
  }

  void _loadMeta() {
    favorites.clear();
    customBook.clear();
    final raw = _read('meta.json');
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      if (j['fav'] is List) {
        for (final e in (j['fav'] as List)) {
          if (e is num) favorites.add(e.toInt());
        }
      }
      if (j['book'] is List) {
        for (final e in (j['book'] as List)) {
          if (e is num) customBook.add(e.toInt());
        }
      }
      dailyNewLimit = (j['newLimit'] as num?)?.toInt() ?? 20;
      dailyGoalHours = (j['goal'] as num?)?.toDouble() ?? 1.0;
      randomNewWords = (j['randomOrder'] as bool?) ?? true;
      shuffleSeed = (j['shuffleSeed'] as num?)?.toInt() ?? 0;
    } catch (_) {}
  }

  void saveProgress() => _write('progress.json',
      progress.map((k, v) => MapEntry(k.toString(), v.toJson())));
  void saveStats() =>
      _write('stats.json', stats.map((k, v) => MapEntry(k, v.toJson())));
  void saveMeta() => _write('meta.json', {
        'fav': favorites.toList(),
        'book': customBook,
        'newLimit': dailyNewLimit,
        'goal': dailyGoalHours,
        'randomOrder': randomNewWords,
        'shuffleSeed': shuffleSeed,
      });

  static String todayKey([DateTime? d]) {
    final n = d ?? DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-'
        '${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  DailyStat todayStat() {
    final k = todayKey();
    return stats[k] ??= DailyStat(date: k);
  }

  // ---------- 学习队列 ----------

  List<Word> dueReviews({DateTime? at}) {
    final now = at ?? DateTime.now();
    final out = <Word>[];
    progress.forEach((id, p) {
      if (p.reviewCount > 0 && !p.dueDate.isAfter(now)) {
        final w = _byId[id];
        if (w != null) out.add(w);
      }
    });
    out.sort((a, b) => progress[a.id]!.dueDate.compareTo(progress[b.id]!.dueDate));
    return out;
  }

  /// 每日稳定的随机种子（FNV-1a 哈希，保证同一天同一种子结果一致）
  int _dailySeed() {
    var h = 0x811C9DC5;
    final key = '${todayKey()}#$shuffleSeed';
    for (final c in key.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0x7FFFFFFF;
    }
    return h;
  }

  /// 今日要学的新词。
  ///
  /// 随机模式下先用 Fisher-Yates 整体打乱词库（种子 = 日期 + shuffleSeed），
  /// 再按打乱后的顺序取前 N 个未学过的词：
  /// - 同一天内结果稳定（重启 App、反复进入首页都不变）
  /// - 已学过的词自动跳过，不会重复出现
  /// - 点「随机抽取」换种子即重新洗牌
  List<Word> newWords() {
    final learned = progress.keys.toSet();
    final today = todayStat();
    final remaining = (dailyNewLimit - today.newWords).clamp(0, dailyNewLimit);
    if (remaining <= 0) return const [];

    final pool = (customBook.isNotEmpty
            ? customBook.map((id) => _byId[id]).whereType<Word>()
            : allWords)
        .toList();
    if (randomNewWords) {
      pool.shuffle(Random(_dailySeed()));
    }

    final out = <Word>[];
    for (final w in pool) {
      if (!learned.contains(w.id)) {
        out.add(w);
        if (out.length >= remaining) break;
      }
    }
    return out;
  }

  /// 重新抽取今日新词（换一个随机种子）
  void reshuffleNewWords() {
    shuffleSeed = Random().nextInt(1 << 30);
    saveMeta();
  }

  void setRandomNewWords(bool value) {
    randomNewWords = value;
    saveMeta();
  }

  void applyReview(Word w, int grade) {
    final p = progress[w.id] ?? WordProgress.initial(DateTime.now());
    final isNew = p.reviewCount == 0;
    final r = Sm2.review(p, grade, DateTime.now());
    progress[w.id] = r.progress;
    final st = todayStat();
    if (isNew) {
      st.newWords += 1;
    } else {
      st.reviews += 1;
    }
    saveProgress();
    saveStats();
  }

  void markUnknown(Word w) {
    progress[w.id] = WordProgress.initial(DateTime.now());
    saveProgress();
  }

  void addStudySeconds(int sec) {
    todayStat().studySeconds += sec;
    saveStats();
  }

  void toggleFavorite(int id) {
    if (!favorites.remove(id)) favorites.add(id);
    saveMeta();
  }

  void setDailyNewLimit(int n) {
    dailyNewLimit = n;
    saveMeta();
  }

  // ---------- 统计 ----------

  int get totalLearned => progress.values.where((p) => p.reviewCount > 0).length;

  int get masteredCount =>
      progress.values.where((p) => p.repetitions >= 3 && p.interval >= 21).length;

  int get streak {
    var n = 0;
    var d = DateTime.now();
    var first = true;
    while (true) {
      final st = stats[todayKey(d)];
      if (st != null && (st.newWords > 0 || st.reviews > 0)) {
        n++;
      } else if (!first) {
        break;
      }
      first = false;
      d = d.subtract(const Duration(days: 1));
      if (n > 1000) break;
    }
    return n;
  }

  List<DailyStat> recentStats(int days) {
    final out = <DailyStat>[];
    final now = DateTime.now();
    for (var i = days - 1; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      out.add(stats[todayKey(d)] ?? DailyStat(date: todayKey(d)));
    }
    return out;
  }
}
