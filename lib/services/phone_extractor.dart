/// Extracts Indian mobile numbers from OCR text.
/// Formatting (spaces, hyphens, dots, parentheses, country code) does not
/// matter. After cleanup, only a 10-digit number starting with 6-9 is valid.
/// Country code (91) and STD prefix (0) are removed automatically.
class PhoneExtractor {
  // Matches a number-like cluster: digits + connectors (space/hyphen/dot/parens/plus)
  static final RegExp _cluster = RegExp(r'[+(]?[\d][\d\-.\s()]{5,15}\d');

  static List<String> findAll(String text) => _scan(text).valid;

  static String? findFirst(String text) {
    final v = findAll(text);
    return v.isEmpty ? null : v.first;
  }

  static List<String> findFailedCandidates(String text) => _scan(text).failedRaw;

  static _ScanResult _scan(String text) {
    final valid = <String>{};
    final failed = <String>[];

    for (final line in text.split('\n')) {
      final clusters = _cluster.allMatches(line).map((m) => m.group(0)!.trim()).toSet();
      for (final raw in clusters) {
        final digits = raw.replaceAll(RegExp(r'[^\d]'), '');
        final core = _extractCore(digits);
        if (core != null) {
          valid.add(core);
        } else if (digits.length >= 7 && digits.length <= 12) {
          failed.add(raw);
        }
      }
    }

    // Avoid duplicates: drop failed candidates that are part of a valid number.
    final filteredFailed = failed.where((raw) {
      final digits = raw.replaceAll(RegExp(r'[^\d]'), '');
      return !valid.any((v) => digits.contains(v));
    }).toList();

    return _ScanResult(valid.toList(), filteredFailed);
  }

  /// Gets the 10-digit core from digits - only the COUNT matters, not the format.
  /// 12 digits starting with '91' -> remove country code.
  /// 11 digits starting with '0' -> remove STD prefix.
  /// What remains must be exactly 10 digits starting with 6-9.
  static String? _extractCore(String digits) {
    String d = digits;
    if (d.length == 12 && d.startsWith('91')) {
      d = d.substring(2);
    } else if (d.length == 11 && d.startsWith('0')) {
      d = d.substring(1);
    }
    if (d.length == 10 && RegExp(r'^[6-9]').hasMatch(d)) return d;
    return null;
  }

  /// wa.me format: 91XXXXXXXXXX (no +, no space)
  static String toWhatsAppFormat(String tenDigitNumber) => '91$tenDigitNumber';

  /// Display format: +91 XXXXXXXXXX
  static String toDisplayFormat(String tenDigitNumber) => '+91 $tenDigitNumber';
}

class _ScanResult {
  final List<String> valid;
  final List<String> failedRaw;
  _ScanResult(this.valid, this.failedRaw);
}