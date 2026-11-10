import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import '../models/self_check.dart';
import '../models/word.dart';
import 'ebbinghaus.dart';
import 'sm2.dart';

class DailyStat {
  final String date; // yyyy-MM-dd
  int newWords;
  int reviews;
  int studySeconds;

  /// 每日自我检查：做了多少题、答对多少
  int checkTotal;
  int checkCorrect;

  DailyStat({
    required this.date,
    this.newWords = 0,
    this.reviews = 0,
    this.studySeconds = 0,
    this.checkTotal = 0,
    this.checkCorrect = 0,
  });

  bool get checkDone => checkTotal > 0;

  Map<String, dynamic> toJson() => {
        'd': date,
        'n': newWords,
        'r': reviews,
        's': studySeconds,
        'ct': checkTotal,
        'cc': checkCorrect,
      };

  factory DailyStat.fromJson(Map<String, dynamic> j) => DailyStat(
        date: j['d'] as String,
        newWords: (j['n'] as num?)?.toInt() ?? 0,
        reviews: (j['r'] as num?)?.toInt() ?? 0,
        studySeconds: (j['s'] as num?)?.toInt() ?? 0,
        checkTotal: (j['ct'] as num?)?.toInt() ?? 0,
        checkCorrect: (j['cc'] as num?)?.toInt() ?? 0,
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

  /// 主题色索引（对应 AppPalette.presets）
  int themeIndex = 0;

  /// 记忆算法：0 = 艾宾浩斯曲线（默认），1 = SM-2 自适应
  int memoryMethod = 0;

  /// 自检题型：0 = 仅选择题，1 = 仅拼写题，2 = 混合（默认）
  int selfCheckMode = 2;

  static const int checkChoice = 0;
  static const int checkSpelling = 1;
  static const int checkMixed = 2;

  /// 评价编码版本。3 = 三档（v1.8.0+）；0/缺失 = 老的五档，需要迁移
  int _gradeScale = 0;

  static const int methodEbbinghaus = 0;
  static const int methodSm2 = 1;

  bool get useEbbinghaus => memoryMethod == methodEbbinghaus;

  String get memoryMethodName => useEbbinghaus ? '艾宾浩斯曲线' : 'SM-2 自适应';

  /// 切换记忆算法。切换时把老数据里没算过的阶段一次性固化，
  /// 但不改动任何词的下次复习时间 —— 进度不会突然后退或爆量。
  void setMemoryMethod(int m) {
    memoryMethod = m == methodSm2 ? methodSm2 : methodEbbinghaus;
    if (useEbbinghaus) _migrateStages();
    saveMeta();
  }

  /// 把 SM-2 历史换算成艾宾浩斯阶段并写回（只处理 stage 未初始化的词）
  void _migrateStages() {
    var changed = false;
    progress.forEach((id, p) {
      if (p.stage < 0) {
        progress[id] = p.copyWith(stage: Ebbinghaus.inferStage(p));
        changed = true;
      }
    });
    if (changed) saveProgress();
  }

  /// 某个词当前处在遗忘曲线的第几阶段
  int stageOf(WordProgress p) => Ebbinghaus.stageOf(p);

  /// 评分按钮上的「下次复习」提示，按当前算法算
  String predictLabel(WordProgress p, int grade) =>
      useEbbinghaus ? Ebbinghaus.predictLabel(p, grade) : Sm2.predictLabel(p, grade);

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
    // 老版本的五档评价码 → 三档（v1.8.0 起内部也统一为三档）
    if (_gradeScale < 3) {
      _migrateGradeScale();
      _gradeScale = 3;
      saveMeta();
    }
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
      themeIndex = (j['theme'] as num?)?.toInt() ?? 0;
      memoryMethod = (j['method'] as num?)?.toInt() ?? 0;
      if (memoryMethod != methodSm2) memoryMethod = methodEbbinghaus;
      final cm = (j['checkMode'] as num?)?.toInt() ?? checkMixed;
      selfCheckMode = (cm >= 0 && cm <= 2) ? cm : checkMixed;
      _gradeScale = (j['gradeScale'] as num?)?.toInt() ?? 0;
    } catch (_) {}
  }

  /// 把老的五档评价码（0..4）迁移成三档（0..2）
  void _migrateGradeScale() {
    var changed = false;
    for (final id in progress.keys.toList()) {
      final p = progress[id]!;
      if (p.lastGrade < 0) continue;
      final g = p.lastGrade >= 3 ? 2 : (p.lastGrade >= 1 ? 1 : 0);
      if (g != p.lastGrade) {
        progress[id] = p.copyWith(lastGrade: g);
        changed = true;
      }
    }
    if (changed) saveProgress();
  }

  void setSelfCheckMode(int mode) {
    selfCheckMode = (mode >= 0 && mode <= 2) ? mode : checkMixed;
    saveMeta();
  }

  String get selfCheckModeName => switch (selfCheckMode) {
        checkChoice => '看单词选意思',
        checkSpelling => '看意思写单词',
        _ => '两种混合',
      };

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
        'theme': themeIndex,
        'method': memoryMethod,
        'checkMode': selfCheckMode,
        'gradeScale': _gradeScale,
      });

  void setThemeIndex(int i) {
    themeIndex = i;
    saveMeta();
  }

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
    final now = DateTime.now();
    final r = useEbbinghaus ? Ebbinghaus.review(p, grade, now) : Sm2.review(p, grade, now);
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

  // ---------- 每日自我检查 ----------

  /// 取一个词最核心的中文释义（第一个非空的翻译）
  String _primaryMeaning(Word w) {
    for (final t in w.translations) {
      final cn = t.cn.trim();
      if (cn.isNotEmpty) return cn;
    }
    return '';
  }

  /// 按当前题型设置挑一种题型
  SelfCheckType _pickType(Random rnd) {
    switch (selfCheckMode) {
      case checkChoice:
        return SelfCheckType.choice;
      case checkSpelling:
        return SelfCheckType.spelling;
      default:
        // 混合：逐题随机，两种都会出现
        return rnd.nextBool()
            ? SelfCheckType.spelling
            : SelfCheckType.choice;
    }
  }

  /// 从「已学过」的词里抽题
  ///
  /// 选择题：给 4 个中文释义，干扰项优先取同词性的词，
  /// 否则一眼就能靠词性排除，测不出真实记忆。
  /// 拼写题：给中文意思，要求写出英文单词。
  List<SelfCheckQuestion> buildSelfCheckQuestions({int count = 20}) {
    final learned = <Word>[];
    progress.forEach((id, p) {
      if (p.reviewCount > 0) {
        final w = _byId[id];
        if (w != null) learned.add(w);
      }
    });
    if (learned.length < 4) return const [];

    final rnd = Random();
    final pool = [...learned]..shuffle(rnd);
    final picked = pool.take(count).toList();
    final questions = <SelfCheckQuestion>[];

    for (final w in picked) {
      final meaning = _primaryMeaning(w);
      if (meaning.isEmpty) continue;

      final type = _pickType(rnd);

      // ---- 拼写题：不需要干扰项 ----
      if (type == SelfCheckType.spelling) {
        questions.add(SelfCheckQuestion(
          word: w,
          type: SelfCheckType.spelling,
          prompt: meaning,
          answer: w.word,
        ));
        continue;
      }

      // ---- 选择题：凑 4 个选项 ----
      final pos = w.translations.isNotEmpty ? w.translations.first.pos : null;
      final options = <String>{meaning};

      // 第一轮：同词性干扰项
      if (pos != null && pos.isNotEmpty) {
        for (final o in pool) {
          if (options.length >= 4) break;
          if (o.id == w.id || o.translations.isEmpty) continue;
          if (o.translations.first.pos != pos) continue;
          final m = _primaryMeaning(o);
          if (m.isNotEmpty) options.add(m);
        }
      }
      // 第二轮：任意干扰项补齐
      for (final o in pool) {
        if (options.length >= 4) break;
        if (o.id == w.id) continue;
        final m = _primaryMeaning(o);
        if (m.isNotEmpty) options.add(m);
      }
      if (options.length < 4) {
        // 凑不齐就退化成拼写题，别浪费这个词
        questions.add(SelfCheckQuestion(
          word: w,
          type: SelfCheckType.spelling,
          prompt: meaning,
          answer: w.word,
        ));
        continue;
      }

      questions.add(SelfCheckQuestion(
        word: w,
        type: SelfCheckType.choice,
        prompt: w.word,
        answer: meaning,
        options: options.toList()..shuffle(rnd),
      ));
    }
    return questions;
  }

  /// 记录一次自检结果
  void recordSelfCheck(int total, int correct) {
    final st = todayStat();
    st.checkTotal += total;
    st.checkCorrect += correct;
    saveStats();
  }

  /// 自检答错：记忆强度退一级，并让它立刻回到复习队列
  ///
  /// 只惩罚答错、不奖励答对 —— 自检是「检验」，不该打乱正常曲线；
  /// 但答错说明确实没记住，把它拉回来是合理的。
  void applySelfCheckMiss(Word w) {
    final p = progress[w.id];
    if (p == null) return;
    final now = DateTime.now();
    if (useEbbinghaus) {
      progress[w.id] = p.copyWith(
        stage: Ebbinghaus.clampStage(Ebbinghaus.stageOf(p) - 1),
        dueDate: now,
      );
    } else {
      final ef = (p.easeFactor - 0.2).clamp(1.3, 2.5).toDouble();
      progress[w.id] = p.copyWith(
        easeFactor: ef,
        repetitions: p.repetitions > 0 ? p.repetitions - 1 : 0,
        dueDate: now,
      );
    }
    saveProgress();
  }

  /// 今日自检情况
  int get todayCheckTotal => todayStat().checkTotal;
  int get todayCheckCorrect => todayStat().checkCorrect;
  bool get todayCheckDone => todayStat().checkDone;

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

  /// 单个词是否算「已掌握」，口径随算法走：
  /// - 艾宾浩斯：走到 30 天及以后的阶段
  /// - SM-2：连续答对 3 次且间隔超过 21 天
  bool isMastered(WordProgress p) {
    if (p.reviewCount == 0) return false;
    if (useEbbinghaus) return Ebbinghaus.stageOf(p) >= Ebbinghaus.masteredStage;
    return p.repetitions >= 3 && p.interval >= 21;
  }

  int get masteredCount =>
      progress.values.where(isMastered).length;

  /// 各阶段的词数分布，用于统计页展示遗忘曲线进度
  List<int> get stageDistribution {
    final out = List<int>.filled(Ebbinghaus.intervalMinutes.length, 0);
    for (final p in progress.values) {
      if (p.reviewCount == 0) continue;
      out[Ebbinghaus.clampStage(Ebbinghaus.stageOf(p))]++;
    }
    return out;
  }

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
