class LessonEntity {
  final int id;
  final int order;
  final String level;
  final List<PhonemeEntity> phonemes;
  final int totalExercises;
  final int completedExercises;

  const LessonEntity({
    required this.id,
    required this.order,
    required this.level,
    required this.phonemes,
    required this.totalExercises,
    required this.completedExercises,
  });

  double get progressPercent =>
      totalExercises == 0 ? 0 : completedExercises / totalExercises;

  bool get isCompleted =>
      completedExercises >= totalExercises && totalExercises > 0;
  bool get isStarted => completedExercises > 0;
}

class PhonemeEntity {
  final int id;
  final String symbol;
  final String description;
  final String? audioUrl;
  final String type;
  final int order;

  const PhonemeEntity({
    required this.id,
    required this.symbol,
    required this.description,
    this.audioUrl,
    required this.type,
    required this.order,
  });

  String get dualCaseSymbol {
    String capitalize(String s) {
      if (s.isEmpty) return s;
      return s[0].toUpperCase() + s.substring(1);
    }

    String raw = symbol;
    
    final regex = RegExp(r'^([^(]+)\s*\(([^)]+)\)$');
    final match = regex.firstMatch(raw);
    if (match != null) {
      final mainPart = match.group(1)!.trim();
      final parenPart = match.group(2)!.trim();
      
      final spellingParts = parenPart.split('/');
      final formattedSpellings = spellingParts.map((sp) {
        final s = sp.trim();
        if (s.contains('silent') || s.contains('voiced') || s.contains('unvoiced') || s.contains('in some words')) {
          return capitalize(s);
        }
        return '${capitalize(s)} $s';
      }).join(' / ');
      
      return '$formattedSpellings ($mainPart)';
    }

    if (raw.contains('/') && !raw.contains('(')) {
      return raw.split('/').map((s) {
        final trimmed = s.trim();
        return '${capitalize(trimmed)} ${trimmed.toLowerCase()}';
      }).join(' / ');
    }

    final clean = raw.trim();
    return '${capitalize(clean)} ${clean.toLowerCase()}';
  }
}
