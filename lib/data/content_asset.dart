/// Extraction of the bundled content database out of the asset bundle.
///
/// SQLite cannot open a file inside the Flutter asset bundle, so the asset is
/// copied once into app support storage. A marker file records which content
/// version was extracted; when the app ships new decks the marker stops
/// matching [bundledContentVersion] and the copy is replaced. Review progress
/// lives in a separate database keyed by `card.uid`, so replacing the content
/// never discards a user's history.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import 'content_version.dart';

class ContentAsset {
  const ContentAsset._();

  static const assetPath = 'assets/content/content.db';
  static const fileName = 'content.db';
  static const markerName = 'content.version';

  /// Whether [ensureExtracted] would have to copy the asset.
  ///
  /// Lets the UI say "this happens once" before a multi-second extraction,
  /// instead of showing a bare spinner that looks like a hang.
  static Future<bool> needsExtraction(Directory directory) async {
    final marker = File(p.join(directory.path, markerName));
    if (!File(p.join(directory.path, fileName)).existsSync()) return true;
    if (!marker.existsSync()) return true;
    return (await marker.readAsString()).trim() != bundledContentVersion;
  }

  /// Ensures an up-to-date copy exists in [directory] and returns its path.
  static Future<String> ensureExtracted(Directory directory) async {
    await directory.create(recursive: true);
    final dbPath = p.join(directory.path, fileName);
    final marker = File(p.join(directory.path, markerName));

    final extractedVersion =
        marker.existsSync() ? (await marker.readAsString()).trim() : null;
    final upToDate =
        File(dbPath).existsSync() && extractedVersion == bundledContentVersion;

    if (!upToDate) {
      await _copy(dbPath);
      await marker.writeAsString(bundledContentVersion, flush: true);
      debugPrint('ContentAsset: extracted content $bundledContentVersion '
          '(was ${extractedVersion ?? 'absent'})');
    }
    return dbPath;
  }

  static Future<void> _copy(String dbPath) async {
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

    // Write to a sibling temp file and rename. A process killed mid-copy would
    // otherwise leave a truncated database that the marker then blesses.
    final temp = File('$dbPath.tmp');
    await temp.writeAsBytes(bytes, flush: true);
    final target = File(dbPath);
    if (target.existsSync()) await target.delete();
    await temp.rename(dbPath);
  }
}

/// Mirrors `fold()` in tools/build_content.py: both must agree, or searching
/// for "grosse" stops finding "große".
String foldForSearch(String input) {
  const map = <String, String>{
    'ä': 'ae', 'ö': 'oe', 'ü': 'ue', 'ß': 'ss',
    'é': 'e', 'è': 'e', 'ê': 'e', 'á': 'a', 'à': 'a', 'â': 'a',
    'í': 'i', 'ì': 'i', 'ó': 'o', 'ò': 'o', 'ô': 'o',
    'ú': 'u', 'ù': 'u', 'ç': 'c', 'ñ': 'n',
  };
  final out = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    final ch = String.fromCharCode(rune);
    out.write(map[ch] ?? ch);
  }
  return out.toString();
}
