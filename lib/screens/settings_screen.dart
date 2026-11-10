import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/ebbinghaus.dart';
import '../services/store.dart';
import '../services/update_service.dart';
import '../theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((p) {
      if (!mounted) return;
      setState(() => _version = 'v${p.version}');
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final s = Store.I;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: [
          const Text('设置',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          _Section(
            title: '主题色',
            children: [
              const SizedBox(height: 4),
              SizedBox(
                height: 76,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: AppPalette.presets.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (_, i) {
                    final preset = AppPalette.presets[i];
                    final selected = i == s.themeIndex;
                    return GestureDetector(
                      onTap: () {
                        s.setThemeIndex(i);
                        AppPalette.apply(i);
                        AppPalette.revision.value++;
                        setState(() {});
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: preset.seed,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected
                                    ? Colors.grey.shade800
                                    : Colors.transparent,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: preset.seed.withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: selected
                                ? const Icon(Icons.check,
                                    size: 20, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            preset.name,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight:
                                  selected ? FontWeight.w600 : FontWeight.normal,
                              color: selected
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: '记忆算法',
            children: [
              const SizedBox(height: 2),
              _MethodOption(
                selected: s.useEbbinghaus,
                title: '艾宾浩斯遗忘曲线',
                badge: '推荐',
                subtitle: '固定间隔表：10 分钟 → 12 小时 → 1 天 → 2 天 → '
                    '4 天 → 7 天 → 15 天 → 30 天… 越熟间隔越长',
                onTap: () {
                  s.setMemoryMethod(Store.methodEbbinghaus);
                  setState(() {});
                },
              ),
              const SizedBox(height: 10),
              _MethodOption(
                selected: !s.useEbbinghaus,
                title: 'SM-2 自适应',
                subtitle: '按每个词自己的难度因子动态计算间隔，'
                    '背得快的词间隔拉得更开',
                onTap: () {
                  s.setMemoryMethod(Store.methodSm2);
                  setState(() {});
                },
              ),
              const Divider(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.timeline, color: AppPalette.primary),
                title: const Text('复习时间表', style: TextStyle(fontSize: 14)),
                subtitle: Text(
                  '遗忘曲线共 ${Ebbinghaus.intervalMinutes.length} 个阶段，'
                  '点开看每一级对应多久',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => _showCurveTable(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: '学习计划',
            children: [
              _SliderTile(
                label: '每日新词上限',
                value: s.dailyNewLimit.toDouble(),
                min: 5,
                max: 100,
                step: 5,
                display: '${s.dailyNewLimit} 词',
                onChanged: (v) {
                  setState(() => s.setDailyNewLimit(v.round()));
                },
              ),
              const SizedBox(height: 8),
              _SliderTile(
                label: '每日学习目标',
                value: s.dailyGoalHours,
                min: 0.5,
                max: 4,
                step: 0.5,
                display: '${s.dailyGoalHours.toStringAsFixed(1)} 小时',
                onChanged: (v) {
                  s.dailyGoalHours = v;
                  s.saveMeta();
                  setState(() {});
                },
              ),
              const Divider(height: 24),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('随机抽取新词',
                    style: TextStyle(fontSize: 14)),
                subtitle: const Text(
                    '伪随机打乱词库，避免每天从 abandon 一路背到 Z',
                    style: TextStyle(fontSize: 12)),
                value: s.randomNewWords,
                activeTrackColor: AppPalette.primary,
                onChanged: (v) {
                  setState(() => s.setRandomNewWords(v));
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                enabled: s.randomNewWords,
                leading: Icon(Icons.casino_outlined,
                    color: AppPalette.primary),
                title: const Text('重新随机抽取今日新词',
                    style: TextStyle(fontSize: 14)),
                subtitle: const Text('换一组词，今天还没学的会重新抽',
                    style: TextStyle(fontSize: 12)),
                onTap: s.randomNewWords
                    ? () {
                        s.reshuffleNewWords();
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('已重新随机抽取今日新词'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: '词库',
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.library_books_outlined,
                    color: AppPalette.primary),
                title: const Text('四级词汇（正序版）',
                    style: TextStyle(fontSize: 15)),
                subtitle: Text('${s.allWords.length} 词 · 有道词书',
                    style: const TextStyle(fontSize: 12)),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.sync, color: AppPalette.primary),
                title: const Text('重置学习进度', style: TextStyle(fontSize: 15)),
                subtitle: const Text('清空所有记忆记录，重新开始',
                    style: TextStyle(fontSize: 12)),
                onTap: () => _confirmReset(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: '更新',
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.system_update_outlined,
                    color: AppPalette.primary),
                title: const Text('检查更新',
                    style: TextStyle(fontSize: 15)),
                subtitle: Text(
                  UpdateService.diagnostic,
                  style: const TextStyle(fontSize: 11.5),
                ),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () async {
                  await UpdateService.manualCheck(context);
                  if (mounted) setState(() {});
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.network_check, color: AppPalette.primary),
                title: const Text('网络诊断', style: TextStyle(fontSize: 15)),
                subtitle: const Text('检测 DNS 解析和直连是否正常',
                    style: TextStyle(fontSize: 12)),
                onTap: () async {
                  final report = await UpdateService.diagnose();
                  if (!context.mounted) return;
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Row(children: [
                        Icon(
                          report.dnsOk ? Icons.check_circle : Icons.error,
                          color: report.dnsOk
                              ? AppPalette.primary
                              : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        const Text('网络诊断'),
                      ]),
                      content: SingleChildScrollView(
                        child: Text(report.detail,
                            style: const TextStyle(fontSize: 12.5, height: 1.6)),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('知道了'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: '关于',
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.info_outline, color: AppPalette.primary),
                title: const Text('当前算法', style: TextStyle(fontSize: 15)),
                subtitle: Text(
                    '${s.memoryMethodName} · 5 档评分自动安排复习时间',
                    style: const TextStyle(fontSize: 12)),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.storage_outlined, color: AppPalette.primary),
                title: const Text('数据存储', style: TextStyle(fontSize: 15)),
                subtitle: const Text('全部数据保存在本机，不联网不上传',
                    style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
                _version.isEmpty ? '四级背单词' : '四级背单词 $_version',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ),
        ],
      ),
    );
  }

  void _showCurveTable(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('艾宾浩斯复习时间表'),
        contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: Ebbinghaus.intervalMinutes.length,
            itemBuilder: (_, i) {
              final last = i == Ebbinghaus.intervalMinutes.length - 1;
              return Padding(
                padding: const EdgeInsets.only(bottom: 13),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: last
                            ? AppPalette.primary
                            : AppPalette.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Text('${i + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: last ? Colors.white : AppPalette.primary,
                          )),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(Ebbinghaus.stageLabels[i],
                              style: const TextStyle(
                                  fontSize: 13.5, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(Ebbinghaus.stageHints[i],
                              style: TextStyle(
                                  fontSize: 11.5, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('确认重置？'),
        content: const Text('所有学习记录将被清空，此操作无法撤销。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('确认重置'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      final s = Store.I;
      s.progress.clear();
      s.stats.clear();
      s.favorites.clear();
      s.saveProgress();
      s.saveStats();
      s.saveMeta();
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('学习进度已清空')),
      );
    }
  }
}

class _MethodOption extends StatelessWidget {
  final bool selected;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;

  const _MethodOption({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppPalette.soft : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppPalette.primary.withValues(alpha: 0.55)
                : Colors.grey.shade200,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 20,
                color: selected ? AppPalette.primary : Colors.grey.shade400,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? AppPalette.primaryDark
                                : Colors.black87,
                          )),
                      if (badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppPalette.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(badge!,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppPalette.primary,
                              )),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.45,
                        color: Colors.grey.shade600,
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final double step;
  final String display;
  final ValueChanged<double> onChanged;

  const _SliderTile({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.display,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 14)),
            const Spacer(),
            Text(display,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppPalette.primary)),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: ((max - min) / step).round(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
