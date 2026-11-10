class Translation {
  final String? pos;
  final String cn;
  final String? en;

  Translation({this.pos, required this.cn, this.en});

  factory Translation.fromJson(Map<String, dynamic> j) => Translation(
        pos: j['pos'] as String?,
        cn: (j['cn'] as String?) ?? '',
        en: j['en'] as String?,
      );
}

class Example {
  final String en;
  final String? cn;
  final String? src;

  Example({required this.en, this.cn, this.src});

  factory Example.fromJson(Map<String, dynamic> j) => Example(
        en: (j['en'] as String?) ?? '',
        cn: j['cn'] as String?,
        src: j['src'] as String?,
      );

  static Example? maybe(dynamic j) =>
      j is Map<String, dynamic> ? Example.fromJson(j) : null;
}

class Phrase {
  final String p;
  final String? cn;

  Phrase({required this.p, this.cn});

  static Phrase? maybe(dynamic j) =>
      j is Map<String, dynamic> ? Phrase(p: (j['p'] as String?) ?? '', cn: j['cn'] as String?) : null;
}

class Word {
  final int id;
  final String word;
  final String? us;
  final String? uk;
  final int star;
  final List<Translation> translations;
  final Example? example;
  final Example? examExample;
  final List<Phrase> phrases;
  final List<String> synonyms;
  final List<String> antonyms;
  final String? mnemonic;

  Word({
    required this.id,
    required this.word,
    this.us,
    this.uk,
    this.star = 0,
    required this.translations,
    this.example,
    this.examExample,
    this.phrases = const [],
    this.synonyms = const [],
    this.antonyms = const [],
    this.mnemonic,
  });

  factory Word.fromJson(Map<String, dynamic> j) {
    final ph = <Phrase>[];
    if (j['ph'] is List) {
      for (final e in (j['ph'] as List)) {
        final p = Phrase.maybe(e);
        if (p != null) ph.add(p);
      }
    }
    final syn = <String>[];
    if (j['syn'] is List) {
      for (final s in (j['syn'] as List)) {
        if (s is String && s.trim().isNotEmpty) syn.add(s);
      }
    }
    final ant = <String>[];
    if (j['ant'] is List) {
      for (final s in (j['ant'] as List)) {
        if (s is String && s.trim().isNotEmpty) ant.add(s);
      }
    }
    final tr = <Translation>[];
    if (j['tr'] is List) {
      for (final t in (j['tr'] as List)) {
        if (t is Map<String, dynamic>) tr.add(Translation.fromJson(t));
      }
    }
    return Word(
      id: (j['id'] as num).toInt(),
      word: (j['w'] as String?) ?? '',
      us: j['us'] as String?,
      uk: j['uk'] as String?,
      star: (j['star'] as num?)?.toInt() ?? 0,
      translations: tr,
      example: Example.maybe(j['ex']),
      examExample: Example.maybe(j['rex']),
      phrases: ph,
      synonyms: syn,
      antonyms: ant,
      mnemonic: j['rem'] as String?,
    );
  }

  String get primaryMeaning => translations.isEmpty ? '' : translations.first.cn;
}
