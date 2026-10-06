import 'dart:io';

import 'android_player.dart';
import 'windows_player.dart';

/// Єдина точка входу для UI-коду (main.dart тощо), яка приховує різницю
/// між WindowsPlayer (PowerShell + WPF MediaPlayer) та AndroidPlayer
/// (just_audio + audio_service). Обидва класи мають ідентичний статичний
/// API, тому тут просто маршрутизуємо виклики за платформою.
///
/// Якщо колись додасться Linux/macOS плеєр — досить дописати ще одну
/// гілку тут, решта коду не зміниться.
class Player {
  Player._();

  static Stream<Duration> get positionStream =>
      Platform.isWindows ? WindowsPlayer.positionStream : AndroidPlayer.positionStream;
  static Stream<Duration> get durationStream =>
      Platform.isWindows ? WindowsPlayer.durationStream : AndroidPlayer.durationStream;
  static Stream<bool> get playingStream =>
      Platform.isWindows ? WindowsPlayer.playingStream : AndroidPlayer.playingStream;
  static Stream<void> get completionStream =>
      Platform.isWindows ? WindowsPlayer.completionStream : AndroidPlayer.completionStream;

  static bool get isPlaying => Platform.isWindows ? WindowsPlayer.isPlaying : AndroidPlayer.isPlaying;
  static bool get isPaused => Platform.isWindows ? WindowsPlayer.isPaused : AndroidPlayer.isPaused;
  static Duration get position => Platform.isWindows ? WindowsPlayer.position : AndroidPlayer.position;
  static Duration get duration => Platform.isWindows ? WindowsPlayer.duration : AndroidPlayer.duration;

  static Future<void> play(String filePath) =>
      Platform.isWindows ? WindowsPlayer.play(filePath) : AndroidPlayer.play(filePath);

  static Future<void> pause() =>
      Platform.isWindows ? WindowsPlayer.pause() : AndroidPlayer.pause();

  static Future<void> resume() =>
      Platform.isWindows ? WindowsPlayer.resume() : AndroidPlayer.resume();

  static Future<void> stop() =>
      Platform.isWindows ? WindowsPlayer.stop() : AndroidPlayer.stop();

  static Future<void> seek(Duration position) =>
      Platform.isWindows ? WindowsPlayer.seek(position) : AndroidPlayer.seek(position);

  static void dispose() {
    if (Platform.isWindows) {
      WindowsPlayer.dispose();
    } else {
      AndroidPlayer.dispose();
    }
  }
}
