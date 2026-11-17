import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import 'audio_sniff.dart';

/// Помилка відтворення з уже готовим текстом для користувача
/// (показується в червоному SnackBar з main.dart → _playSong).
class PlayerError implements Exception {
  final String message;
  PlayerError(this.message);
  @override
  String toString() => message;
}

/// Плеєр СПЕЦІАЛЬНО під iOS (AVPlayer через just_audio).
///
/// Чим відрізняється від AndroidPlayer:
///  - помилки НЕ ковтаються, а кидаються нагору — на iPhone немає логів під
///    рукою, тож користувач бачить причину прямо на екрані;
///  - перед відтворенням перевіряємо файл (існує? не порожній?) і формат
///    (AVPlayer не вміє webm/ogg/opus — це найчастіша причина "тиші");
///  - таймаут завантаження треку, щоб інтерфейс не "висів" вічно;
///  - play() не await-иться до кінця треку (у just_audio цей Future
///    завершується лише коли трек доспівав) — інакше стан UI плутається;
///  - аудіосесія з категорією playback: звук іде навіть при ввімкненому
///    беззвучному режимі (перемикач збоку) і при вимкненому екрані
///    (разом з UIBackgroundModes=audio, який дописує codemagic.yaml).
///
/// Публічний API ідентичний WindowsPlayer/AndroidPlayer.
class IosPlayer {
  IosPlayer._();

  static AudioPlayer? _player;
  static bool _sessionReady = false;
  static bool _disposed = false;

  static final _positionController = StreamController<Duration>.broadcast();
  static final _durationController = StreamController<Duration>.broadcast();
  static final _playingController = StreamController<bool>.broadcast();
  static final _completionController = StreamController<void>.broadcast();
  static final _queueIndexController = StreamController<int>.broadcast();

  static Stream<Duration> get positionStream => _positionController.stream;
  static Stream<Duration> get durationStream => _durationController.stream;
  static Stream<bool> get playingStream => _playingController.stream;
  static Stream<void> get completionStream => _completionController.stream;

  /// Нативний AVQueuePlayer повідомляє про перехід до наступного треку сам —
  /// навіть коли екран заблокований і Dart-ізоляція призупинена.
  static Stream<int> get queueIndexStream => _queueIndexController.stream;

  static bool get isPlaying => _player?.playing ?? false;
  static bool get isPaused =>
      _player != null && !_player!.playing && _player!.processingState == ProcessingState.ready;
  static Duration get position => _player?.position ?? Duration.zero;
  static Duration get duration => _player?.duration ?? Duration.zero;

  static AudioPlayer _ensurePlayer() {
    final existing = _player;
    if (existing != null) return existing;
    final p = AudioPlayer();
    _player = p;

    void onErr(Object e, [StackTrace? st]) => print('[IosPlayer] stream error: $e');

    p.positionStream.listen(_positionController.add, onError: onErr);
    p.durationStream.listen((d) { if (d != null) _durationController.add(d); }, onError: onErr);
    p.playingStream.listen(_playingController.add, onError: onErr);
    p.playbackEventStream.listen((_) {}, onError: onErr);
    p.processingStateStream.listen((s) {
      if (s == ProcessingState.completed) _completionController.add(null);
    }, onError: onErr);
    // Індекс черги змінюється нативним плеєром — це і є автоперемикання
    /// треків у фоні, коли застосунок не активний.
    p.currentIndexStream.listen((i) {
      if (i != null) _queueIndexController.add(i);
    }, onError: onErr);
    return p;
  }

  static Future<void> _ensureSession() async {
    if (_sessionReady) return;
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());

      // Навушники від'єднали — пауза.
      session.becomingNoisyEventStream.listen((_) {
        if (_player?.playing == true) _player!.pause();
      });
      // Дзвінок/Siri: пауза на початку, відновлення після.
      session.interruptionEventStream.listen((e) {
        final p = _player;
        if (p == null) return;
        if (e.begin) {
          p.pause();
        } else if (e.type == AudioInterruptionType.pause) {
          unawaited(p.play());
        }
      });
      _sessionReady = true;
    } catch (e) {
      // Не фатально: just_audio активує сесію сам при play().
      print('[IosPlayer] audio session init error: $e');
    }
  }

  static Future<void> play(String filePath) async {
    final name = filePath.split('/').last;
    final file = File(filePath);

    if (!await file.exists()) {
      throw PlayerError('Файл не знайдено: $name');
    }
    if (await file.length() == 0) {
      throw PlayerError('Файл порожній (0 байт): $name — завантаж пісню ще раз');
    }
    // Реальний формат за вмістом файлу. AVPlayer довіряє розширенню, тому
    // mp3/aac під іменем .mp4 (так зберігались TikTok-звуки) дає помилку
    // -11829. Для таких файлів граємо тимчасову копію з правильним
    // розширенням — старі завантаження працюють без повторного скачування.
    final real = await sniffAudioExt(filePath);
    if (real == 'webm' || real == 'ogg' || extensionOf(filePath) == 'opus') {
      throw PlayerError('iPhone не відтворює webm/ogg/opus: $name. '
          'Завантаж пісню ще раз — нова версія зберігає .m4a/.mp4');
    }
    var playPath = filePath;
    if (real != null && !sameAudioKind(extensionOf(filePath), real)) {
      final size = await file.length();
      final tmp = File('${Directory.systemTemp.path}/ios_play_${filePath.hashCode.abs()}_$size.$real');
      if (!await tmp.exists()) await file.copy(tmp.path);
      playPath = tmp.path;
    }

    await _ensureSession();
    final p = _ensurePlayer();
    try {
      await p.stop();
      await p
          .setAudioSource(AudioSource.uri(Uri.file(playPath)))
          .timeout(const Duration(seconds: 20));
      // НЕ await: цей Future завершується, коли трек догра́є.
      unawaited(p.play().catchError((Object e) => print('[IosPlayer] play error: $e')));
      print('[IosPlayer] ▶️ $name');
    } on PlayerInterruptedException {
      // Запустили інший трек поки вантажився цей — це нормально.
    } on PlayerException catch (e) {
      throw PlayerError('iOS не зміг відтворити "$name" (код ${e.code}): ${e.message ?? "без опису"}. '
          'Формат за вмістом: ${real ?? "невідомий"}, розширення: .${extensionOf(filePath)}');
    } on TimeoutException {
      throw PlayerError('Таймаут: трек "$name" не завантажився за 20 с');
    }
  }

  /// Підготувати один файл черги: перевірити, виправити розширення
  /// (старі TikTok-звуки збережені з неправильним розширенням) і зробити
  /// AudioSource для нативного чергового плеєра.
  static Future<AudioSource> _audioSourceFor(String filePath) async {
    final name = filePath.split('/').last;
    final file = File(filePath);
    if (!await file.exists()) {
      throw PlayerError('Файл не знайдено: $name');
    }
    final size = await file.length();
    if (size == 0) {
      throw PlayerError('Файл порожній (0 байт): $name — завантаж пісню ще раз');
    }
    final real = await sniffAudioExt(filePath);
    if (real == 'webm' || real == 'ogg' || extensionOf(filePath) == 'opus') {
      throw PlayerError('iPhone не відтворює webm/ogg/opus: $name. '
          'Завантаж пісню ще раз — нова версія зберігає .m4a/.mp4');
    }
    var playPath = filePath;
    if (real != null && !sameAudioKind(extensionOf(filePath), real)) {
      final tmp = File('${Directory.systemTemp.path}/ios_play_${filePath.hashCode.abs()}_$size.$real');
      if (!await tmp.exists()) await file.copy(tmp.path);
      playPath = tmp.path;
    }
    return AudioSource.uri(Uri.file(playPath));
  }

  /// Задати всю чергу одразу. AVQueuePlayer сам переходить до наступного
  /// треку по завершенню поточного — без участі Dart-коду, тому музика
  /// не зупиняється на останньому треку при заблокованому екрані.
  static Future<void> playQueue(List<String> paths, int index) async {
    if (paths.isEmpty) return;
    final start = index.clamp(0, paths.length - 1);

    await _ensureSession();
    final children = <AudioSource>[];
    for (final path in paths) {
      children.add(await _audioSourceFor(path));
    }
    final p = _ensurePlayer();
    try {
      await p.stop();
      // Зациклюємо всю чергу: після останнього треку знову перший.
      await p.setLoopMode(LoopMode.all);
      // preload:false — не завантажуємо всю бібліотеку одразу (при 500+
      // треках це була б помітна затримка), поточний трек підвантажиться
      // сам при play().
      await p.setAudioSources(children, initialIndex: start, preload: false);
      // НЕ await: Future завершується лише коли вся черга дограє.
      unawaited(p.play().catchError((Object e) => print('[IosPlayer] queue play error: $e')));
      print('[IosPlayer] ▶️ queue (${paths.length} треків) з індексу $start');
    } on PlayerInterruptedException {
      // Запустили іншу чергу, поки готували цю — нормально.
    } on PlayerException catch (e) {
      throw PlayerError('iOS не зміг запустити чергу (код ${e.code}): ${e.message ?? "без опису"}');
    }
  }

  /// Нативне перемикання в межах черги — не перезавантажує файл і не
  /// ламає фонове відтворення.
  static Future<void> skipToNext() async {
    try { await _player?.seekToNext(); } catch (e) { print('[IosPlayer] skipNext error: $e'); }
  }

  static Future<void> skipToPrevious() async {
    try { await _player?.seekToPrevious(); } catch (e) { print('[IosPlayer] skipPrev error: $e'); }
  }

  static Future<void> pause() async {
    try { await _player?.pause(); } catch (e) { print('[IosPlayer] pause error: $e'); }
  }

  static Future<void> resume() async {
    final p = _player;
    if (p == null) return;
    unawaited(p.play().catchError((Object e) => print('[IosPlayer] resume error: $e')));
  }

  static Future<void> stop() async {
    try { await _player?.stop(); } catch (e) { print('[IosPlayer] stop error: $e'); }
  }

  static Future<void> seek(Duration position) async {
    try { await _player?.seek(position); } catch (e) { print('[IosPlayer] seek error: $e'); }
  }

  static void dispose() {
    if (_disposed) return;
    _disposed = true;
    try {
      _player?.dispose();
      _positionController.close();
      _durationController.close();
      _playingController.close();
      _completionController.close();
      _queueIndexController.close();
    } catch (e) {
      print('[IosPlayer] dispose error: $e');
    }
  }
}
