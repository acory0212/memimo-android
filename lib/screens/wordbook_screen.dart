import 'package:flutter/material.dart';

import '../models/word.dart';
import '../services/sm2.dart';
import '../services/store.dart';
import 'word_detail_screen.dart';
import '../theme.dart';

class WordbookScreen extends StatefulWidget {
  const WordbookScreen({super.key});

  @override
  State<WordbookScreen> createState() => _WordbookScreenState();
}

class _WordbookScreenState extends State<WordbookScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  _Filter _filter = _Filter.all;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Word> _filtered() {
    final s = Store.I;
    Iterable<Word> it = s.allWords;
    switch (_filter) {
      case _Filter.learned:
        it = it.where((w) => (s.progress[w.id]?.reviewCount ?? 0) > 0);
      case _Filter.favorite:
        it = it.where((w) => s.favorites.contains(w.id));
      case _Filter.mistake:
        it = it.where((w) => (s.progress[w.id]?.lapseCount ?? 0) > 0);
      case _Filter.unlearned:
        it = it.where((w) => (s.progress[w.id]?.reviewCount ?? 0) == 0);
      case _Filter.all:
        break;
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      it = it.where((w) =>
          w.word.toLowerCase().contains(q) ||
          w.translations.any((t) => t.cn.contains(q)));
    }
    return it.toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered();
    final s = Store.I;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('词库',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text('${s.allWords.length} 词',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v.trim()),
                  decoration: InputDecoration(
                    hintText: '搜索单词或中文释义',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                          label: '全部',
                          selected: _filter == _Filter.all,
                          onTap: () => setState(() => _filter = _Filter.all)),
                      _FilterChip(
                          label: '已学',
                          selected: _filter == _Filter.learned,
                          onTap: () => setState(() => _filter = _Filter.learned)),
                      _FilterChip(
                          label: '未学',
                          selected: _filter == _Filter.unlearned,
                          onTap: () => setState(() => _filter = _Filter.unlearned)),
                      _FilterChip(
                          label: '收藏',
                          selected: _filter == _Filter.favorite,
                          onTap: () => setState(() => _filter = _Filter.favorite)),
                      _FilterChip(
                          label: '错题',
                          selected: _filter == _Filter.mistake,
                          onTap: () => setState(() => _filter = _Filter.mistake)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Text('没有匹配的单词',
                        style: TextStyle(color: Colors.grey.shade500)))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final w = list[i];
                      final p = s.progress[w.id];
                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 8),
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => WordDetailScreen(word: w)),
                          ),
                          title: Row(
                            children: [
                              Text(w.word,
                                  style: const TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.w600)),
                              if (s.favorites.contains(w.id)) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.star,
                                    size: 14, color: Color(0xFFF9A825)),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            w.primaryMeaning,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                          ),
                          trailing: p == null || p.reviewCount == 0
                              ? Text('未学',
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.grey.shade400))
                              : Text(
                                  _statusText(p),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Store.I.isMastered(p)
                                        ? const Color(0xFF2E7D32)
                                        : Colors.grey.shade600,
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _statusText(WordProgress p) {
    if (Store.I.isMastered(p)) return '已掌握';
    if (p.reviewCount == 0) return '未学';
    final days = p.dueDate.difference(DateTime.now()).inDays;
    if (days < 0) return '待复习';
    if (days == 0) return '今天';
    return '$days 天后';
  }
}

enum _Filter { all, learned, unlearned, favorite, mistake }

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppPalette.primary : Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              color: selected ? Colors.white : Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }
}
