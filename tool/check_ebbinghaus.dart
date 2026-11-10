// 艾宾浩斯算法自检脚本（纯 Dart，不依赖 Flutter）
// 运行：dart run tool/check_ebbinghaus.dart
import '../lib/services/ebbinghaus.dart';
import '../lib/services/sm2.dart';

int _pass = 0;
int _fail = 0;

void check(String name, Object actual, Object expected) {
  if ('$actual' == '$expected') {
    _pass++;
    print('  ok   $name = $actual');
  } else {
    _fail++;
    print('  FAIL $name: got $actual, want $expected');
  }
}

void main() {
  final t0 = DateTime(2026, 1, 1, 8, 0);

  print('== 新词首次评价 ==');
  var p = WordProgress.initial(t0);
  check('初始阶段', Ebbinghaus.stageOf(p), 0);

  var r = Ebbinghaus.review(p, 3, t0).progress; // 熟悉
  check('熟悉后阶段', r.stage, 1);
  check('熟悉后间隔(小时)', r.dueDate.difference(t0).inHours, 12);

  r = Ebbinghaus.review(p, 4, t0).progress; // 秒杀（新词也只到 1）
  check('新词秒杀后阶段', r.stage, 1);

  r = Ebbinghaus.review(p, 2, t0).progress; // 认识
  check('新词认识后阶段', r.stage, 1);
  check('新词认识后间隔(小时)', r.dueDate.difference(t0).inHours, 12);

  r = Ebbinghaus.review(p, 1, t0).progress; // 模糊
  check('新词模糊后阶段', r.stage, 0);
  check('新词模糊后间隔(分钟)', r.dueDate.difference(t0).inMinutes, 10);

  r = Ebbinghaus.review(p, 0, t0).progress; // 忘记
  check('新词忘记后阶段', r.stage, 0);
  check('新词忘记后间隔(分钟)', r.dueDate.difference(t0).inMinutes, 10);

  print('== 阶段推进/回退 ==');
  // 造一个已在阶段 4（4 天）的词
  WordProgress at(int stage) => WordProgress(
        interval: 0,
        easeFactor: 2.5,
        repetitions: 0,
        dueDate: t0,
        reviewCount: 5,
        lapseCount: 0,
        lastGrade: 3,
        stage: stage,
      );

  check('阶段4+熟悉', Ebbinghaus.review(at(4), 3, t0).progress.stage, 5);
  check('阶段4+秒杀', Ebbinghaus.review(at(4), 4, t0).progress.stage, 6);
  check('阶段4+认识(推进)', Ebbinghaus.review(at(4), 2, t0).progress.stage, 5);
  check('阶段4+模糊', Ebbinghaus.review(at(4), 1, t0).progress.stage, 3);
  check('阶段4+忘记', Ebbinghaus.review(at(4), 0, t0).progress.stage, 0);

  print('== 边界 ==');
  check('阶段0+模糊不越界', Ebbinghaus.review(at(0), 1, t0).progress.stage, 0);
  check('顶阶+秒杀不越界', Ebbinghaus.review(at(11), 4, t0).progress.stage, 11);
  r = Ebbinghaus.review(at(11), 3, t0).progress;
  check('顶阶间隔(天)', r.dueDate.difference(t0).inDays, 365);

  print('== 各阶段对应间隔 ==');
  final wantDays = [0, 0, 1, 2, 4, 7, 15, 30, 60, 120, 180, 365];
  for (var i = 0; i < Ebbinghaus.intervalMinutes.length; i++) {
    final d = Ebbinghaus.intervalMinutes[i] / 1440.0;
    final label = Ebbinghaus.stageLabels[i];
    if (i == 0) {
      check('阶段$i 标签', label, '10 分钟');
      check('阶段$i 分钟', Ebbinghaus.intervalMinutes[i], 10);
    } else if (i == 1) {
      check('阶段$i 标签', label, '12 小时');
      check('阶段$i 小时', Ebbinghaus.intervalMinutes[i] ~/ 60, 12);
    } else {
      check('阶段$i 天数', d.round(), wantDays[i]);
    }
  }

  print('== 旧 SM-2 数据换算 ==');
  WordProgress old(int reps, double interval, int rc) => WordProgress(
        interval: interval,
        easeFactor: 2.5,
        repetitions: reps,
        dueDate: t0,
        reviewCount: rc,
        lapseCount: 0,
        lastGrade: 3,
        stage: -1,
      );
  check('未学过', Ebbinghaus.inferStage(old(0, 0, 0)), 0);
  check('reps1 interval1', Ebbinghaus.inferStage(old(1, 1, 1)), 2);
  check('reps2', Ebbinghaus.inferStage(old(2, 2, 2)), 2);
  check('reps3 interval3', Ebbinghaus.inferStage(old(3, 3, 3)), 3);
  check('reps5 interval10', Ebbinghaus.inferStage(old(5, 10, 5)), 5);
  check('reps8 interval60', Ebbinghaus.inferStage(old(8, 60, 8)), 8);
  check('reps9 interval200', Ebbinghaus.inferStage(old(9, 200, 9)), 10);
  check('reps10 interval365', Ebbinghaus.inferStage(old(10, 365, 10)), 11);

  print('== 预测标签与实际一致 ==');
  for (var g = 0; g <= 4; g++) {
    final predicted = Ebbinghaus.predictLabel(at(5), g);
    final actual = Ebbinghaus.labelFor(Ebbinghaus.review(at(5), g, t0).progress.stage);
    check('评分$g 预测=实际', predicted, actual);
  }

  print('== SM-2 仍然可用（回归） ==');
  final s = Sm2.review(WordProgress.initial(t0), 3, t0).progress;
  check('SM-2 首评 reps', s.repetitions, 1);
  check('SM-2 首评间隔(天)', s.interval, 1.0);
  check('SM-2 不写 stage', s.stage, -1);

  print('');
  print('结果: $_pass 通过, $_fail 失败');
  if (_fail > 0) throw StateError('有 $_fail 项未通过');
}
