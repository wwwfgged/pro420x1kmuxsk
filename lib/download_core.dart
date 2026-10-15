import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'models/song.dart';

/// Кешуємо обчислену теку один раз за сесію — на Android
/// getExternalStorageDirectory() асинхронний і не варто дьоргати
/// платформний канал на кожен виклик.
Directory? _cachedMusicDir;

Future<Directory> getMusicDir() async {
  if (_cachedMusicDir != null) return _cachedMusicDir!;

  Directory dir;
  if (Platform.isAndroid) {
    // App-specific зовнішнє сховище:
    // /storage/emulated/0/Android/data/<package>/files/pro420x1kmuxsk
    // Не потребує додаткових дозволів на керування всім сховищем.
    final base = await getExternalStorageDirectory();
    if (base == null) {
      // Дуже рідкісний фолбек, якщо зовнішнє сховище недоступне.
      final docs = await getApplicationDocumentsDirectory();
      dir = Directory('${docs.path}/pro420x1kmuxsk');
    } else {
      dir = Directory('${base.path}/pro420x1kmuxsk');
    }
  } else if (Platform.isIOS) {
    // iOS: тільки пісочниця застосунку. Documents видно в застосунку
    // "Файли" (при UIFileSharingEnabled у Info.plist).
    final docs = await getApplicationDocumentsDirectory();
    dir = Directory('${docs.path}/pro420x1kmuxsk');
  } else if (Platform.isWindows) {
    final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '.';
    dir = Directory('$home/Music/muzik420');
  } else {
    // Linux/macOS фолбек (для майбутнього).
    final home = Platform.environment['HOME'] ?? '.';
    dir = Directory('$home/Music/muzik420');
  }

  if (!await dir.exists()) await dir.create(recursive: true);
  _cachedMusicDir = dir;
  return dir;
}

typedef ProgressCb = void Function(String status, double progress);

/// Завантажити відео/аудіо з YouTube за посиланням. Повертає локальний
/// шлях до збереженого файлу, або null при помилці.
/// Використовується і UI-завантажувачем, і відновленням з Google Drive.
Future<String?> downloadYoutubeVideo(String url, {ProgressCb? onProgress}) async {
  final yt = YoutubeExplode();
  try {
    final base = await getMusicDir();
    onProgress?.call('Підключаюсь...', 0.05);
    final video = await yt.videos.get(url);
    var safe = video.title.replaceAll(RegExp(r'[<>:"/\\|?*#]'), '').trim();
    // Ліміт імені файлу в iOS/Android — 255 БАЙТ, а кирилиця = 2 байти на
    // символ: довга назва з YouTube просто не створювала файл.
    if (safe.length > 80) {
      safe = safe.substring(0, 80);
      final last = safe.codeUnitAt(safe.length - 1);
      if (last >= 0xD800 && last <= 0xDBFF) safe = safe.substring(0, safe.length - 1); // не різати емодзі навпіл
      safe = safe.trim();
    }
    if (safe.isEmpty) safe = 'track_${DateTime.now().millisecondsSinceEpoch}';
    onProgress?.call('Знайдено: ${video.title}', 0.15);

    Directory saveDir = base;
    try {
      final t = await http.get(Uri.parse(video.thumbnails.highResUrl)).timeout(const Duration(seconds: 8));
      if (t.statusCode == 200) {
        final songDir = Directory('${base.path}/$safe');
        if (!await songDir.exists()) await songDir.create(recursive: true);
        await File('${songDir.path}/cover.jpg').writeAsBytes(t.bodyBytes);
        saveDir = songDir;
      }
    } catch (_) {}

    onProgress?.call('Отримую стріми...', 0.25);
    StreamManifest manifest;
    try {
      manifest = await yt.videos.streams.getManifest(video.id,
        ytClients: [YoutubeApiClient.androidVr, YoutubeApiClient.safari, YoutubeApiClient.ios]);
    } catch (_) { manifest = await yt.videos.streams.getManifest(video.id); }

    StreamInfo? info;
    String ext = 'mp4';
    if (manifest.muxed.isNotEmpty) {
      info = manifest.muxed.sortByVideoQuality().first;
    } else if (manifest.audioOnly.isNotEmpty) {
      // Тільки аудіо: віддаємо перевагу AAC у mp4-контейнері (.m4a) —
      // його відтворює і iOS (AVPlayer). Раніше тут міг братись webm/opus
      // і зберігатись під іменем .mp4 — на iPhone такий файл не грався.
      final mp4Audio = manifest.audioOnly.where((s) => s.container == StreamContainer.mp4).toList();
      if (mp4Audio.isNotEmpty) {
        info = mp4Audio.withHighestBitrate();
        ext = 'm4a';
      } else {
        info = manifest.audioOnly.withHighestBitrate();
        ext = 'webm';
      }
    } else {
      onProgress?.call('❌ Немає стрімів', 0);
      return null;
    }

    final filePath = '${saveDir.path}/$safe.$ext';
    final total = info.size.totalBytes;
    var recv = 0;
    final sink = File(filePath).openWrite();
    await for (final chunk in yt.videos.streams.get(info)) {
      sink.add(chunk); recv += chunk.length;
      final p = total > 0 ? 0.30 + (recv / total) * 0.65 : (recv / (30*1024*1024)).clamp(0.30, 0.95);
      onProgress?.call('Завантажую... ${(recv/1024/1024).toStringAsFixed(1)} MB', p);
    }
    await sink.flush(); await sink.close();

    final size = await File(filePath).length();
    if (size < 10000) {
      try { await File(filePath).delete(); } catch (_) {}
      onProgress?.call('❌ Порожній файл', 0);
      return null;
    }

    try {
      final sourcesFile = File('${base.path}/${SourceStore.fileNameOf()}');
      await SourceStore.set(sourcesFile, filePath, 'https://youtube.com/watch?v=${video.id.value}');
    } catch (_) {}

    onProgress?.call('✅ Завантажено!', 1.0);
    return filePath;
  } catch (e) {
    onProgress?.call('❌ Помилка: $e', 0);
    return null;
  } finally {
    yt.close();
  }
}

/// Завантажити відео/музику з TikTok за посиланням. Повертає локальний
/// шлях до збереженого файлу, або null при помилці.
Future<String?> downloadTikTokVideo(String url, {ProgressCb? onProgress}) async {
  try {
    final base = await getMusicDir();
    onProgress?.call('Підключаюсь до TikTok...', 0.05);
    final r = await http.post(Uri.parse('https://www.tikwm.com/api/'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded', 'User-Agent': 'Mozilla/5.0 (Linux; Android 13)'},
      body: 'url=${Uri.encodeComponent(url)}&count=12&cursor=0&web=1&hd=1',
    ).timeout(const Duration(seconds: 20));
    if (r.statusCode != 200) throw Exception('tikwm статус ${r.statusCode}');
    final d = jsonDecode(r.body);
    if (d['code'] != 0) throw Exception('tikwm: ${d['msg']}');
    final data = d['data'] as Map<String, dynamic>;
    final title = (data['title'] as String? ?? 'TikTok').replaceAll(RegExp(r'[<>:"/\\|?*#]'), '').trim();
    final safe = title.length > 50 ? title.substring(0, 50) : title;
    final dlUrl = data['music_info']?['play'] as String? ?? data['wmplay'] as String? ?? data['play'] as String?;
    final cover = data['cover'] as String?;

    Directory saveDir = base;
    if (cover != null) {
      try {
        final t = await http.get(Uri.parse(cover)).timeout(const Duration(seconds: 8));
        if (t.statusCode == 200) {
          final songDir = Directory('${base.path}/$safe');
          if (!await songDir.exists()) await songDir.create(recursive: true);
          await File('${songDir.path}/cover.jpg').writeAsBytes(t.bodyBytes);
          saveDir = songDir;
        }
      } catch (_) {}
    }
    if (dlUrl == null) throw Exception('Немає посилання');
    onProgress?.call('Знайдено: $title', 0.30);
    final ext = dlUrl.contains('.mp3') ? 'mp3' : 'mp4';
    final req = http.Request('GET', Uri.parse(dlUrl));
    req.headers['User-Agent'] = 'Mozilla/5.0 (Linux; Android 13)';
    req.headers['Referer'] = 'https://www.tiktok.com/';
    final resp = await req.send().timeout(const Duration(minutes: 10));
    final totalB = resp.contentLength ?? 0;
    var recv = 0;
    final filePath = '${saveDir.path}/$safe.$ext';
    final sink = File(filePath).openWrite();
    await for (final chunk in resp.stream) {
      sink.add(chunk); recv += chunk.length;
      final p = totalB > 0 ? 0.30 + (recv / totalB) * 0.70 : (recv / (20*1024*1024)).clamp(0.30, 0.95);
      onProgress?.call('Завантажую... ${(recv/1024/1024).toStringAsFixed(1)} MB', p);
    }
    await sink.flush(); await sink.close();
    final size = await File(filePath).length();
    if (size < 5000) throw Exception('Файл порожній');

    try {
      final sourcesFile = File('${base.path}/${SourceStore.fileNameOf()}');
      await SourceStore.set(sourcesFile, filePath, url);
    } catch (_) {}

    onProgress?.call('✅ Завантажено!', 1.0);
    return filePath;
  } catch (e) {
    onProgress?.call('❌ Помилка: $e', 0);
    return null;
  }
}

/// Завантажити за посиланням, автоматично визначивши YouTube чи TikTok.
Future<String?> downloadFromUrl(String url, {ProgressCb? onProgress}) async {
  final lower = url.toLowerCase();
  if (lower.contains('tiktok.com')) {
    return downloadTikTokVideo(url, onProgress: onProgress);
  }
  return downloadYoutubeVideo(url, onProgress: onProgress);
}
