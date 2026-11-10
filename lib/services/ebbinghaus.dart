import 'sm2.dart';

/// 艾宾浩斯遗忘曲线复习法
///
/// 与 SM-2 的根本区别：
/// - SM-2 用「难度因子」动态算间隔，每个词的间隔都不一样
/// - 艾宾浩斯用一张**固定的复习时间表**，词只是在这条曲线上往前走
///
/// 每个词有一个「阶段」（stage），阶段决定下次什么时候复习。
/// 记住就往前走（拉长间隔），忘了就退回起点（缩短间隔），
/// 这正好对应遗忘曲线的形状。
class Ebbinghaus {
  Ebbinghaus._();

  /// 每个阶段对应的复习间隔（分钟）
  ///
  /// 前密后疏：刚学完的几天反复巩固，熟悉之后间隔迅速拉开，
  /// 这就是艾宾浩斯曲线的核心。
  static const List<int> intervalMinutes = [
    10, //         阶段 0：当堂巩固，10 分钟
    12 * 60, //    阶段 1：12 小时（当天睡前或次日早上）
    24 * 60, //    阶段 2：1 天
    2 * 1440, //   阶段 3：2 天
    4 * 1440, //   阶段 4：4 天
    7 * 1440, //   阶段 5：7 天
    15 * 1440, //  阶段 6：15 天
    30 * 1440, //  阶段 7：30 天
    60 * 1440, //  阶段 8：60 天
    120 * 1440, // 阶段 9：120 天
    180 * 1440, // 阶段 10：180 天
    365 * 1440, // 阶段 11：1 年（长期记忆）
  ];

  /// 阶段的中文名字，直接显示给用户看
  static const List<String> stageLabels = [
    '10 分钟',
    '12 小时',
    '1 天',
    '2 天',
    '4 天',
    '7 天',
    '15 天',
    '30 天',
    '60 天',
    '120 天',
    '180 天',
    '1 年',
  ];

  /// 阶段说明，用于设置页的时间表展示
  static const List<String> stageHints = [
    '刚学完，马上巩固一次',
    '当天回看，或睡前过一遍',
    '隔天复习',
    '短间隔巩固',
    '一周内的最后一轮',
    '满一周',
    '半个月',
    '满一个月，进入中期记忆',
    '两个月',
    '四个月',
    '半年',
    '已转为长期记忆',
  ];

  /// 「已掌握」的门槛：走到 30 天及以后的阶段
  static const int masteredStage = 7;

  static int get maxStage => intervalMinutes.length - 1;

  /// 安全地把阶段限制在合法范围
  static int clampStage(int v) {
    if (v < 0) return 0;
    if (v > maxStage) return maxStage;
    return v;
  }

  /// 读取一个词的当前阶段
  ///
  /// 老数据（用 SM-2 学的，没有 stage 字段）会按历史表现自动换算，
  /// 这样开启艾宾浩斯后进度不会凭空归零、也不会突然冒出几千个到期词。
  static int stageOf(WordProgress p) {
    if (p.stage >= 0) return clampStage(p.stage);
    return inferStage(p);
  }

  /// 把 SM-2 的 repetitions / interval 换算成等效的艾宾浩斯阶段
  static int inferStage(WordProgress p) {
    if (p.reviewCount == 0) return 0;
    if (p.repetitions <= 1) return p.interval < 1 ? 1 : 2;
    if (p.repetitions == 2) return 2;
    final d = p.interval;
    if (d < 2) return 2;
    if (d < 4) return 3;
    if (d < 7) return 4;
    if (d < 15) return 5;
    if (d < 30) return 6;
    if (d < 60) return 7;
    if (d < 120) return 8;
    if (d < 180) return 9;
    if (d < 365) return 10;
    return 11;
  }

  static String labelFor(int stage) => stageLabels[clampStage(stage)];

  /// 这个阶段代表多长的间隔（文字形式）
  static String labelOf(WordProgress p) => labelFor(stageOf(p));

  /// 评价后应该进入哪个阶段
  ///
  /// 0 忘记 → 回到起点，整条曲线重走
  /// 1 模糊 → 退一级，下次来得更早
  /// 2 一般 → 原地不动，同一间隔再巩固一次
  /// 3 熟悉 → 前进一级
  /// 4 秒杀 → 前进两级，很熟的词不用陪跑
  static int nextStage(WordProgress p, int grade) {
    final cur = stageOf(p);

    if (grade == 0) return 0;
    if (grade == 1) return clampStage(cur - 1);

    // 新词第一次评价：不论选「一般」还是「秒杀」，
    // 都统一进入 12 小时阶段 —— 给当天留一次回看机会，别一上来就放两天
    if (p.reviewCount == 0) return 1;

    if (grade == 2) return cur;
    if (grade == 3) return clampStage(cur + 1);
    return clampStage(cur + 2);
  }

  /// 提交一次复习，返回新的记忆状态
  ///
  /// 只写 stage / dueDate / 计数，不动 interval 和 repetitions，
  /// 这样以后切回 SM-2 时两套算法的数据不会互相污染。
  static Sm2Result review(WordProgress p, int grade, DateTime now) {
    final next = nextStage(p, grade);
    final mins = intervalMinutes[next];
    final updated = p.copyWith(
      stage: next,
      dueDate: now.add(Duration(minutes: mins)),
      reviewCount: p.reviewCount + 1,
      lapseCount: grade == 0 ? p.lapseCount + 1 : p.lapseCount,
      lastGrade: grade,
    );
    return Sm2Result(updated, now);
  }

  /// 评分按钮上显示的「下次什么时候见」
  static String predictLabel(WordProgress p, int grade) =>
      labelFor(nextStage(p, grade));

  /// 距离下次复习还有多久（用于词详情页）
  static String remainingText(WordProgress p, [DateTime? at]) {
    final now = at ?? DateTime.now();
    final diff = p.dueDate.difference(now);
    if (diff.isNegative) return '现在就该复习';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟后';
    if (diff.inHours < 24) return '${diff.inHours} 小时后';
    return '${diff.inDays} 天后';
  }
}
