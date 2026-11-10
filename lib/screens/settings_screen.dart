import 'package:flutter/material.dart';

import '../services/store.dart';
import '../services/update_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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
                activeTrackColor: const Color(0xFF4A7C59),
                onChanged: (v) {
                  setState(() => s.setRandomNewWords(v));
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                enabled: s.randomNewWords,
                leading: const Icon(Icons.casino_outlined,
                    color: Color(0xFF4A7C59)),
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
                leading: const Icon(Icons.library_books_outlined,
                    color: Color(0xFF4A7C59)),
                title: const Text('四级词汇（正序版）',
                    style: TextStyle(fontSize: 15)),
                subtitle: Text('${s.allWords.length} 词 · 有道词书',
                    style: const TextStyle(fontSize: 12)),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.sync, color: Color(0xFF4A7C59)),
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
                leading: const Icon(Icons.system_update_outlined,
                    color: Color(0xFF4A7C59)),
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
                leading: const Icon(Icons.network_check, color: Color(0xFF4A7C59)),
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
                              ? const Color(0xFF4A7C59)
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
                leading: const Icon(Icons.info_outline, color: Color(0xFF4A7C59)),
                title: const Text('记忆算法', style: TextStyle(fontSize: 15)),
                subtitle: const Text(
                    'SM-2 间隔重复算法，5 档评分自动安排复习时间',
                    style: TextStyle(fontSize: 12)),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.storage_outlined, color: Color(0xFF4A7C59)),
                title: const Text('数据存储', style: TextStyle(fontSize: 15)),
                subtitle: const Text('全部数据保存在本机，不联网不上传',
                    style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: Text('四级背单词 v1.0.0',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
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
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4A7C59))),
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
