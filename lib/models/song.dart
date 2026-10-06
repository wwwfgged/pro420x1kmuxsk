import 'dart:io';

/// Дістати чисту назву файлу з повного шляху, незалежно від того,
/// якими слешами (Windows "\" чи Unix "/") представлений шлях.
String basenameOf(String path) => path.split(RegExp(r'[\\/]')).last;

/// Прибрати розширення аудіофайлу з назви.
String stripAudioExt(String name) =>
    name.replaceAll(RegExp(r'\.(mp3|m4a|aac|mp4|webm|ogg)$', caseSensitive: false), '');

class Song {
  final String title;
  final String artist;
  final String filePath;
  final String? coverPath;
  Song({required this.title, required this.artist, required this.filePath, this.coverPath});
}

/// Трекінг посилань-джерел (YouTube/TikTok) для кожної завантаженої пісні.
/// Один файл sources.txt в корені Music\muzik420\, формат:
///   C:\шлях\до\пісня.mp3|https://youtube.com/watch?v=...
/// Пісні без посилання (додані вручну) просто відсутні в цьому файлі.
class SourceStore {
  static const _fileName = 'sources.txt';

  static String fileNameOf() => _fileName;

  static Future<Map<String, String>> readAll(File file) async {
    final map = <String, String>{};
    if (!await file.exists()) return map;
    try {
      final lines = (await file.readAsString()).split(RegExp(r'\r?\n'));
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        final idx = line.indexOf('|');
        if (idx <= 0) continue;
        final path = line.substring(0, idx);
        final url = line.substring(idx + 1);
        if (url.isNotEmpty) map[path] = url;
      }
    } catch (_) {}
    return map;
  }

  static Future<void> set(File file, String songPath, String sourceUrl) async {
    final map = await readAll(file);
    map[songPath] = sourceUrl;
    await _writeAll(file, map);
  }

  static Future<void> remove(File file, String songPath) async {
    final map = await readAll(file);
    map.remove(songPath);
    await _writeAll(file, map);
  }

  static Future<void> _writeAll(File file, Map<String, String> map) async {
    final buf = StringBuffer();
    map.forEach((path, url) => buf.writeln('$path|$url'));
    await file.writeAsString(buf.toString());
  }
}

class MusicPlaylist {
  final String name;
  final List<Song> songs;
  MusicPlaylist({required this.name, required this.songs});
}

class PlaylistEntry {
  final String name;
  final List<String> paths;
  PlaylistEntry(this.name, this.paths);
}

/// ВСІ плейлисти зберігаються в ОДНОМУ текстовому файлі
/// (Music\muzik420\playlists.txt), кожен плейліст — свій блок:
///
///   muzikmen(Назва плейлиста 1)
///   C:\шлях\до\пісня1.mp3
///   C:\шлях\до\пісня2.mp3
///   кінець плейлисту
///   muzikmen(Назва плейлиста 2)
///   C:\шлях\до\пісня3.mp3
///   кінець плейлисту
///
/// Файл містить лише ШЛЯХИ до існуючих пісень (без копіювання самих файлів).
class PlaylistStore {
  static const _footer = 'кінець плейлисту';
  static final _headerRe = RegExp(r'^muzikmen\((.*)\)$');

  static String fileName() => 'playlists.txt';

  /// Розпарсити весь файл на список плейлистів (може містити 0+ блоків).
  static List<PlaylistEntry> parseAll(String content) {
    final lines = content.split(RegExp(r'\r?\n'));
    final result = <PlaylistEntry>[];
    String? curName;
    List<String> curPaths = [];

    void flush() {
      if (curName != null) result.add(PlaylistEntry(curName!, curPaths));
    }

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final headerMatch = _headerRe.firstMatch(line);
      if (headerMatch != null) {
        flush();
        curName = headerMatch.group(1) ?? '';
        curPaths = [];
        continue;
      }
      if (line == _footer) {
        flush();
        curName = null;
        curPaths = [];
        continue;
      }
      if (curName != null) curPaths.add(line);
    }
    flush(); // на випадок, якщо файл обірваний без фінального "кінець плейлисту"
    return result;
  }

  static String serializeAll(List<PlaylistEntry> entries) {
    final buf = StringBuffer();
    for (final e in entries) {
      buf.writeln('muzikmen(${e.name})');
      for (final p in e.paths) {
        buf.writeln(p);
      }
      buf.writeln(_footer);
    }
    return buf.toString();
  }

  static Future<List<PlaylistEntry>> readAll(File file) async {
    if (!await file.exists()) return [];
    try {
      final content = await file.readAsString();
      return parseAll(content);
    } catch (_) {
      return [];
    }
  }

  static Future<void> _writeAll(File file, List<PlaylistEntry> entries) async {
    await file.writeAsString(serializeAll(entries));
  }

  static Future<void> createPlaylist(File file, String name) async {
    final entries = await readAll(file);
    if (entries.any((e) => e.name == name)) return;
    entries.add(PlaylistEntry(name, []));
    await _writeAll(file, entries);
  }

  static Future<void> deletePlaylist(File file, String name) async {
    final entries = await readAll(file);
    entries.removeWhere((e) => e.name == name);
    await _writeAll(file, entries);
  }

  static Future<void> appendSong(File file, String playlistName, String songPath) async {
    final entries = await readAll(file);
    final idx = entries.indexWhere((e) => e.name == playlistName);
    if (idx == -1) return;
    if (entries[idx].paths.contains(songPath)) return;
    entries[idx] = PlaylistEntry(playlistName, [...entries[idx].paths, songPath]);
    await _writeAll(file, entries);
  }

  static Future<void> removeSong(File file, String playlistName, String songPath) async {
    final entries = await readAll(file);
    final idx = entries.indexWhere((e) => e.name == playlistName);
    if (idx == -1) return;
    entries[idx] = PlaylistEntry(
      playlistName,
      entries[idx].paths.where((p) => p != songPath).toList(),
    );
    await _writeAll(file, entries);
  }
}
