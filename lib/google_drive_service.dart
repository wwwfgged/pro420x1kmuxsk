import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'platform_utils.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'models/song.dart';
import 'download_core.dart';

/// OAuth 2.0 "Desktop app" флоу через локальний loopback-сервер.
/// Google офіційно рекомендує саме цей підхід для десктопних застосунків
/// (redirect_uri = http://127.0.0.1:PORT, без url_launcher — відкриваємо
/// системний браузер напряму через `cmd /c start`).
class GoogleDriveService {
  // TODO: якщо колись переносиш проєкт в інший Google Cloud проєкт —
  // онови ці два значення.
  static const _clientId = '192776637060-3b1vnq9h4uh8o7h1tuds0l0hccnbehua.apps.googleusercontent.com';
  static const _clientSecret = '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';
  static const _scope = 'https://www.googleapis.com/auth/drive.file';

  static const _tokenEndpoint = 'https://oauth2.googleapis.com/token';
  static const _authEndpoint = 'https://accounts.google.com/o/oauth2/v2/auth';

  static String? _accessToken;
  static String? _refreshToken;
  static DateTime? _accessTokenExpiry;
  static String? _userEmail;

  /// На Android кешується один раз при loadSaved() через path_provider
  /// (немає синхронного еквіваленту APPDATA).
  static String? _androidTokenDir;

  static String get _tokenFilePath {
    if (isMobilePlatform) {
      final dir = _androidTokenDir ?? '.';
      return '$dir/google_token.json';
    }
    final appData = Platform.environment['APPDATA'];
    final base = (appData != null && appData.isNotEmpty)
      ? appData
      : '${Platform.environment['USERPROFILE'] ?? 'C:/Users/user'}/AppData/Roaming';
    return '$base/muzik420/google_token.json';
  }

  static bool get isSignedIn => _refreshToken != null;
  static String? get userEmail => _userEmail;

  /// Завантажити збережений токен при старті застосунку (якщо є).
  static Future<void> loadSaved() async {
    if (isMobilePlatform) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        _androidTokenDir = dir.path;
      } catch (e) {
        print('[GoogleDrive] Android token dir error: $e');
      }
    }
    try {
      final file = File(_tokenFilePath);
      if (!await file.exists()) return;
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      _refreshToken = json['refresh_token'] as String?;
      _userEmail = json['email'] as String?;
      print('[GoogleDrive] Знайдено збережений вхід: $_userEmail');
    } catch (e) {
      print('[GoogleDrive] loadSaved error: $e');
    }
  }

  static Future<void> _saveToken() async {
    try {
      final file = File(_tokenFilePath);
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode({
        'refresh_token': _refreshToken,
        'email': _userEmail,
      }));
    } catch (e) {
      print('[GoogleDrive] _saveToken error: $e');
    }
  }

  /// Відкрити системний браузер для авторизації, підняти локальний сервер
  /// на 127.0.0.1, дочекатись редіректу з кодом, обміняти код на токени.
  static Future<bool> signIn() =>
      Platform.isWindows ? _signInWindows() : _signInAndroid();

  /// Android/мобільний вхід: Chrome Custom Tabs через flutter_web_auth_2 +
  /// зарезервована Google-схема, прив'язана напряму до client_id
  /// (com.googleusercontent.apps.<ID>) — саме так робить нативний
  /// Google Sign-In SDK, не треба нічого додатково реєструвати в
  /// Google Cloud Console.
  static String get _androidRedirectScheme {
    final id = _clientId.split('.apps.googleusercontent.com').first;
    return 'com.googleusercontent.apps.$id';
  }

  static Future<bool> _signInAndroid() async {
    try {
      final redirectUri = '$_androidRedirectScheme:/oauth2redirect';
      final authUrl = Uri.parse(_authEndpoint).replace(queryParameters: {
        'client_id': _clientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': '$_scope https://www.googleapis.com/auth/userinfo.email',
        'access_type': 'offline',
        'prompt': 'consent',
      });

      print('[GoogleDrive] Відкриваю Chrome Custom Tab для входу...');
      final result = await FlutterWebAuth2.authenticate(
        url: authUrl.toString(),
        callbackUrlScheme: _androidRedirectScheme,
      );

      final code = Uri.parse(result).queryParameters['code'];
      final error = Uri.parse(result).queryParameters['error'];
      if (code == null) {
        print('[GoogleDrive] Вхід скасовано: ${error ?? "невідома причина"}');
        return false;
      }

      return await _exchangeCodeForTokens(code, redirectUri);
    } catch (e) {
      print('[GoogleDrive] _signInAndroid error: $e');
      return false;
    }
  }

  /// Windows вхід: системний браузер + локальний loopback-сервер на
  /// 127.0.0.1, що очікує редірект з кодом.
  static Future<bool> _signInWindows() async {
    HttpServer? server;
    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;
      final redirectUri = 'http://127.0.0.1:$port';

      final authUrl = Uri.parse(_authEndpoint).replace(queryParameters: {
        'client_id': _clientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': '$_scope https://www.googleapis.com/auth/userinfo.email',
        'access_type': 'offline',
        'prompt': 'consent',
      });

      print('[GoogleDrive] Відкриваю браузер для входу...');
      // rundll32 url.dll,FileProtocolHandler — це те саме, що Windows сам
      // використовує "під капотом" для відкриття URL у стандартному браузері.
      // explorer.exe виявився ненадійним (іноді просто відкриває Провідник),
      // а cmd/start ламав URL через "&". Це найнадійніший варіант без
      // сторонніх пакетів (url_launcher).
      await Process.start('rundll32.exe', ['url.dll,FileProtocolHandler', authUrl.toString()]);

      final codeCompleter = Completer<String?>();
      server.listen((HttpRequest request) async {
        final code = request.uri.queryParameters['code'];
        final error = request.uri.queryParameters['error'];

        request.response.headers.contentType = ContentType.html;
        if (code != null) {
          request.response.write('''
            <html><body style="font-family:sans-serif;background:#0A0A0F;color:#fff;
              display:flex;align-items:center;justify-content:center;height:100vh;margin:0;">
              <div style="text-align:center;">
                <h2 style="color:#4CAF50;">✅ Вхід виконано!</h2>
                <p>Можеш закрити цю вкладку і повернутись у muzik420_new.</p>
              </div>
            </body></html>''');
        } else {
          request.response.write('''
            <html><body style="font-family:sans-serif;background:#0A0A0F;color:#fff;
              display:flex;align-items:center;justify-content:center;height:100vh;margin:0;">
              <div style="text-align:center;">
                <h2 style="color:#F44336;">❌ Помилка входу</h2>
                <p>${error ?? "Невідома помилка"}</p>
              </div>
            </body></html>''');
        }
        await request.response.close();
        if (!codeCompleter.isCompleted) codeCompleter.complete(code);
      });

      final code = await codeCompleter.future.timeout(const Duration(minutes: 3),
        onTimeout: () => null);
      await server.close(force: true);
      server = null;

      if (code == null) {
        print('[GoogleDrive] Вхід скасовано або час вийшов');
        return false;
      }

      return await _exchangeCodeForTokens(code, redirectUri);
    } catch (e) {
      print('[GoogleDrive] signIn error: $e');
      return false;
    } finally {
      try { await server?.close(force: true); } catch (_) {}
    }
  }

  /// Спільний для обох платформ обмін authorization code на токени +
  /// отримання email користувача.
  static Future<bool> _exchangeCodeForTokens(String code, String redirectUri) async {
    final tokenResp = await http.post(Uri.parse(_tokenEndpoint), body: {
      'code': code,
      'client_id': _clientId,
      'client_secret': _clientSecret,
      'redirect_uri': redirectUri,
      'grant_type': 'authorization_code',
    });

    if (tokenResp.statusCode != 200) {
      print('[GoogleDrive] Token exchange error: ${tokenResp.body}');
      return false;
    }

    final tokenJson = jsonDecode(tokenResp.body) as Map<String, dynamic>;
    _accessToken = tokenJson['access_token'] as String?;
    _refreshToken = tokenJson['refresh_token'] as String?;
    final expiresIn = tokenJson['expires_in'] as int? ?? 3600;
    _accessTokenExpiry = DateTime.now().add(Duration(seconds: expiresIn - 30));

    try {
      final userResp = await http.get(
        Uri.parse('https://www.googleapis.com/oauth2/v2/userinfo'),
        headers: {'Authorization': 'Bearer $_accessToken'});
      if (userResp.statusCode == 200) {
        final u = jsonDecode(userResp.body) as Map<String, dynamic>;
        _userEmail = u['email'] as String?;
      }
    } catch (_) {}

    await _saveToken();
    print('[GoogleDrive] ✅ Вхід успішний: $_userEmail');
    return true;
  }

  static Future<void> signOut() async {
    _accessToken = null;
    _refreshToken = null;
    _accessTokenExpiry = null;
    _userEmail = null;
    try {
      final file = File(_tokenFilePath);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  /// Отримати дійсний access_token, оновивши його за потреби через
  /// refresh_token. Використовується всіма подальшими Drive API запитами.
  static Future<String?> _getValidAccessToken() async {
    if (_refreshToken == null) return null;
    if (_accessToken != null && _accessTokenExpiry != null &&
        DateTime.now().isBefore(_accessTokenExpiry!)) {
      return _accessToken;
    }
    try {
      final resp = await http.post(Uri.parse(_tokenEndpoint), body: {
        'client_id': _clientId,
        'client_secret': _clientSecret,
        'refresh_token': _refreshToken,
        'grant_type': 'refresh_token',
      });
      if (resp.statusCode != 200) {
        print('[GoogleDrive] refresh error: ${resp.body}');
        return null;
      }
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      _accessToken = json['access_token'] as String?;
      final expiresIn = json['expires_in'] as int? ?? 3600;
      _accessTokenExpiry = DateTime.now().add(Duration(seconds: expiresIn - 30));
      return _accessToken;
    } catch (e) {
      print('[GoogleDrive] refresh exception: $e');
      return null;
    }
  }

  /// Публічний метод для швидкої перевірки з'єднання (Settings-екран
  /// викликає це одразу після signIn(), щоб підтвердити токен реально working).
  static Future<bool> testConnection() async {
    final token = await _getValidAccessToken();
    if (token == null) return false;
    try {
      final resp = await http.get(
        Uri.parse('https://www.googleapis.com/drive/v3/about?fields=user'),
        headers: {'Authorization': 'Bearer $token'});
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ============================================================
  //  DRIVE API — низькорівневі хелпери
  // ============================================================

  static const _driveBase = 'https://www.googleapis.com/drive/v3';
  static const _driveUpload = 'https://www.googleapis.com/upload/drive/v3';
  static const _backupFolderName = 'muzik420_backup';

  static Future<Map<String, String>> _authHeaders() async {
    final token = await _getValidAccessToken();
    if (token == null) throw Exception('Немає дійсного токену. Увійди в Google акаунт ще раз.');
    return {'Authorization': 'Bearer $token'};
  }

  /// Знайти папку за назвою (в корені Drive, серед файлів застосунку —
  /// scope drive.file бачить тільки те, що сам застосунок створив).
  /// Якщо не знайдено — створити.
  static Future<String> _findOrCreateFolder(String name, {String? parentId}) async {
    final headers = await _authHeaders();
    final parentQ = parentId != null ? " and '$parentId' in parents" : '';
    final q = Uri.encodeQueryComponent(
      "name = '$name' and mimeType = 'application/vnd.google-apps.folder' and trashed = false$parentQ");
    final resp = await http.get(
      Uri.parse('$_driveBase/files?q=$q&fields=files(id,name)'), headers: headers);
    if (resp.statusCode == 200) {
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final files = json['files'] as List<dynamic>;
      if (files.isNotEmpty) return files.first['id'] as String;
    }
    // Не знайдено — створюємо
    final createResp = await http.post(Uri.parse('$_driveBase/files'),
      headers: {...headers, 'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'mimeType': 'application/vnd.google-apps.folder',
        if (parentId != null) 'parents': [parentId],
      }));
    if (createResp.statusCode != 200 && createResp.statusCode != 201) {
      print('[GoogleDrive] _findOrCreateFolder ПОМИЛКА (${createResp.statusCode}): ${createResp.body}');
      throw Exception('Не вдалось створити папку "$name" на Drive (${createResp.statusCode}): ${createResp.body}');
    }
    final createdJson = jsonDecode(createResp.body) as Map<String, dynamic>;
    final id = createdJson['id'] as String?;
    if (id == null) {
      throw Exception('Google Drive не повернув id папки: ${createResp.body}');
    }
    return id;
  }

  /// Знайти файл за назвою всередині папки. Повертає id або null.
  static Future<String?> _findFileInFolder(String name, String folderId) async {
    final headers = await _authHeaders();
    final q = Uri.encodeQueryComponent(
      "name = '$name' and '$folderId' in parents and trashed = false");
    final resp = await http.get(
      Uri.parse('$_driveBase/files?q=$q&fields=files(id,name)'), headers: headers);
    if (resp.statusCode != 200) return null;
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final files = json['files'] as List<dynamic>;
    return files.isNotEmpty ? files.first['id'] as String : null;
  }

  /// Завантажити файл (байти) у папку. Якщо файл з такою назвою вже є —
  /// перезаписує його вміст замість створення дубліката.
  static Future<String> _uploadBytes(List<int> bytes, String name, String folderId, String mimeType) async {
    final headers = await _authHeaders();
    final existingId = await _findFileInFolder(name, folderId);

    final metadata = jsonEncode(existingId == null
      ? {'name': name, 'parents': [folderId]}
      : {'name': name});

    final boundary = 'muzik420_boundary_${DateTime.now().millisecondsSinceEpoch}';
    final body = <int>[];
    void addStr(String s) => body.addAll(utf8.encode(s));

    addStr('--$boundary\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n$metadata\r\n');
    addStr('--$boundary\r\nContent-Type: $mimeType\r\n\r\n');
    body.addAll(bytes);
    addStr('\r\n--$boundary--');

    final uri = existingId == null
      ? Uri.parse('$_driveUpload/files?uploadType=multipart')
      : Uri.parse('$_driveUpload/files/$existingId?uploadType=multipart');

    final req = http.Request(existingId == null ? 'POST' : 'PATCH', uri);
    req.headers.addAll({...headers, 'Content-Type': 'multipart/related; boundary=$boundary'});
    req.bodyBytes = body;

    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw Exception('Upload failed (${resp.statusCode}): ${resp.body}');
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    return json['id'] as String;
  }

  static Future<String> _uploadFile(String localPath, String name, String folderId) async {
    final bytes = await File(localPath).readAsBytes();
    final ext = localPath.split('.').last.toLowerCase();
    final mime = {
      'mp3': 'audio/mpeg', 'm4a': 'audio/mp4', 'aac': 'audio/aac',
      'mp4': 'video/mp4', 'webm': 'video/webm', 'ogg': 'audio/ogg',
      'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png', 'webp': 'image/webp',
    }[ext] ?? 'application/octet-stream';
    return _uploadBytes(bytes, name, folderId, mime);
  }

  static Future<List<int>> _downloadBytes(String fileId) async {
    final headers = await _authHeaders();
    final resp = await http.get(Uri.parse('$_driveBase/files/$fileId?alt=media'), headers: headers);
    if (resp.statusCode != 200) throw Exception('Download failed (${resp.statusCode})');
    return resp.bodyBytes;
  }

  // ============================================================
  //  БЕКАП
  // ============================================================
  //
  // Формат манідесту (muzik420_backup.txt всередині папки muzik420_backup):
  //
  //   muzikbackup(v1)
  //   [SONG]
  //   title=Назва пісні
  //   source=https://youtube.com/watch?v=xxx  (або NONE)
  //   drive_audio=<file id>                    (тільки якщо source=NONE)
  //   drive_cover=<file id>                     (тільки якщо є і source=NONE)
  //   [/SONG]
  //   ...
  //   [PLAYLIST]
  //   name=Назва плейлиста
  //   songs=Назва1|Назва2|Назва3
  //   [/PLAYLIST]
  //   кінець бекапу
  //
  // Пісні з відомим джерелом (source) НЕ заливаються файлом — при
  // відновленні вони просто перекачуються заново тим самим посиланням.
  // Обкладинка для таких пісень теж не заливається окремо (прийде разом
  // з піснею при відновленні). Файлом заливаються лише пісні БЕЗ джерела.

  static const _manifestName = 'muzik420_backup.txt';

  static Future<bool> backup({
    required List<Song> songs,
    required List<MusicPlaylist> playlists,
    required Map<String, String> sources, // filePath -> source URL
    void Function(String status, double progress)? onProgress,
  }) async {
    try {
      onProgress?.call('Створюю папку на Drive...', 0.02);
      final folderId = await _findOrCreateFolder(_backupFolderName);

      final buf = StringBuffer();
      buf.writeln('muzikbackup(v1)');

      // titleUsed рахує повтори назв, щоб плейлисти коректно посилались
      // навіть якщо є пісні з однаковою назвою.
      final total = songs.length;
      var done = 0;

      for (final song in songs) {
        done++;
        final source = sources[song.filePath];
        buf.writeln('[SONG]');
        buf.writeln('title=${song.title}');

        if (source != null) {
          buf.writeln('source=$source');
          onProgress?.call('${song.title} (посилання, без заливки)', 0.05 + (done / total) * 0.7);
        } else {
          onProgress?.call('Заливаю: ${song.title}', 0.05 + (done / total) * 0.7);
          buf.writeln('source=NONE');
          try {
            final audioName = basenameOf(song.filePath);
            final audioId = await _uploadFile(song.filePath, audioName, folderId);
            buf.writeln('drive_audio=$audioId');
          } catch (e) {
            print('[GoogleDrive] Помилка заливки ${song.title}: $e');
            buf.writeln('drive_audio=NONE');
          }
          if (song.coverPath != null) {
            try {
              final coverName = basenameOf(song.coverPath!);
              final coverId = await _uploadFile(song.coverPath!, coverName, folderId);
              buf.writeln('drive_cover=$coverId');
            } catch (_) {
              buf.writeln('drive_cover=NONE');
            }
          }
        }
        buf.writeln('[/SONG]');
      }

      for (final pl in playlists) {
        buf.writeln('[PLAYLIST]');
        buf.writeln('name=${pl.name}');
        buf.writeln('songs=${pl.songs.map((s) => s.title).join('|')}');
        buf.writeln('[/PLAYLIST]');
      }

      buf.writeln('кінець бекапу');

      onProgress?.call('Заливаю маніфест...', 0.90);
      await _uploadBytes(utf8.encode(buf.toString()), _manifestName, folderId, 'text/plain');

      onProgress?.call('✅ Бекап завершено!', 1.0);
      return true;
    } catch (e) {
      print('[GoogleDrive] backup error: $e');
      onProgress?.call('❌ Помилка бекапу: $e', 0);
      return false;
    }
  }

  // ============================================================
  //  ВІДНОВЛЕННЯ
  // ============================================================

  static Future<bool> restore({
    void Function(String status, double progress)? onProgress,
  }) async {
    try {
      onProgress?.call('Шукаю бекап на Drive...', 0.02);
      final folderId = await _findOrCreateFolder(_backupFolderName);
      final manifestId = await _findFileInFolder(_manifestName, folderId);
      if (manifestId == null) {
        onProgress?.call('❌ Бекап не знайдено на Drive', 0);
        return false;
      }

      final manifestBytes = await _downloadBytes(manifestId);
      final manifestText = utf8.decode(manifestBytes);
      final lines = manifestText.split(RegExp(r'\r?\n'));

      final base = await getMusicDir();
      final sourcesFile = File('${base.path}/${SourceStore.fileNameOf()}');

      // Парсимо маніфест
      final songBlocks = <Map<String, String>>[];
      final playlistBlocks = <Map<String, String>>[];
      Map<String, String>? cur;
      String? mode;

      for (final rawLine in lines) {
        final line = rawLine.trim();
        if (line == '[SONG]') { cur = {}; mode = 'song'; continue; }
        if (line == '[/SONG]') { if (cur != null) songBlocks.add(cur); cur = null; mode = null; continue; }
        if (line == '[PLAYLIST]') { cur = {}; mode = 'playlist'; continue; }
        if (line == '[/PLAYLIST]') { if (cur != null) playlistBlocks.add(cur); cur = null; mode = null; continue; }
        if (cur != null && mode != null) {
          final idx = line.indexOf('=');
          if (idx > 0) cur[line.substring(0, idx)] = line.substring(idx + 1);
        }
      }

      final total = songBlocks.length;
      var done = 0;
      // title -> реальний локальний шлях після відновлення (для плейлистів)
      final titleToPath = <String, String>{};

      for (final s in songBlocks) {
        done++;
        final title = s['title'] ?? 'Без назви';
        final source = s['source'];
        onProgress?.call('[$done/$total] $title', 0.05 + (done / total) * 0.8);

        try {
          if (source != null && source != 'NONE') {
            final path = await downloadFromUrl(source);
            if (path != null) titleToPath[title] = path;
          } else {
            final audioId = s['drive_audio'];
            if (audioId == null || audioId == 'NONE') continue;
            final coverId = s['drive_cover'];
            final bytes = await _downloadBytes(audioId);

            if (coverId != null && coverId != 'NONE') {
              final safeName = title.replaceAll(RegExp(r'[<>:"/\\|?*#]'), '').trim();
              final songDir = Directory('${base.path}/$safeName');
              if (!await songDir.exists()) await songDir.create(recursive: true);
              final audioPath = '${songDir.path}/audio.mp3';
              await File(audioPath).writeAsBytes(bytes);
              try {
                final coverBytes = await _downloadBytes(coverId);
                await File('${songDir.path}/cover.jpg').writeAsBytes(coverBytes);
              } catch (_) {}
              titleToPath[title] = audioPath;
            } else {
              final safeName = title.replaceAll(RegExp(r'[<>:"/\\|?*#]'), '').trim();
              final audioPath = '${base.path}/$safeName.mp3';
              await File(audioPath).writeAsBytes(bytes);
              titleToPath[title] = audioPath;
            }
          }
        } catch (e) {
          print('[GoogleDrive] Помилка відновлення "$title": $e');
        }
      }

      // Відновлюємо джерела для перекачаних пісень
      for (final s in songBlocks) {
        final title = s['title'];
        final source = s['source'];
        final path = titleToPath[title];
        if (title != null && source != null && source != 'NONE' && path != null) {
          try { await SourceStore.set(sourcesFile, path, source); } catch (_) {}
        }
      }

      // Відновлюємо плейлисти
      onProgress?.call('Відновлюю плейлисти...', 0.92);
      final playlistsFile = File('${base.path}/${PlaylistStore.fileName()}');
      for (final p in playlistBlocks) {
        final name = p['name'];
        if (name == null) continue;
        final songTitles = (p['songs'] ?? '').split('|').where((s) => s.isNotEmpty);
        await PlaylistStore.createPlaylist(playlistsFile, name);
        for (final t in songTitles) {
          final path = titleToPath[t];
          if (path != null) {
            await PlaylistStore.appendSong(playlistsFile, name, path);
          }
        }
      }

      onProgress?.call('✅ Відновлення завершено!', 1.0);
      return true;
    } catch (e) {
      print('[GoogleDrive] restore error: $e');
      onProgress?.call('❌ Помилка відновлення: $e', 0);
      return false;
    }
  }

  // ============================================================
  //  ВИДАЛЕННЯ БЕКАПУ
  // ============================================================

  /// Перевірити, чи існує бекап на Drive, і скільки файлів у ньому
  /// (для показу перед видаленням).
  static Future<({bool exists, int fileCount})> getBackupInfo() async {
    try {
      final headers = await _authHeaders();
      final resp = await http.get(
        Uri.parse("$_driveBase/files?q=name = '$_backupFolderName' and "
          "mimeType = 'application/vnd.google-apps.folder' and trashed = false&fields=files(id)"),
        headers: headers);
      if (resp.statusCode != 200) return (exists: false, fileCount: 0);
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final folders = json['files'] as List<dynamic>;
      if (folders.isEmpty) return (exists: false, fileCount: 0);
      final folderId = folders.first['id'] as String;

      final childrenResp = await http.get(
        Uri.parse("$_driveBase/files?q='$folderId' in parents and trashed = false&fields=files(id)"),
        headers: headers);
      if (childrenResp.statusCode != 200) return (exists: true, fileCount: 0);
      final childrenJson = jsonDecode(childrenResp.body) as Map<String, dynamic>;
      final children = childrenJson['files'] as List<dynamic>;
      return (exists: true, fileCount: children.length);
    } catch (e) {
      print('[GoogleDrive] getBackupInfo error: $e');
      return (exists: false, fileCount: 0);
    }
  }

  /// Видалити весь бекап (папку зі всім вмістом) на Drive.
  static Future<bool> deleteBackup() async {
    try {
      final headers = await _authHeaders();
      final resp = await http.get(
        Uri.parse("$_driveBase/files?q=name = '$_backupFolderName' and "
          "mimeType = 'application/vnd.google-apps.folder' and trashed = false&fields=files(id)"),
        headers: headers);
      if (resp.statusCode != 200) return false;
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final folders = json['files'] as List<dynamic>;
      if (folders.isEmpty) return true; // нема чого видаляти

      final folderId = folders.first['id'] as String;
      final delResp = await http.delete(
        Uri.parse('$_driveBase/files/$folderId'), headers: headers);
      // Google повертає 204 No Content при успішному видаленні
      return delResp.statusCode == 204 || delResp.statusCode == 200;
    } catch (e) {
      print('[GoogleDrive] deleteBackup error: $e');
      return false;
    }
  }
}
