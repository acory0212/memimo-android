import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/self_check.dart';
import '../models/word.dart';
import '../services/store.dart';
import '../theme.dart';

/// 每日自我检查：检验真实记忆，而不是学习
///
/// 两种题型自由组合（设置页可切换）：
/// - 看单词选意思（四选一）
/// - 看意思写单词（拼写）
///
/// 答对不动曲线，答错才把这个词拉回复习队列。
class SelfCheckScreen extends StatefulWidget {
  const SelfCheckScreen({super.key});

  @override
  State<SelfCheckScreen> createState() => _SelfCheckScreenState();
}

class _SelfCheckScreenState extends State<SelfCheckScreen> {
  late List<SelfCheckQuestion> _questions;
  int _idx = 0;

  /// 选择题=选中的选项；拼写题=用户输入
  String? _picked;
  bool _finished = false;
  int _correct = 0;
  final List<Word> _missed = [];
  Timer? _timer;
  final TextEditingController _input = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _questions = Store.I.buildSelfCheckQuestions();
    if (_questions.isEmpty) _finished = true;
    _focusFirstIfSpelling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _focusFirstIfSpelling() {
    if (_questions.isEmpty || !_questions[0].isSpelling) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  /// 选中某个选项 / 提交拼写
  void _commit(String picked, bool ok) {
    if (_picked != null) return;
    final q = _questions[_idx];
    setState(() {
      _picked = picked;
      if (ok) {
        _correct++;
      } else {
        _missed.add(q.word);
      }
    });
    if (ok) {
      _focus.unfocus();
      _timer = Timer(const Duration(milliseconds: 850), _next);
    } else {
      // 答错停下来，让用户看清正确答案，再手动继续
      _focus.unfocus();
    }
  }

  void _answerChoice(String option) {
    final q = _questions[_idx];
    _commit(option, option == q.answer);
  }

  void _answerSpelling() {
    if (_picked != null) return;
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _commit(text, _questions[_idx].check(text));
  }

  void _next() {
    _timer?.cancel();
    if (!mounted) return;
    if (_idx + 1 >= _questions.length) {
      Store.I.recordSelfCheck(_questions.length, _correct);
      for (final w in _missed) {
        Store.I.applySelfCheckMiss(w);
      }
      setState(() => _finished = true);
      return;
    }
    setState(() {
      _idx++;
      _picked = null;
      _input.clear();
    });
    final q = _questions[_idx];
    if (q.isSpelling) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
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
      _input.clear();
    });
    _focusFirstIfSpelling();
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
    final revealed = _picked != null;
    final isRight = revealed && q.check(_picked!);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${_idx + 1} / ${_questions.length}',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade500)),
                  _TypeChip(isSpelling: q.isSpelling),
                ],
              ),
              const SizedBox(height: 24),
              if (q.isSpelling)
                ..._spellingBody(q, revealed, isRight)
              else
                ..._choiceBody(q, revealed),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
            child: Text(
              revealed
                  ? (isRight ? '答对了，马上到下一题' : '答错的词会退回复习队列')
                  : (q.isSpelling ? '拼出这个单词，注意拼写' : '选出正确的中文意思'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
            ),
          ),
        ),
      ],
    );
  }

  // ---------- 选择题 ----------

  List<Widget> _choiceBody(SelfCheckQuestion q, bool revealed) {
    final phonetics = [
      if (q.word.uk != null && q.word.uk!.isNotEmpty) '英 /${q.word.uk}/',
      if (q.word.us != null && q.word.us!.isNotEmpty) '美 /${q.word.us}/',
    ].join('   ');

    return [
      Text(
        q.prompt,
        textAlign: TextAlign.center,
        style: const TextStyle(
            fontSize: 38, fontWeight: FontWeight.w700, letterSpacing: 0.5),
      ),
      if (phonetics.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(phonetics,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
      ],
      const SizedBox(height: 28),
      for (final opt in q.options)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _OptionTile(
            text: opt,
            revealed: revealed,
            isAnswer: opt == q.answer,
            isPicked: opt == _picked,
            onTap: () => _answerChoice(opt),
          ),
        ),
      if (revealed) _continueButton(),
    ];
  }

  // ---------- 拼写题 ----------

  List<Widget> _spellingBody(
      SelfCheckQuestion q, bool revealed, bool isRight) {
    final pos = q.word.translations.isNotEmpty
        ? q.word.translations.first.pos
        : null;

    return [
      if (pos != null && pos.isNotEmpty) ...[
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppPalette.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(pos,
                style: TextStyle(
                    fontSize: 12.5,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600,
                    color: AppPalette.primary)),
          ),
        ),
        const SizedBox(height: 18),
      ],
      Text(
        q.prompt,
        textAlign: TextAlign.center,
        style: const TextStyle(
            fontSize: 26, height: 1.4, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 30),
      TextField(
        controller: _input,
        focusNode: _focus,
        enabled: !revealed,
        textAlign: TextAlign.center,
        autocorrect: false,
        enableSuggestions: false,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _answerSpelling(),
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
          color: revealed
              ? (isRight ? const Color(0xFF2E7D32) : const Color(0xFFD84315))
              : Colors.black87,
        ),
        decoration: InputDecoration(
          hintText: '输入英文单词',
          hintStyle: TextStyle(
              fontSize: 15, color: Colors.grey.shade400, letterSpacing: 0),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: BorderSide(
              color: revealed
                  ? (isRight
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFFD84315))
                  : Colors.grey.shade300,
              width: 1.6,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: BorderSide(color: AppPalette.primary, width: 1.6),
          ),
        ),
      ),
      const SizedBox(height: 14),
      if (!revealed)
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _answerSpelling,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13)),
            ),
            child: const Text('提交', style: TextStyle(fontSize: 15)),
          ),
        ),
      if (revealed && !isRight)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF2E7D32).withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle,
                  size: 18, color: Color(0xFF2E7D32)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  q.answer,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: Color(0xFF2E7D32)),
                ),
              ),
            ],
          ),
        ),
      if (revealed) _continueButton(),
    ];
  }

  Widget _continueButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _next,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          ),
          child: const Text('继续', style: TextStyle(fontSize: 15)),
        ),
      ),
    );
  }

  // ---------- 结果页 ----------

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
    final spellCount =
        _questions.where((q) => q.isSpelling).length;
    final choiceCount = total - spellCount;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
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
                    if (choiceCount > 0 && spellCount > 0) ...[
                      const SizedBox(height: 4),
                      Text('选择 $choiceCount 题 · 拼写 $spellCount 题',
                          style: TextStyle(
                              fontSize: 11.5, color: Colors.grey.shade500)),
                    ],
                    const SizedBox(height: 12),
                    Text(_verdict(pct),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              if (_missed.isNotEmpty) ...[
                const SizedBox(height: 28),
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
                    child:
                        const Text('再测一次', style: TextStyle(fontSize: 15)),
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

class _TypeChip extends StatelessWidget {
  final bool isSpelling;
  const _TypeChip({required this.isSpelling});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: isSpelling
            ? const Color(0xFF6A1B9A).withValues(alpha: 0.09)
            : const Color(0xFF1976D2).withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSpelling ? Icons.edit_outlined : Icons.list_alt,
            size: 12,
            color: isSpelling
                ? const Color(0xFF6A1B9A)
                : const Color(0xFF1976D2),
          ),
          const SizedBox(width: 3),
          Text(
            isSpelling ? '拼写' : '选择',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isSpelling
                  ? const Color(0xFF6A1B9A)
                  : const Color(0xFF1976D2),
            ),
          ),
        ],
      ),
    );
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
