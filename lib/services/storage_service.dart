import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/contact_entry.dart';

class StorageService {
  static const _key = 'scanned_entries';

  static Future<List<ContactEntry>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // always read the latest saved data
    final raw = prefs.getStringList(_key) ?? [];
    final entries = raw.map((e) => ContactEntry.fromJson(jsonDecode(e))).toList();
    entries.sort((a, b) => b.scannedAt.compareTo(a.scannedAt)); // newest first

    // Clean up duplicates that may already exist from older versions.
    final deduped = _dedupe(entries);
    if (deduped.length != entries.length) await _saveAll(deduped);
    return deduped;
  }

  /// Keeps one entry per number (the newest), filling missing name/email from older ones.
  static List<ContactEntry> _dedupe(List<ContactEntry> newestFirst) {
    final indexByNumber = <String, int>{};
    final out = <ContactEntry>[];
    for (final e in newestFirst) {
      final i = indexByNumber[e.number];
      if (i == null) {
        indexByNumber[e.number] = out.length;
        out.add(e);
      } else {
        final keep = out[i];
        out[i] = ContactEntry(
          id: keep.id,
          number: keep.number,
          display: keep.display,
          name: keep.name ?? e.name,
          email: keep.email ?? e.email,
          scannedAt: keep.scannedAt,
        );
      }
    }
    return out;
  }

  /// Adds a new entry, or - if the number already exists - updates the old one
  /// (new scan time, moved to top, missing name/email filled in). Never duplicates.
  /// Existing name/email are kept, since the user may have edited them.
  static Future<ContactEntry> upsert(ContactEntry incoming) async {
    final all = await loadAll();
    final idx = all.indexWhere((e) => e.number == incoming.number);

    final ContactEntry result;
    if (idx == -1) {
      result = incoming;
    } else {
      final old = all.removeAt(idx);
      result = ContactEntry(
        id: old.id,
        number: old.number,
        display: old.display,
        name: old.name ?? incoming.name,
        email: old.email ?? incoming.email,
        scannedAt: incoming.scannedAt,
      );
    }
    all.insert(0, result);
    await _saveAll(all);
    return result;
  }

  /// True if another entry (not [exceptId]) already has this wa.me number.
  static Future<bool> numberExists(String waNumber, {String? exceptId}) async {
    final all = await loadAll();
    return all.any((e) => e.number == waNumber && e.id != exceptId);
  }

  static Future<void> update(ContactEntry updated) async {
    final all = await loadAll();
    final idx = all.indexWhere((e) => e.id == updated.id);
    if (idx != -1) {
      all[idx] = updated;
      await _saveAll(all);
    }
  }

  static Future<void> delete(String id) async {
    final all = await loadAll();
    all.removeWhere((e) => e.id == id);
    await _saveAll(all);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Future<void> _saveAll(List<ContactEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = entries.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_key, raw);
  }
}