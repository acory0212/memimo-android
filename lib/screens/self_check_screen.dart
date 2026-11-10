import 'dart:async';

import 'package:flutter/material.dart';

import '../models/self_check.dart';
import '../models/word.dart';
import '../services/store.dart';

/// 每日自我检查：从已学词汇里抽题，四选一检验真实记忆
///
/// 和「学习」不同，这里是**检验**而不是学习：
/// 答对不动曲线，答错才把这个词拉回复习队列。
class SelfCheckScreen extends StatefulWidget {
  const SelfCheckScreen({super.key});

  @override
  State<SelfCheckScreen> createState() => _SelfCheckScreenState();
}

class _SelfCheckScreenState extends State<SelfCheckScreen> {
  late List<SelfCheckQuestion> _questions;
  int _idx = 0;
  String? _picked;
  bool _finished = false;
  int _correct = 0;
  final List<Word> _missed = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _questions = Store.I.buildSelfCheckQuestions();
    if (_questions.isEmpty) _finished = true;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _pick(String option) {
    if (_picked != null) return;
    final q = _questions[_idx];
    final ok = option == q.answer;
    setState(() {
      _picked = option;
      if (ok) {
        _correct++;
      } else {
        _missed.add(q.word);
      }
    });
    _timer = Timer(const Duration(milliseconds: 950), () {
      if (!mounted) return;
      if (_idx + 1 >= _questions.length) {
        Store.I.recordSelfCheck(_questions.length, _correct);
        for (final w in _missed) {
          Store.I.applySelfCheckMiss(w);
        }
        setState(() => _finished = true);
      } else {
        setState(() {
          _idx++;
          _picked = null;
        });
      }
    });
  }

  void _restart() {
    final qs = Store.I.buildSelfCheckQuestions();
    setState(() {
      _questions = qs;
      _idx = 0;
      _picked = null;
      _correct = 0;
      _missed.clear();
      _finished = qs.isEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = _questions.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(_finished ? '检查结果' : '每日自我检查'),
        actions: [
          if (!_finished)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('结束'),
            ),
        ],
        bottom: _finished
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : _idx / total,
                  minHeight: 3,
                ),
              ),
      ),
      body: _finished ? _buildResult() : _buildQuestion(),
    );
  }

  Widget _buildQuestion() {
    final q = _questions[_idx];
    final phonetics = [
      if (q.word.uk != null && q.word.uk!.isNotEmpty) '英 /${q.word.uk}/',
      if (q.word.us != null && q.word.us!.isNotEmpty) '美 /${q.word.us}/',
    ].join('   ');

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
            children: [
              Text('${_idx + 1} / ${_questions.length}',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(fontSize: 13, color: Colors.grey.shade500)),
              const SizedBox(height: 26),
              Text(
                q.word.word,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5),
              ),
              if (phonetics.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(phonetics,
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              ],
              const SizedBox(height: 30),
              for (final opt in q.options)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _OptionTile(
                    text: opt,
                    revealed: _picked != null,
                    isAnswer: opt == q.answer,
                    isPicked: opt == _picked,
                    onTap: () => _pick(opt),
                  ),
                ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
            child: Text(
              _picked == null ? '选出正确的中文意思' : '答错的词会退回复习队列',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResult() {
    final total = _questions.length;
    if (total == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.school_outlined, size: 56, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              const Text('还没有可以检查的单词',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('先学几个词再来检验吧',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                ),
                child: const Text('去学习'),
              ),
            ],
          ),
        ),
      );
    }

    final pct = (_correct / total * 100).round();
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 12),
            children: [
              Center(
                child: Column(
                  children: [
                    Text('$pct%',
                        style: TextStyle(
                          fontSize: 58,
                          height: 1.0,
                          fontWeight: FontWeight.w700,
                          color: _scoreColor(pct),
                        )),
                    const SizedBox(height: 10),
                    Text('$_correct / $total 答对',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade600)),
                    const SizedBox(height: 12),
                    Text(_verdict(pct),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              if (_missed.isNotEmpty) ...[
                const SizedBox(height: 30),
                Row(
                  children: [
                    Icon(Icons.error_outline,
                        size: 15, color: const Color(0xFFD84315)),
                    const SizedBox(width: 6),
                    Text('需要加强（${_missed.length} 个）',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 10),
                for (final w in _missed)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD84315).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Text(w.word,
                            style: const TextStyle(
                                fontSize: 14.5, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            w.translations.isNotEmpty
                                ? w.translations.first.cn
                                : '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12.5, color: Colors.grey.shade600),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  '这些词已退回复习队列，会在今天或明天的学习中再次出现',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
                ),
              ],
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('完成', style: TextStyle(fontSize: 15)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _restart,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('再测一次',
                        style: TextStyle(fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Color _scoreColor(int pct) {
    if (pct >= 85) return const Color(0xFF2E7D32);
    if (pct >= 60) return const Color(0xFF7CB342);
    if (pct >= 40) return const Color(0xFFEF6C00);
    return const Color(0xFFD84315);
  }

  String _verdict(int pct) {
    if (pct >= 90) return '记得很牢，保持这个节奏';
    if (pct >= 75) return '掌握得不错，再补几个漏的';
    if (pct >= 50) return '有一半还不稳，建议多看两眼';
    return '这批词忘得比较多，需要回去重学';
  }
}

class _OptionTile extends StatelessWidget {
  final String text;
  final bool revealed;
  final bool isAnswer;
  final bool isPicked;
  final VoidCallback onTap;

  const _OptionTile({
    required this.text,
    required this.revealed,
    required this.isAnswer,
    required this.isPicked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color border = Colors.grey.shade200;
    Color bg = Colors.white;
    Color fg = Colors.black87;
    IconData? icon;

    if (revealed) {
      if (isAnswer) {
        border = const Color(0xFF2E7D32);
        bg = const Color(0xFF2E7D32).withValues(alpha: 0.07);
        fg = const Color(0xFF2E7D32);
        icon = Icons.check_circle;
      } else if (isPicked) {
        border = const Color(0xFFD84315);
        bg = const Color(0xFFD84315).withValues(alpha: 0.07);
        fg = const Color(0xFFD84315);
        icon = Icons.cancel;
      } else {
        fg = Colors.grey.shade400;
      }
    }

    return GestureDetector(
      onTap: revealed ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        constraints: const BoxConstraints(minHeight: 58),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: border,
            width: (revealed && (isAnswer || isPicked)) ? 1.6 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                    fontSize: 15,
                    height: 1.35,
                    color: fg,
                    fontWeight: (revealed && isAnswer)
                        ? FontWeight.w600
                        : FontWeight.normal),
              ),
            ),
            if (icon != null) ...[
              const SizedBox(width: 10),
              Icon(icon, size: 20, color: fg),
            ],
          ],
        ),
      ),
    );
  }
}
