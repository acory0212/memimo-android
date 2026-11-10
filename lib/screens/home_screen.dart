import 'package:flutter/material.dart';

import '../services/store.dart';
import 'learn_screen.dart';
import 'stats_screen.dart';
import 'settings_screen.dart';
import 'wordbook_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          _TodayTab(),
          WordbookScreen(),
          StatsScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today_outlined), selectedIcon: Icon(Icons.today), label: '今日'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: '词库'),
          NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: '统计'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: '设置'),
        ],
      ),
    );
  }
}

class _TodayTab extends StatefulWidget {
  const _TodayTab();

  @override
  State<_TodayTab> createState() => _TodayTabState();
}

class _TodayTabState extends State<_TodayTab> {
  @override
  Widget build(BuildContext context) {
    final s = Store.I;
    final due = s.dueReviews();
    final news = s.newWords();
    final today = s.todayStat();
    final total = s.totalLearned;
    final mastered = s.masteredCount;
    final goalMinutes = (s.dailyGoalHours * 60).round();
    final studiedMinutes = (today.studySeconds / 60).round();
    final progress = goalMinutes == 0
        ? 0.0
        : (today.studySeconds / (goalMinutes * 60)).clamp(0.0, 1.0);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '四级背单词',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                ),
              ),
              if (s.streak > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.local_fire_department,
                          size: 18, color: Color(0xFFE65100)),
                      const SizedBox(width: 4),
                      Text('${s.streak} 天',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFE65100))),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '今日目标 ${s.dailyGoalHours.toStringAsFixed(1)} 小时',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),

          _BigCard(
            title: '今日学习',
            subtitle: '复习 ${due.length} 个 · 新词 ${news.length} 个',
            icon: Icons.play_circle_fill,
            colors: const [Color(0xFF4A7C59), Color(0xFF6FA97D)],
            onTap: () async {
              if (due.isEmpty && news.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('今天的学习任务已完成 🎉')),
                );
                return;
              }
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => LearnScreen(due: due, newWords: news)),
              );
              setState(() {});
            },
            footer: progress > 0
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation(Colors.white),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('已学 $studiedMinutes / $goalMinutes 分钟',
                          style: const TextStyle(fontSize: 12, color: Colors.white70)),
                    ],
                  )
                : null,
          ),

          const SizedBox(height: 10),
          _RandomBar(
            enabled: s.randomNewWords,
            count: news.length,
            onDraw: () {
              s.reshuffleNewWords();
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('已重新随机抽取今日新词'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),

          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _StatCard(label: '已学词汇', value: '$total', unit: '词')),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(label: '已掌握', value: '$mastered', unit: '词')),
              const SizedBox(width: 12),
              Expanded(
                  child: _StatCard(
                      label: '今日新词', value: '${today.newWords}', unit: '词')),
            ],
          ),

          const SizedBox(height: 24),
          const Text('快捷入口',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuickCard(
                  icon: Icons.style_outlined,
                  label: '错题本',
                  color: const Color(0xFFD84315),
                  onTap: () => _openList(context, '错题本', () {
                    final ids = s.progress.entries
                        .where((e) => e.value.lapseCount > 0)
                        .map((e) => e.key)
                        .toList();
                    ids.sort((a, b) =>
                        s.progress[b]!.lapseCount.compareTo(s.progress[a]!.lapseCount));
                    return ids
                        .map((i) => s.wordById(i))
                        .whereType<dynamic>()
                        .toList();
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickCard(
                  icon: Icons.star_outline,
                  label: '收藏',
                  color: const Color(0xFFF9A825),
                  onTap: () => _openList(context, '收藏', () {
                    final ids = s.favorites.toList();
                    return ids.map((i) => s.wordById(i)).whereType<dynamic>().toList();
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openList(BuildContext context, String title, List<dynamic> Function() loader) {
    final list = loader();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _WordListPage(title: title, words: list.cast()),
      ),
    );
  }
}

class _RandomBar extends StatelessWidget {
  final bool enabled;
  final int count;
  final VoidCallback onDraw;

  const _RandomBar({
    required this.enabled,
    required this.count,
    required this.onDraw,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            enabled ? Icons.shuffle : Icons.sort,
            size: 17,
            color: const Color(0xFF4A7C59),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              enabled
                  ? '新词随机抽取 · 本组 $count 个'
                  : '新词按词库顺序抽取 · 本组 $count 个',
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
            ),
          ),
          TextButton.icon(
            onPressed: enabled ? onDraw : null,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF4A7C59),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(0, 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.casino_outlined, size: 16),
            label: const Text('随机抽取', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _BigCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;
  final Widget? footer;

  const _BigCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    required this.onTap,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: colors.first.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(subtitle,
                          style: const TextStyle(fontSize: 13, color: Colors.white70)),
                    ],
                  ),
                ),
                Icon(icon, size: 44, color: Colors.white),
              ],
            ),
            if (footer != null) footer!,
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;

  const _StatCard({required this.label, required this.value, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(width: 2),
              Text(unit, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ],
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _WordListPage extends StatelessWidget {
  final String title;
  final List<dynamic> words;

  const _WordListPage({required this.title, required this.words});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('$title (${words.length})')),
      body: words.isEmpty
          ? const Center(child: Text('还没有内容'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: words.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final w = words[i];
                return ListTile(
                  title: Text(w.word,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(w.primaryMeaning,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                );
              },
            ),
    );
  }
}
