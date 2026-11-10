import 'package:flutter/material.dart';

import '../models/word.dart';
import '../services/audio_player.dart';
import '../services/ebbinghaus.dart';
import '../services/sm2.dart';
import '../services/store.dart';
import '../theme.dart';

class WordDetailScreen extends StatefulWidget {
  final Word word;
  const WordDetailScreen({super.key, required this.word});

  @override
  State<WordDetailScreen> createState() => _WordDetailScreenState();
}

class _WordDetailScreenState extends State<WordDetailScreen> {
  final AudioPlayerService _audio = AudioPlayerService();

  @override
  Widget build(BuildContext context) {
    final w = widget.word;
    final p = Store.I.progress[w.id];

    return Scaffold(
      appBar: AppBar(
        title: Text(w.word),
        actions: [
          IconButton(
            icon: Icon(
              Store.I.favorites.contains(w.id) ? Icons.star : Icons.star_border,
              color: const Color(0xFFF9A825),
            ),
            onPressed: () => setState(() => Store.I.toggleFavorite(w.id)),
          ),
          IconButton(
            icon: const Icon(Icons.volume_up_outlined),
            onPressed: () => _audio.play(w.id),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          Text(w.word,
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700)),
          if ((w.uk ?? '').isNotEmpty || (w.us ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              [
                if ((w.uk ?? '').isNotEmpty) '英 /${w.uk}/',
                if ((w.us ?? '').isNotEmpty) '美 /${w.us}/',
              ].join('   '),
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final t in w.translations)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text.rich(
                      TextSpan(
                        style: const TextStyle(fontSize: 16, height: 1.5),
                        children: [
                          if ((t.pos ?? '').isNotEmpty)
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
              ],
            ),
          ),
          if ((w.mnemonic ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            _Box(
              icon: Icons.lightbulb_outline,
              title: '助记',
              child: Text(w.mnemonic!,
                  style: const TextStyle(fontSize: 13.5, height: 1.55)),
            ),
          ],
          if (w.example != null) ...[
            const SizedBox(height: 12),
            _Box(
              icon: Icons.format_quote,
              title: '例句',
              child: _ExampleView(example: w.example!),
            ),
          ],
          if (w.examExample != null) ...[
            const SizedBox(height: 12),
            _Box(
              icon: Icons.school_outlined,
              title: '真题例句',
              child: _ExampleView(example: w.examExample!),
            ),
          ],
          if (w.phrases.isNotEmpty) ...[
            const SizedBox(height: 12),
            _Box(
              icon: Icons.link,
              title: '短语',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final ph in w.phrases)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text.rich(
                        TextSpan(
                          style: const TextStyle(fontSize: 13.5, height: 1.5),
                          children: [
                            TextSpan(
                                text: ph.p,
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            if ((ph.cn ?? '').isNotEmpty)
                              TextSpan(
                                  text: '  ${ph.cn}',
                                  style: TextStyle(color: Colors.grey.shade700)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (w.synonyms.isNotEmpty || w.antonyms.isNotEmpty) ...[
            const SizedBox(height: 12),
            _Box(
              icon: Icons.compare_arrows,
              title: '同反义',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (w.synonyms.isNotEmpty)
                    Text('近义：${w.synonyms.join(' / ')}',
                        style: const TextStyle(fontSize: 13.5, height: 1.6)),
                  if (w.antonyms.isNotEmpty)
                    Text('反义：${w.antonyms.join(' / ')}',
                        style: const TextStyle(fontSize: 13.5, height: 1.6)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (p != null && p.reviewCount > 0) _ProgressCard(p: p),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              Store.I.markUnknown(w);
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已重置为未学，稍后会重新出现')),
              );
            },
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('重新学习此词'),
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final WordProgress p;
  const _ProgressCard({required this.p});

  @override
  Widget build(BuildContext context) {
    final due = p.dueDate;
    final days = due.difference(DateTime.now()).inDays;
    final dueText = days < 0
        ? '已到期'
        : days == 0
            ? '今天'
            : '$days 天后';
    final eb = Store.I.useEbbinghaus;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.soft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights, size: 16, color: AppPalette.primary),
              const SizedBox(width: 6),
              const Text('学习记录',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(Store.I.memoryMethodName,
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade600)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _kv('复习次数', '${p.reviewCount}'),
              _kv('遗忘次数', '${p.lapseCount}'),
              if (eb) ...[
                _kv('记忆阶段', '第 ${Ebbinghaus.stageOf(p) + 1} 级'),
                _kv('本级间隔', Ebbinghaus.labelOf(p)),
              ] else ...[
                _kv('记忆强度', p.easeFactor.toStringAsFixed(2)),
                _kv('当前间隔', p.interval < 1
                    ? '${(p.interval * 24).round()} 小时'
                    : '${p.interval.round()} 天'),
              ],
              _kv('下次复习', dueText),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          const SizedBox(height: 2),
          Text(v,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      );
}

class _Box extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _Box({required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
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
              Icon(icon, size: 15, color: AppPalette.primary),
              const SizedBox(width: 5),
              Text(title,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700)),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _ExampleView extends StatelessWidget {
  final Example example;
  const _ExampleView({required this.example});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(example.en, style: const TextStyle(fontSize: 14, height: 1.55)),
        if ((example.cn ?? '').isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(example.cn!,
              style: TextStyle(
                  fontSize: 13, height: 1.5, color: Colors.grey.shade700)),
        ],
        if ((example.src ?? '').isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(example.src!,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ],
      ],
    );
  }
}
