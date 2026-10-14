import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'player.dart';
import 'widgets/mobile_player.dart';
import 'widgets/ui_animations.dart';
import 'screens/onboarding_screen.dart';
import 'theme/app_theme.dart';
import 'win_theme.dart';
import 'google_drive_service.dart';
import 'download_core.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

// Models
import 'models/song.dart';

// Screens
import 'screens/songs_tab.dart';
import 'screens/download_tab.dart';
import 'screens/doom_game.dart';

import 'config/app_config.dart';
import 'screens/songs_tab_desktop.dart';
// Widgets
import 'widgets/mini_player.dart';
import 'widgets/common.dart';
import 'widgets/media_overlay.dart';
export 'screens/songs_tab_desktop.dart' show AeroPlayerBar, AeroBottomNav, SettingsScreen;

// getMusicDir() тепер визначена єдиний раз у download_core.dart (імпортовано вище)

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // window_manager (рамка/розмір/мінімізація вікна) стосується лише
  // десктопу — на Android/iOS цей пакет не має реалізації і викликати
  // його там не потрібно. Це швидкі локальні виклики (без диску/мережі),
  // тому не впливають на час запуску Android.
  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true); // перехоплюємо закриття -> onWindowClose()
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setTitleBarStyle(TitleBarStyle.normal);
    await windowManager.setMinimumSize(const Size(400, 300));
    await windowManager.setResizable(true);
    await windowManager.setBackgroundColor(Colors.transparent);
    await windowManager.setSize(const Size(800, 600));
    await windowManager.center();
    await windowManager.show();
    await windowManager.focus();
    WinTheme.forceDarkTitleBar();
  }

  // ВАЖЛИВО: AppConfig.load()/GoogleDriveService.loadSaved() свідомо НЕ
  // await-яться тут. Flutter не малює жодного кадру, поки не викликано
  // runApp() — тобто весь час цих await'ів на екрані висів нативний
  // БІЛИЙ splash (саме це й було причиною ~10с затримки на Android:
  // перші виклики платформних плагінів типу path_provider в debug-збірці
  // можуть зайняти секунди). Тепер runApp() стартує миттєво, і замість
  // білого екрану користувач одразу бачить наш власний темний лоадер
  // (Pro420App сам чекає _bootFuture і показує спінер).
  runApp(Pro420App(args: args));
}

class Pro420App extends StatelessWidget {
  final List<String> args;
  const Pro420App({super.key, this.args = const []});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'pro420x1kmuxsk',
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark().copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: ColorScheme.dark(primary: AppTheme.primary, secondary: AppTheme.secondary),
      // Явно прибираємо будь-яке декорування тексту за замовчуванням —
      // на деяких Windows-системах з увімкненою перевіркою орфографії
      // з'являлись жовті підкреслення під текстом.
      textTheme: ThemeData.dark().textTheme.apply(decorationColor: Colors.transparent),
    ),
    builder: (context, child) => DefaultTextStyle.merge(
      style: const TextStyle(decoration: TextDecoration.none),
      child: child ?? const SizedBox.shrink()),
    home: MainScreen(args: args));
}

/// Темний лоадер замість нативного білого splash — показується миттєво
/// (перший кадр Flutter), поки AppConfig/GoogleDriveService вантажаться
/// у фоні. Раніше ці await'и блокували виклик runApp() — саме це й
/// давало довгий білий екран на Android. Колір фону (0xFF0A0A0F) навмисно
/// співпадає з launch_background.xml нативного splash — перехід між
/// ними візуально непомітний.
class _BootSplash extends StatefulWidget {
  const _BootSplash();
  @override
  State<_BootSplash> createState() => _BootSplashState();
}

class _BootSplashState extends State<_BootSplash> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFF0A0A0F),
    child: Center(child: AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        // Пульсація (0.85 → 1.0 → 0.85) + повільне обертання кільця навколо.
        final pulse = 0.85 + 0.15 * (0.5 + 0.5 * (1 - (2 * _ctrl.value - 1).abs()));
        return Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 88, height: 88, child: Stack(alignment: Alignment.center, children: [
            Transform.rotate(angle: _ctrl.value * 6.28318, child: Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(colors: const [
                  Color(0x007C5CFC), Color(0xFF7C5CFC), Color(0xFFFC5C9C), Color(0x007C5CFC)]))),
            ),
            Container(width: 78, height: 78,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF0A0A0F))),
            Transform.scale(scale: pulse, child: const Icon(
              Icons.music_note_rounded, size: 44, color: Color(0xFF7C5CFC))),
          ])),
          const SizedBox(height: 20),
          Opacity(opacity: 0.5, child: const Text('pro420x1kmuxsk',
            style: TextStyle(color: Colors.white, fontSize: 13, letterSpacing: 1))),
        ]);
      })));
}

class MainScreen extends StatefulWidget {
  final List<String> args;
  const MainScreen({super.key, this.args = const []});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver, WindowListener {
  int _tab = 0;
  // Windows native player
  List<Song> _songs = [];
  List<MusicPlaylist> _playlists = [];
  Song? _currentSong;
  List<Song> _queue = [];
  int? _currentIndex;
  bool _editMode = false;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isMinimized = false;
  int _versionTapCount = 0;
  Timer? _versionTapTimer;

  // Поки true — показуємо _BootSplash замість основного UI.
  bool _booted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (Platform.isWindows) windowManager.addListener(this);

    // Обидва завантаження йдуть паралельно (а не послідовно, як було
    // раніше) — це вдвічі швидше, і головне: більше не блокує runApp().
    Future.wait([
      AppConfig.load(widget.args),
      GoogleDriveService.loadSaved(),
    ]).then((_) {
      if (!mounted) return;
      setState(() => _booted = true);
    });

    _loadAll();
    Player.positionStream.listen((p) { if (mounted) setState(() => _position = p); });
    Player.durationStream.listen((d) { if (mounted && d != null) setState(() => _duration = d); });
    Player.playingStream.listen((p) { if (mounted) setState(() => _isPlaying = p); });
    Player.completionStream.listen((_) => _playNext());
  }

  @override
  void onWindowMinimize() async {
    if (!_isMinimized) await _setMiniMode(true);
  }

  bool _closing = false;

  @override
  void onWindowClose() async {
    if (_closing) return;
    _closing = true;
    // Ховаємо вікно ОДРАЗУ — так користувач бачить миттєве закриття,
    // а не "не відповідає" на пару сотень мс, поки триває async cleanup
    // нижче. windowManager.destroy() викликається в кінці однаково.
    try { await windowManager.hide(); } catch (_) {}
    try {
      await Player.stop();
      Player.dispose();
      // Даємо PowerShell-процесу час коректно завершитись (EXIT + kill
      // всередині dispose() виконуються з невеликою затримкою).
      await Future.delayed(const Duration(milliseconds: 400));
    } catch (_) {
    } finally {
      await windowManager.destroy();
    }
  }

  @override
  void onWindowRestore() async {
    if (_isMinimized) await _setMiniMode(false);
  }

  Future<void> _setMiniMode(bool mini) async {
    // Плаваюче міні-вікно (always-on-top, фіксований розмір) — суто
    // десктопна фіча через window_manager. На Android аналога немає.
    if (!Platform.isWindows) return;
    if (mini == _isMinimized) return;
    setState(() => _isMinimized = mini);
    if (mini) {
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
      await windowManager.setBackgroundColor(Colors.transparent);
      await windowManager.setMinimumSize(const Size(320, 120));
      await windowManager.setMaximumSize(const Size(320, 120));
      await windowManager.setResizable(false);
      await windowManager.setSize(const Size(320, 120));
    } else {
      await windowManager.setAlwaysOnTop(false);
      await windowManager.setTitleBarStyle(TitleBarStyle.normal);
      // КРИТИЧНО: скидаємо maxSize, встановлений у міні-режимі (320x120) —
      // саме через це вікно застрягало маленьким і не давало розгорнутись
      // після виходу з міні-плеєра. window_manager не скидає це сам.
      await windowManager.setMaximumSize(const Size(10000, 10000));
      await windowManager.setMinimumSize(const Size(400, 300));
      await windowManager.setResizable(true);
      await windowManager.setBackgroundColor(Colors.transparent);
      await windowManager.setSize(const Size(800, 600));
      await windowManager.center();
      WinTheme.forceDarkTitleBar();
    }
  }

  void _toggleMinimize() => _setMiniMode(!_isMinimized);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) Player.stop();
  }

  bool _isAudio(String p) => RegExp(r'\.(mp3|m4a|aac|mp4|webm|ogg)$', caseSensitive: false).hasMatch(p);
  bool _isImage(String p) => RegExp(r'\.(jpg|jpeg|png|webp)$', caseSensitive: false).hasMatch(p);

  Future<File> _playlistsFile() async {
    final base = await getMusicDir();
    return File('${base.path}/${PlaylistStore.fileName()}');
  }

  Future<void> _loadAll() async {
    final base = await getMusicDir();
    final songs = <Song>[];
    final playlists = <MusicPlaylist>[];

    try {
      for (final e in base.listSync(recursive: false)) {
        if (e is Directory) {
          // Підпапка — НЕ плейліст (ті тепер у playlists.txt), а:
          //  - 1 аудіо + (опційно) обкладинка -> "пісня з обкладинкою"
          //  - кілька аудіо -> папка масового завантаження (напр. YouTube
          //    плейліст), кожен файл показуємо як окрему пісню,
          //    обкладинку шукаємо за співпадінням імені файлу.
          final audioFiles = <File>[];
          final imageFiles = <File>[];
          for (final f in e.listSync(recursive: false)) {
            if (f is File && _isAudio(f.path)) audioFiles.add(f);
            if (f is File && _isImage(f.path)) imageFiles.add(f);
          }
          if (audioFiles.length == 1) {
            final folderName = basenameOf(e.path);
            final cover = imageFiles.isNotEmpty ? imageFiles.first.path : null;
            songs.add(Song(title: folderName, artist: 'Невідомий виконавець',
              filePath: audioFiles.first.path, coverPath: cover));
          } else if (audioFiles.length > 1) {
            final folderName = basenameOf(e.path);
            for (final audioFile in audioFiles) {
              final nameNoExt = stripAudioExt(basenameOf(audioFile.path));
              String? cover;
              for (final img in imageFiles) {
                if (stripAudioExt(basenameOf(img.path)) == nameNoExt) { cover = img.path; break; }
              }
              songs.add(Song(title: nameNoExt, artist: folderName,
                filePath: audioFile.path, coverPath: cover));
            }
          }
        } else if (e is File && _isAudio(e.path)) {
          // Пісня без обкладинки — просто файл у корені, без папки.
          final name = stripAudioExt(basenameOf(e.path));
          songs.add(Song(title: name, artist: 'Невідомий виконавець',
            filePath: e.path, coverPath: null));
        }
      }

      // Плейлисти: один спільний playlists.txt (muzikmen блоки)
      final plFile = await _playlistsFile();
      final entries = await PlaylistStore.readAll(plFile);
      for (final entry in entries) {
        final plSongs = <Song>[];
        for (final path in entry.paths) {
          final match = songs.where((s) => s.filePath == path);
          if (match.isNotEmpty) plSongs.add(match.first);
        }
        playlists.add(MusicPlaylist(name: entry.name, songs: plSongs));
      }
    } catch (_) {}

    if (mounted) setState(() { _songs = songs; _playlists = playlists; });
  }

  Future<void> _playSong(Song song, {List<Song>? queue}) async {
    final q = queue ?? _songs;
    final idx = q.indexWhere((s) => s.filePath == song.filePath);
    setState(() { _currentSong = song; _queue = List.from(q); _currentIndex = idx < 0 ? 0 : idx; });
    try {
      await Player.play(song.filePath);
      // play called above
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('❌ $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
    }
  }

  void _playNext() {
    if (_queue.isEmpty || _currentIndex == null) return;
    _playSong(_queue[(_currentIndex! + 1) % _queue.length], queue: _queue);
  }

  void _playPrev() {
    if (_queue.isEmpty || _currentIndex == null) return;
    _playSong(_queue[(_currentIndex! - 1 + _queue.length) % _queue.length], queue: _queue);
  }

  Future<void> _stopPlayer() async {
    await Player.stop();
    if (mounted) setState(() { _currentSong = null; _queue = []; _currentIndex = null; });
    if (_isMinimized) await _setMiniMode(false);
  }

  Future<void> _deleteSong(Song song) async {
    final ok = await _confirmDialog('Видалити "${song.title}"?');
    if (ok != true) return;
    if (_currentSong?.filePath == song.filePath) await _stopPlayer();
    try { await File(song.filePath).delete(); } catch (_) {}
    if (song.coverPath != null) try { await File(song.coverPath!).delete(); } catch (_) {}
    _loadAll();
  }

  Future<void> _renameSong(Song song) async {
    final ctrl = TextEditingController(text: song.title);
    final name = await _inputDialog('Перейменувати', ctrl);
    if (name == null || name.isEmpty || name == song.title) return;
    final dir = File(song.filePath).parent.path;
    final ext = song.filePath.split('.').last;
    try {
      await File(song.filePath).rename('$dir/$name.$ext');
      if (song.coverPath != null) await File(song.coverPath!).rename('$dir/$name.jpg');
    } catch (_) {}
    if (_currentSong?.filePath == song.filePath) await _stopPlayer();
    _loadAll();
  }

  /// Відкрити нативний Windows діалог вибору файлу через одноразовий
  /// PowerShell-виклик (System.Windows.Forms.OpenFileDialog).
  /// Це НЕ той самий персистентний процес, що й аудіоплеєр — просто
  /// один короткий виклик, який повертає обраний шлях і завершується.
  Future<String?> _pickImageFileWindows() async {
    const script = r'''
Add-Type -AssemblyName System.Windows.Forms
$f = New-Object System.Windows.Forms.OpenFileDialog
$f.Title = "Вибери обкладинку"
$f.Filter = "Зображення (*.jpg;*.jpeg;*.png;*.webp)|*.jpg;*.jpeg;*.png;*.webp"
if ($f.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
    Write-Output $f.FileName
}
''';
    try {
      final result = await Process.run(
        'powershell.exe',
        ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-Command', script],
      );
      final out = result.stdout.toString().trim();
      return out.isEmpty ? null : out;
    } catch (e) {
      print('[_pickImageFileWindows] error: $e');
      return null;
    }
  }

  /// Android/мобільний вибір зображення через нативний галерейний пікер
  /// (пакет image_picker, вже підключений у pubspec.yaml).
  Future<String?> _pickImageFileMobile() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
      return file?.path;
    } catch (e) {
      print('[_pickImageFileMobile] error: $e');
      return null;
    }
  }

  Future<String?> _pickImageFile() =>
      Platform.isWindows ? _pickImageFileWindows() : _pickImageFileMobile();

  String _sanitizeFileName(String name) =>
      name.replaceAll(RegExp(r'[<>:"/\\|?*#]'), '').trim();

  Future<void> _changeCover(Song song) async {
    final imgPath = await _pickImageFile();
    if (imgPath == null || imgPath.isEmpty) return;
    final ext = imgPath.contains('.') ? imgPath.split('.').last : 'jpg';

    try {
      final base = await getMusicDir();
      final currentDir = File(song.filePath).parent;
      final wasFlat = currentDir.path == base.path;
      final isCurrentlyPlaying = _currentSong?.filePath == song.filePath;

      if (wasFlat) {
        if (isCurrentlyPlaying) await _stopPlayer();
        // Пісня зараз лежить прямо в корені -> створюємо для неї власну
        // папку "Назва/" і переносимо аудіо туди разом з новою обкладинкою.
        final safeName = _sanitizeFileName(song.title);
        final newDir = Directory('${base.path}/$safeName');
        if (!await newDir.exists()) await newDir.create(recursive: true);
        final audioFileName = basenameOf(song.filePath);
        final newAudioPath = '${newDir.path}/$audioFileName';
        await File(song.filePath).rename(newAudioPath);
        await File(imgPath).copy('${newDir.path}/cover.$ext');
      } else {
        // Пісня вже в папці. Дізнаємось, скільки там аудіофайлів:
        // 1 -> це "пісня з обкладинкою", просто перезаписуємо cover.*;
        // кілька -> папка масового завантаження, обкладинку називаємо
        // так само, як аудіофайл цієї конкретної пісні (для збігу назв).
        final audioCount = currentDir.listSync()
          .whereType<File>().where((f) => _isAudio(f.path)).length;

        // Приберемо старі обкладинки, що явно належать саме цій пісні.
        final audioBase = stripAudioExt(basenameOf(song.filePath));
        for (final f in currentDir.listSync().whereType<File>()) {
          if (_isImage(f.path)) {
            final imgBase = stripAudioExt(basenameOf(f.path));
            if (audioCount == 1 || imgBase == audioBase) {
              try { await f.delete(); } catch (_) {}
            }
          }
        }

        final coverName = audioCount == 1 ? 'cover.$ext' : '$audioBase.$ext';
        await File(imgPath).copy('${currentDir.path}/$coverName');
      }

      await _loadAll();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ Обкладинку оновлено'),
        backgroundColor: Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('❌ Помилка: $e'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating));
    }
  }

  void _moveSong(Song song, int dir) {
    final idx = _songs.indexWhere((s) => s.filePath == song.filePath);
    if (idx < 0) return;
    final ni = (idx + dir).clamp(0, _songs.length - 1);
    if (ni == idx) return;
    setState(() {
      _songs.removeAt(idx);
      _songs.insert(ni, song);
      if (_currentIndex == idx) _currentIndex = ni;
      else if (_currentIndex == ni) _currentIndex = idx;
    });
  }

  void _showSongMenu(Song song, {bool inPlaylist = false}) {
    final idx = _songs.indexWhere((s) => s.filePath == song.filePath);
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => EditSheet(title: song.title, options: [
        EditOpt(Icons.delete_outline_rounded, Colors.red, 'Видалити',
          () { Navigator.pop(context); _deleteSong(song); }),
        if (!inPlaylist) EditOpt(Icons.drive_file_rename_outline_rounded, const Color(0xFF7C5CFC), 'Перейменувати',
          () { Navigator.pop(context); _renameSong(song); }),
        if (!inPlaylist) EditOpt(Icons.arrow_upward_rounded, const Color(0xFF4CAF50), 'Вгору',
          idx > 0 ? () { Navigator.pop(context); _moveSong(song, -1); } : null),
        if (!inPlaylist) EditOpt(Icons.arrow_downward_rounded, const Color(0xFF4CAF50), 'Вниз',
          idx < _songs.length - 1 ? () { Navigator.pop(context); _moveSong(song, 1); } : null),
        EditOpt(Icons.image_rounded, const Color(0xFFFC5C9C), 'Обкладинка',
          () { Navigator.pop(context); _changeCover(song); }),
        if (!inPlaylist) EditOpt(Icons.playlist_add_rounded, const Color(0xFFFFAA00), 'Додати до плейлісту',
          () { Navigator.pop(context); _addToPlaylistDialog(song); }),
      ]));
  }

  Future<void> _createPlaylist() async {
    final ctrl = TextEditingController();
    final name = await _inputDialog('Новий плейліст', ctrl, hint: 'Назва плейлісту');
    if (name == null || name.isEmpty) return;
    final file = await _playlistsFile();
    await PlaylistStore.createPlaylist(file, name);
    _loadAll();
  }

  Future<void> _deletePlaylist(MusicPlaylist pl) async {
    final ok = await _confirmDialog('Видалити "${pl.name}"? (пісні НЕ видаляться, тільки плейліст)');
    if (ok != true) return;
    if (_currentSong != null && pl.songs.any((s) => s.filePath == _currentSong!.filePath)) {
      await _stopPlayer();
    }
    final file = await _playlistsFile();
    await PlaylistStore.deletePlaylist(file, pl.name);
    _loadAll();
  }

  Future<void> _addToPlaylistDialog(Song song) async {
    if (_playlists.isEmpty) {
      final ok = await _confirmDialog('Немає плейлістів. Створити новий?');
      if (ok != true) return;
      await _createPlaylist();
      if (_playlists.isEmpty) return;
    }
    final pl = await showDialog<MusicPlaylist>(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF12121A),
      title: const Text('Додати до плейлісту', style: TextStyle(color: Colors.white)),
      content: Column(mainAxisSize: MainAxisSize.min,
        children: _playlists.map((p) => ListTile(
          leading: const Icon(Icons.queue_music_rounded, color: Color(0xFF7C5CFC)),
          title: Text(p.name, style: const TextStyle(color: Colors.white)),
          subtitle: Text('${p.songs.length} пісень', style: const TextStyle(color: Color(0xFF6A6A88))),
          onTap: () => Navigator.pop(context, p))).toList())));
    if (pl == null) return;
    try {
      final file = await _playlistsFile();
      await PlaylistStore.appendSong(file, pl.name, song.filePath);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ Додано до "${pl.name}"'), backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('❌ $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
    }
    _loadAll();
  }

  Future<bool?> _confirmDialog(String msg) => showDialog<bool>(context: context,
    builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF12121A),
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false),
          child: const Text('Скасувати', style: TextStyle(color: Color(0xFF6A6A88)))),
        TextButton(onPressed: () => Navigator.pop(context, true),
          child: const Text('Так', style: TextStyle(color: Colors.red))),
      ]));

  Future<String?> _inputDialog(String title, TextEditingController ctrl, {String hint = ''}) =>
    showDialog<String>(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF12121A),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      content: TextField(controller: ctrl, autofocus: true,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF6A6A88)),
          filled: true, fillColor: const Color(0xFF1A1A28),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF2A2A40))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF7C5CFC))))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
          child: const Text('Скасувати', style: TextStyle(color: Color(0xFF6A6A88)))),
        TextButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()),
          child: const Text('OK', style: TextStyle(color: Color(0xFF7C5CFC)))),
      ]));

  void _onVersionTap() {
    _versionTapCount++;
    if (_versionTapTimer != null) {
      _versionTapTimer!.cancel();
      _versionTapTimer = null;
    }
    _versionTapTimer = Timer(const Duration(milliseconds: 500), () {
      _versionTapCount = 0;
      _versionTapTimer = null;
    });
    if (_versionTapCount >= 3) {
      _versionTapCount = 0;
      _versionTapTimer?.cancel();
      _versionTapTimer = null;
      setState(() => _tab = 2);
    }
  }

  void _launchDoom() async {
    // Пошук нативних DOOM-бінарників через `which` має сенс лише на
    // desktop (Windows/Linux) — на Android одразу відкриваємо вбудовану
    // міні-гру.
    if (!Platform.isWindows) {
      _openMiniDoom();
      return;
    }
    final doomCmds = ['chocolate-doom', 'gzdoom', 'doom'];
    String? found;
    for (final cmd in doomCmds) {
      final result = await Process.run('which', [cmd]).catchError((_) => null);
      if (result != null && result.exitCode == 0) { found = cmd; break; }
    }
    if (found != null) {
      try {
        await Process.start(found, []);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('🔥 DOOM запущено!', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Color(0xFF7C5CFC), behavior: SnackBarBehavior.floating));
      } catch (e) {
        _openMiniDoom();
      }
    } else {
      _openMiniDoom();
    }
  }

  // ===== Easter egg: Mini Doom =====
  void _openMiniDoom() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const MiniDoomGame()));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (Platform.isWindows) windowManager.removeListener(this);
    Player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // textScale (густина шрифту) застосовується глобально для всього
    // піддерева MainScreen — тут, а не в Pro420App/MaterialApp.builder,
    // бо MainScreen надійно перемальовується при зміні налаштувань
    // (через onWallpaperChanged→setState), а корінь MaterialApp — ні.
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(AppConfig.textScale)),
      child: _buildContent(context));
  }

  /// iPhone з вирізом/Dynamic Island: вкладки без власного SafeArea
  /// (Завантаження, Налаштування, десктопна розкладка) наповзали б на
  /// статус-бар. На Android/Windows нічого не змінюємо.
  Widget _iosTop(Widget child) =>
      Platform.isIOS ? SafeArea(bottom: false, child: child) : child;

  Widget _buildContent(BuildContext context) {
    if (!_booted) return const _BootSplash();
    // Екран першого запуску тепер вимкнений за замовчуванням — показується
    // лише для тестування через ключ --startlogo (не автоматично на
    // першому запуску, не блокує звичайну роботу застосунку).
    if (AppConfig.forceOnboarding) {
      return OnboardingScreen(onDone: () => setState(() {}));
    }
    return _isMinimized
        ? DragToMoveArea(
            child: MiniPlayerWidget(
              song: _currentSong,
              isPlaying: _isPlaying,
              position: _position,
              duration: _duration,
              onPlayPause: () => _isPlaying ? Player.pause() : Player.resume(),
              onNext: _playNext,
              onPrev: _playPrev,
              onStop: _stopPlayer,
              onExpand: () => _setMiniMode(false),
            ),
          )
        : Stack(children: [
            // Матовий (frosted) фон — на Windows це шпалери робочого столу
            // (якщо перемикач увімкнутий), на Android — зображення з
            // галереї, вибране користувачем. Працює на всіх вкладках.
            if (AppConfig.hasCustomBackground) ...[
              Positioned.fill(child: Image.file(
                File(AppConfig.backgroundImagePath!), fit: BoxFit.cover)),
              Positioned.fill(child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(color: Colors.black.withOpacity(0.55)))),
            ],
            Scaffold(
            backgroundColor: AppConfig.hasCustomBackground ? Colors.transparent : const Color(0xFF0A0A0F),
            body: Stack(children: [
            Column(children: [
              Expanded(child: IndexedStack(index: _tab, children: [
                AnimatedTabVisibility(
                  active: _tab == 0,
                  child: AppConfig.desktopLayout ? _iosTop(SongsTabDesktop(
                  songs: _songs,
                  playlists: _playlists,
                  currentSong: _currentSong,
                  onPlay: (s) => _playSong(s, queue: _songs),
                  onPlayPlaylist: (s, pl) => _playSong(s, queue: pl.songs),
                  onRefresh: _loadAll,
                  editMode: _editMode,
                  onToggleEdit: () => setState(() => _editMode = !_editMode),
                  onSongMenu: _showSongMenu,
                  onCreatePlaylist: _createPlaylist,
                  onDeletePlaylist: _deletePlaylist,
                  onVersionTap: _onVersionTap,
                  onSettings: () => setState(() => _tab = 2),
                )) : SongsTab(
                  songs: _songs,
                  playlists: _playlists,
                  currentSong: _currentSong,
                  onPlay: (s) => _playSong(s, queue: _songs),
                  onPlayPlaylist: (s, pl) => _playSong(s, queue: pl.songs),
                  onRefresh: _loadAll,
                  editMode: _editMode,
                  onToggleEdit: () => setState(() => _editMode = !_editMode),
                  onSongMenu: _showSongMenu,
                  onCreatePlaylist: _createPlaylist,
                  onDeletePlaylist: _deletePlaylist,
                  onVersionTap: _onVersionTap,
                ),
                ),
                AnimatedTabVisibility(
                  active: _tab == 1,
                  child: _iosTop(DownloadTab(onSongAdded: _loadAll)),
                ),
                AnimatedTabVisibility(
                  active: _tab == 2,
                  child: _iosTop(SettingsScreen(onEasterEgg: _openMiniDoom,
                  songs: _songs, playlists: _playlists, onDataChanged: _loadAll,
                  onWallpaperChanged: () => setState(() {}))),
                ),
              ])),
              // На Android мініплеєр докований у звичайному потоці —
              // прямо над нижньою навігацією (не поверх neї), без
              // ручного розрахунку відступів.
              if (!Platform.isWindows)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => SizeTransition(
                    sizeFactor: animation,
                    axisAlignment: -1,
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: _currentSong == null
                      ? const SizedBox.shrink(key: ValueKey('no-mobile-mini-player'))
                      : MobileMiniPlayer(
                          key: const ValueKey('mobile-mini-player'),
                          song: _currentSong!,
                          isPlaying: _isPlaying,
                          position: _position,
                          duration: _duration,
                          onPlayPause: () => _isPlaying ? Player.pause() : Player.resume(),
                          onNext: _playNext,
                          onPrev: _playPrev,
                          onStop: _stopPlayer,
                        ),
                ),
              AeroBottomNav(current: _tab, onChange: (i) => setState(() => _tab = i)),
            ]),
            // На Windows — ефемерний Media Overlay (з'являється при
            // наведенні). На Android hover немає — мініплеєр вже
            // показаний вище, у звичайному потоці Column.
            if (Platform.isWindows)
              Positioned.fill(child: MediaOverlay(
                song: _currentSong,
                isPlaying: _isPlaying,
                position: _position,
                duration: _duration,
                onPlayPause: () => _isPlaying ? Player.pause() : Player.resume(),
                onNext: _playNext,
                onPrev: _playPrev,
                onStop: _stopPlayer,
                onMinimize: _toggleMinimize,
                onSeek: (pos) => Player.seek(pos),
              )),
          ]),
          ),
        ]);
  }
}











