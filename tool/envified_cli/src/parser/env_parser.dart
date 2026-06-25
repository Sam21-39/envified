/// Parses `.env`-format files into a key-value map.
///
/// Supports:
/// - `KEY=value` and `KEY="quoted value"`
/// - `#` line comments
/// - Blank lines
/// - Multi-word quoted values with spaces
///
/// Ignores `.env.example`, `.env.sample`, `.env.*.template`.
class EnvParser {
  /// Parses [content] (the raw text of a `.env` file) into a String map.
  Map<String, String> parse(String content) {
    final result = <String, String>{};
    for (final line in content.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

      final eqIdx = trimmed.indexOf('=');
      if (eqIdx <= 0) continue;

      final key = trimmed.substring(0, eqIdx).trim();
      if (key.isEmpty) continue;

      String value = trimmed.substring(eqIdx + 1).trim();

      // Strip inline comments (only outside quotes).
      value = _stripInlineComment(value);

      // Unwrap surrounding quotes.
      if ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'"))) {
        value = value.substring(1, value.length - 1);
      }

      result[key] = value;
    }
    return result;
  }

  /// Returns true if [fileName] is a template/example that should be skipped.
  static bool isIgnoredFile(String fileName) {
    final lower = fileName.toLowerCase();
    return lower.endsWith('.example') ||
        lower.endsWith('.sample') ||
        lower.endsWith('.template') ||
        lower.contains('backup') ||
        lower.contains('_old') ||
        lower.contains('.bak') ||
        lower.contains('.tmp');
  }

  String _stripInlineComment(String value) {
    // Only strip if not inside a quoted string.
    if (value.startsWith('"') || value.startsWith("'")) return value;
    final commentIdx = value.indexOf(' #');
    if (commentIdx > 0) return value.substring(0, commentIdx).trim();
    return value;
  }
}
