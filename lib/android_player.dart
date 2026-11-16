import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

/// Android медіа-плеєр на базі голого just_audio + audio_session.
///
/// Свідомо БЕЗ audio_service: цей пакет вимагає, щоб MainActivity
/// наслідувалась від com.ryanheise.audioservice.AudioServiceActivity,
/// інакше кидає PlatformException при першому ж play(). Це саме те,
/// що ламало збірку. audio_session тут лишається — він відповідає за
/// коректну поведінку з навушниками (пауза при від'єднанні) та
/// перериваннями (дзвінки), без вимог до MainActivity.
///
/// Недолік цього підходу: немає нотифікації на лок-скріні й керування
/// з шторки/навушників кнопками play/pause/next — це можна додати
/// пізніше окремим кроком, коли буде готовий кастомний MainActivity.
///
/// ВАЖЛИВО про лінивість: main.dart підписується на positionStream/
/// durationStream/playingStream/completionStream ОДРАЗУ в initState(),
/// ще до того як користувач хоч раз натиснув play. Якщо публічні стріми
/// напряму проксіюють `_player.xxx`, а `_player` — це `static final
/// AudioPlayer _player = AudioPlayer()`, то сам факт звернення до
/// геттера ЗМУШУЄ Dart створити AudioPlayer() (а значить і нативний
/// ExoPlayer під капотом just_audio) прямо на старті застосунку — на
/// кожному запуску, навіть якщо музику ніхто не вмикав. Тому тут
/// публічні стріми — це ОКРЕМІ broadcast-контролери, які просто
/// ретранслюють події від _player ПІСЛЯ того, як він реально створений
/// (у play()). Підписка на них нічого не будує заздалегідь.
///
/// Публічний API ідентичний WindowsPlayer, щоб player.dart міг
/// перемикати платформи без зміни іншого коду.
class AndroidPlayer {
  AndroidPlayer._();

  static AudioPlayer? _playerInstance;
  static bool _sessionReady = false;
  static bool _disposed = false;

  static final _positionController = StreamController<Duration>.broadcast();
  static final _durationController = StreamController<Duration>.broadcast();
  static final _playingController = StreamController<bool>.broadcast();
  static final _completionController = StreamController<void>.broadcast();

  static Stream<Duration> get positionStream => _positionController.stream;
  static Stream<Duration> get durationStream => _durationController.stream;
  static Stream<bool> get playingStream => _playingController.stream;
  static Stream<void> get completionStream => _completionController.stream;

  static bool get isPlaying => _playerInstance?.playing ?? false;
  static bool get isPaused => _playerInstance != null &&
      !_playerInstance!.playing && _playerInstance!.processingState == ProcessingState.ready;
  static Duration get position => _playerInstance?.position ?? Duration.zero;
  static Duration get duration => _playerInstance?.duration ?? Duration.zero;

  /// Створює AudioPlayer() та підключає його стріми до наших публічних
  /// контролерів. Викликається лише зсередини play(), тобто при першому
  /// реальному відтворенні — не раніше.
  static AudioPlayer _ensurePlayer() {
    final existing = _playerInstance;
    if (existing != null) return existing;

    final p = AudioPlayer();
    _playerInstance = p;

    p.positionStream.listen(_positionController.add,
      onError: (e) => print('[AndroidPlayer] positionStream error: $e'));
    p.durationStream.listen((d) { if (d != null) _durationController.add(d); },
      onError: (e) => print('[AndroidPlayer] durationStream error: $e'));
    p.playingStream.listen(_playingController.add,
      onError: (e) => print('[AndroidPlayer] playingStream error: $e'));
    p.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) _completionController.add(null);
    });

    return p;
  }

  static Future<void> _ensureSession() async {
    if (_sessionReady) return;
    _sessionReady = true;
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());

      session.becomingNoisyEventStream.listen((_) {
        if (_playerInstance?.playing == true) _playerInstance!.pause();
      });

      session.interruptionEventStream.listen((e) {
        if (_playerInstance == null) return;
        if (e.begin) {
          _playerInstance!.pause();
        } else if (e.type == AudioInterruptionType.pause) {
          _playerInstance!.play();
        }
      });

      await session.setActive(true);
    } catch (e) {
      print('[AndroidPlayer] audio session init error: $e');
    }
  }

  static Future<void> play(String filePath) async {
    // Обидва виклики (сесія + сам плеєр) відбуваються лише тут, тобто
    // при першому реальному натисканні play — не на старті застосунку.
    await _ensureSession();
    final p = _ensurePlayer();
    try {
      await p.setFilePath(filePath);
      await p.play();
      print('[AndroidPlayer] ▶️ Play: $filePath');
    } catch (e) {
      print('[AndroidPlayer] play() error: $e');
    }
  }

  static Future<void> pause() async {
    if (_playerInstance == null) return;
    try {
      await _playerInstance!.pause();
    } catch (e) {
      print('[AndroidPlayer] pause() error: $e');
    }
  }

  static Future<void> resume() async {
    if (_playerInstance == null) return;
    try {
      await _playerInstance!.play();
    } catch (e) {
      print('[AndroidPlayer] resume() error: $e');
    }
  }

  static Future<void> stop() async {
    if (_playerInstance == null) return;
    try {
      await _playerInstance!.stop();
    } catch (e) {
      print('[AndroidPlayer] stop() error: $e');
    }
  }

  static Future<void> seek(Duration position) async {
    if (_playerInstance == null) return;
    try {
      await _playerInstance!.seek(position);
    } catch (e) {
      print('[AndroidPlayer] seek() error: $e');
    }
  }

  static void dispose() {
    if (_disposed) return;
    _disposed = true;
    try {
      _playerInstance?.dispose();
      _positionController.close();
      _durationController.close();
      _playingController.close();
      _completionController.close();
      print('[AndroidPlayer] 🔌 Dispose завершено');
    } catch (e) {
      print('[AndroidPlayer] dispose() error: $e');
    }
  }
}
