import 'dart:async';

import 'package:flutter/material.dart';

import '../models/word.dart';
import '../services/audio_player.dart';
import '../services/sm2.dart';
import '../services/store.dart';
import '../theme.dart';

/// 一次学习会话：先复习到期的，再学新词
class LearnScreen extends StatefulWidget {
  final List<Word> due;
  final List<Word> newWords;

  const LearnScreen({super.key, required this.due, required this.newWords});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  late final List<Word> _queue;
  int _idx = 0;
  bool _revealed = false;
  int _correct = 0;
  int _wrong = 0;
  final DateTime _startedAt = DateTime.now();
  Timer? _ticker;
  final AudioPlayerService _audio = AudioPlayerService();

  @override
  void initState() {
    super.initState();
    _queue = [...widget.due, ...widget.newWords];
    _ticker = Timer.periodic(const Duration(seconds: 10), (_) {
      Store.I.addStudySeconds(10);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    final elapsed = DateTime.now().difference(_startedAt).inSeconds -
        (_startedAt.millisecondsSinceEpoch ~/ 1000 == 0 ? 0 : 0);
    // 补上不足 10 秒的零头
    final leftover = elapsed % 10;
    if (leftover > 0) Store.I.addStudySeconds(leftover);
    super.dispose();
  }

  Word get _current => _queue[_idx];

  void _reveal() => setState(() => _revealed = true);

  void _grade(int g) {
    Store.I.applyReview(_current, g);
    if (g == 0) {
      _wrong++;
      // 忘记的卡片重新排到队尾
      final w = _queue.removeAt(_idx);
      _queue.add(w);
      if (_idx >= _queue.length) _idx = _queue.length - 1;
      setState(() => _revealed = false);
      return;
    }
    _correct++;
    _next();
  }

  void _next() {
    if (_idx + 1 >= _queue.length) {
      _finish();
      return;
    }
    setState(() {
      _idx++;
      _revealed = false;
    });
  }

  void _finish() {
    final secs = DateTime.now().difference(_startedAt).inSeconds;
    Navigator.pop(context, true);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('学习完成 🎉'),
        content: Text(
          '本次学习 ${_queue.length} 个词\n'
          '用时 ${(secs / 60).ceil()} 分钟\n'
          '认识 $_correct 次 · 忘记 $_wrong 次',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('好的'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = _current;
    final p = Store.I.progress[w.id] ?? WordProgress.initial(DateTime.now());
    final isNew = p.reviewCount == 0;

    return Scaffold(
      appBar: AppBar(
        title: Text('${_idx + 1} / ${_queue.length}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('结束'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: LinearProgressIndicator(
            value: _queue.isEmpty ? 0 : _idx / _queue.length,
            minHeight: 3,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isNew)
                        const _Chip(text: '新词', color: Color(0xFF1976D2)),
                      if (!isNew) ...[
                        const _Chip(text: '复习', color: Color(0xFF7B1FA2)),
                        const SizedBox(width: 6),
                        _Chip(
                          text: '第 ${p.reviewCount + 1} 次',
                          color: Colors.grey.shade600,
                        ),
                      ],
                      if (w.star >= 4) ...[
                        const SizedBox(width: 6),
                        const _Chip(text: '高频', color: Color(0xFFD84315)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        w.word,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => _audio.play(w.id),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppPalette.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.volume_up_outlined,
                            size: 22,
                            color: AppPalette.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (w.uk != null || w.us != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      [
                        if (w.uk != null && w.uk!.isNotEmpty) '英 /${w.uk}/',
                        if (w.us != null && w.us!.isNotEmpty) '美 /${w.us}/',
                      ].join('   '),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    ),
                  ],
                  const SizedBox(height: 28),
                  if (!_revealed) ...[
                    Center(
                      child: Column(
                        children: [
                          OutlinedButton.icon(
                            onPressed: _reveal,
                            icon: const Icon(Icons.visibility_outlined),
                            label: const Text('查看释义'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 28, vertical: 14),
                            ),
                          ),
                          const SizedBox(height: 20),
                          GestureDetector(
                            onTap: () => Store.I.toggleFavorite(w.id),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Store.I.favorites.contains(w.id)
                                      ? Icons.star
                                      : Icons.star_border,
                                  size: 20,
                                  color: const Color(0xFFF9A825),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  Store.I.favorites.contains(w.id) ? '已收藏' : '收藏',
                                  style: TextStyle(
                                      fontSize: 13, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else
                    _MeaningBlock(word: w),
                ],
              ),
            ),
          ),
          _ActionBar(
            revealed: _revealed,
            progress: p,
            onGrade: _grade,
            onReveal: _reveal,
          ),
        ],
      ),
    );
  }
}

class _MeaningBlock extends StatelessWidget {
  final Word word;
  const _MeaningBlock({required this.word});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final t in word.translations)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 16, color: Colors.black87),
                      children: [
                        if (t.pos != null && t.pos!.isNotEmpty)
                          TextSpan(
                            text: '${t.pos}. ',
                            style: TextStyle(
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                              color: AppPalette.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        TextSpan(text: t.cn),
                      ],
                    ),
                  ),
                ),
              if (word.mnemonic != null && word.mnemonic!.isNotEmpty) ...[
                const Divider(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline,
                        size: 16, color: Color(0xFFF9A825)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        word.mnemonic!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (word.example != null) ...[
          const SizedBox(height: 12),
          _ExampleCard(
            title: '例句',
            example: word.example!,
          ),
        ],
        if (word.examExample != null) ...[
          const SizedBox(height: 12),
          _ExampleCard(
            title: '真题',
            example: word.examExample!,
            highlight: true,
          ),
        ],
        if (word.phrases.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.link, size: 15, color: AppPalette.primary),
                    const SizedBox(width: 5),
                    Text('短语',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700)),
                  ],
                ),
                const SizedBox(height: 8),
                for (final p in word.phrases)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text.rich(
                      TextSpan(
                        style: const TextStyle(fontSize: 13.5, height: 1.5),
                        children: [
                          TextSpan(
                            text: p.p,
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppPalette.primaryDark),
                          ),
                          if (p.cn != null && p.cn!.isNotEmpty)
                            TextSpan(
                              text: '  ${p.cn}',
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (word.synonyms.isNotEmpty || word.antonyms.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (word.synonyms.isNotEmpty)
                  _WordChips(label: '近义', words: word.synonyms, color: const Color(0xFF1976D2)),
                if (word.synonyms.isNotEmpty && word.antonyms.isNotEmpty)
                  const SizedBox(height: 10),
                if (word.antonyms.isNotEmpty)
                  _WordChips(label: '反义', words: word.antonyms, color: const Color(0xFFD84315)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            onPressed: () => Store.I.toggleFavorite(word.id),
            icon: Icon(
              Store.I.favorites.contains(word.id) ? Icons.star : Icons.star_border,
              size: 18,
              color: const Color(0xFFF9A825),
            ),
            label: Text(Store.I.favorites.contains(word.id) ? '已收藏' : '收藏',
                style: const TextStyle(fontSize: 13)),
          ),
        ),
      ],
    );
  }
}

class _ExampleCard extends StatelessWidget {
  final String title;
  final Example example;
  final bool highlight;

  const _ExampleCard({
    required this.title,
    required this.example,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlight ? AppPalette.soft : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: highlight
            ? Border.all(color: AppPalette.primary.withValues(alpha: 0.2))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                highlight ? Icons.school_outlined : Icons.format_quote,
                size: 15,
                color: AppPalette.primary,
              ),
              const SizedBox(width: 5),
              Text(title,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700)),
              if (example.src != null && example.src!.isNotEmpty) ...[
                const Spacer(),
                Text(example.src!,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(example.en,
              style: const TextStyle(fontSize: 14, height: 1.55)),
          if (example.cn != null && example.cn!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(example.cn!,
                style: TextStyle(
                    fontSize: 13, height: 1.5, color: Colors.grey.shade700)),
          ],
        ],
      ),
    );
  }
}

class _WordChips extends StatelessWidget {
  final String label;
  final List<String> words;
  final Color color;

  const _WordChips({required this.label, required this.words, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final w in words)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(w,
                      style: TextStyle(
                          fontSize: 12.5,
                          color: color,
                          fontWeight: FontWeight.w500)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final Color color;

  const _Chip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 12, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _ActionBar extends StatelessWidget {
  final bool revealed;
  final WordProgress progress;
  final void Function(int) onGrade;
  final VoidCallback onReveal;

  const _ActionBar({
    required this.revealed,
    required this.progress,
    required this.onGrade,
    required this.onReveal,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: revealed
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      _GradeButton(
                        label: '忘记',
                        hint: Sm2.predictLabel(progress, 0),
                        color: const Color(0xFFD84315),
                        onTap: () => onGrade(0),
                      ),
                      const SizedBox(width: 8),
                      _GradeButton(
                        label: '模糊',
                        hint: Sm2.predictLabel(progress, 1),
                        color: const Color(0xFFEF6C00),
                        onTap: () => onGrade(1),
                      ),
                      const SizedBox(width: 8),
                      _GradeButton(
                        label: '一般',
                        hint: Sm2.predictLabel(progress, 2),
                        color: const Color(0xFF7CB342),
                        onTap: () => onGrade(2),
                      ),
                      const SizedBox(width: 8),
                      _GradeButton(
                        label: '熟悉',
                        hint: Sm2.predictLabel(progress, 3),
                        color: const Color(0xFF2E7D32),
                        onTap: () => onGrade(3),
                      ),
                      const SizedBox(width: 8),
                      _GradeButton(
                        label: '秒杀',
                        hint: Sm2.predictLabel(progress, 4),
                        color: const Color(0xFF1565C0),
                        onTap: () => onGrade(4),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '按记忆程度选择，算法自动安排下次复习',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              )
            : SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onReveal,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('显示答案', style: TextStyle(fontSize: 16)),
                ),
              ),
      ),
    );
  }
}

class _GradeButton extends StatelessWidget {
  final String label;
  final String hint;
  final Color color;
  final VoidCallback onTap;

  const _GradeButton({
    required this.label,
    required this.hint,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: color)),
              const SizedBox(height: 2),
              Text(hint,
                  style: TextStyle(fontSize: 10.5, color: color.withValues(alpha: 0.8))),
            ],
          ),
        ),
      ),
    );
  }
}
