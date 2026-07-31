/// Aligns what the child was asked to read against what the recognizer
/// actually heard, so the result can be shown word by word instead of as a
/// single opaque number.
///
/// A percentage tells a six-year-old nothing they can act on. "You got five
/// of these six, this one was tricky" does.
library;

/// How one expected word fared.
enum WordOutcome {
  /// Heard as expected.
  said,

  /// Not found in the recognized speech. Deliberately named for what
  /// happened rather than as a verdict — the UI must not present this as
  /// failure.
  missed,
}

class WordResult {
  /// The word as written, punctuation and capitalisation intact, so the UI
  /// can render the original sentence rather than a normalised one.
  final String word;
  final WordOutcome outcome;

  const WordResult(this.word, this.outcome);
}

/// Strips everything that isn't a letter or an internal apostrophe, and
/// lowercases. Matches loosely on purpose: recognizers punctuate
/// unpredictably, and "cat." vs "cat" is not a pronunciation error.
String normalizeWord(String raw) {
  final lowered = raw.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lowered.runes) {
    final ch = String.fromCharCode(rune);
    if (RegExp(r"[a-z']").hasMatch(ch)) buffer.write(ch);
  }
  return buffer.toString().replaceAll(RegExp(r"^'+|'+$"), '');
}

List<String> splitWords(String text) => text
    .split(RegExp(r'\s+'))
    .where((w) => w.trim().isNotEmpty)
    .toList(growable: false);

/// Marks each expected word as [WordOutcome.said] or [WordOutcome.missed].
///
/// Uses a longest-common-subsequence alignment rather than comparing index
/// by index. Position-wise comparison breaks badly in practice: recognizers
/// insert filler and drop short words, and a single dropped word would
/// shift every later word out of alignment and mark an otherwise perfect
/// reading as entirely wrong.
///
/// Words repeated in the target are handled correctly — LCS consumes each
/// occurrence at most once, so reading "the cat sat" as "the the cat sat"
/// does not credit the duplicate against a later word.
List<WordResult> alignWords({required String expected, required String heard}) {
  final expectedWords = splitWords(expected);
  if (expectedWords.isEmpty) return const [];

  final a = expectedWords.map(normalizeWord).toList(growable: false);
  final b = splitWords(heard)
      .map(normalizeWord)
      .where((w) => w.isNotEmpty)
      .toList(growable: false);

  // Nothing recognised at all: every word is simply unattempted. Callers
  // should treat this as "we couldn't hear you", not as a wrong answer.
  if (b.isEmpty) {
    return expectedWords
        .map((w) => WordResult(w, WordOutcome.missed))
        .toList(growable: false);
  }

  // lcs[i][j] = length of the longest common subsequence of a[i:] and b[j:].
  final lcs = List.generate(
    a.length + 1,
    (_) => List<int>.filled(b.length + 1, 0),
    growable: false,
  );
  for (var i = a.length - 1; i >= 0; i--) {
    for (var j = b.length - 1; j >= 0; j--) {
      lcs[i][j] = a[i] == b[j]
          ? lcs[i + 1][j + 1] + 1
          : (lcs[i + 1][j] > lcs[i][j + 1] ? lcs[i + 1][j] : lcs[i][j + 1]);
    }
  }

  // Walk the table forwards, recording which expected words the matching
  // subsequence actually covers.
  final results = <WordResult>[];
  var i = 0;
  var j = 0;
  while (i < a.length) {
    if (j < b.length && a[i] == b[j]) {
      results.add(WordResult(expectedWords[i], WordOutcome.said));
      i++;
      j++;
    } else if (j < b.length && lcs[i + 1][j] > lcs[i][j + 1]) {
      results.add(WordResult(expectedWords[i], WordOutcome.missed));
      i++;
    } else if (j < b.length) {
      // Strictly greater above, so ties fall through to here and skip the
      // heard word instead of condemning the expected one. Both branches
      // give an equally long match, but this one blames the recognizer
      // rather than the child: reading "the cat" as "the the cat" should
      // credit "cat", not mark it missed because a stutter consumed the
      // alignment. The charitable reading is also the accurate one.
      // The recognizer heard something extra here. Skip it: inserted words
      // are not shown, because the child was not asked to read them and
      // flagging them would punish background noise.
      j++;
    } else {
      results.add(WordResult(expectedWords[i], WordOutcome.missed));
      i++;
    }
  }
  return List.unmodifiable(results);
}
