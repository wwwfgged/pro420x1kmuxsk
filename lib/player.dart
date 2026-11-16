import 'dart:io';

import 'android_player.dart';
import 'ios_player.dart';
import 'windows_player.dart';

/// Єдина точка входу для UI (main.dart, віджети): ховає різницю між
///  - WindowsPlayer (PowerShell + WPF MediaPlayer),
///  - IosPlayer (AVPlayer через just_audio, з діагностикою помилок),
///  - AndroidPlayer (ExoPlayer через just_audio).
/// Усі три мають ідентичний статичний API.
class Player {
  Player._();

  static T _by<T>(T Function() win, T Function() ios, T Function() android) =>
      Platform.isWindows ? win() : (Platform.isIOS ? ios() : android());

  static Stream<Duration> get positionStream => _by<Stream<Duration>>(
      () => WindowsPlayer.positionStream, () => IosPlayer.positionStream, () => AndroidPlayer.positionStream);
  static Stream<Duration> get durationStream => _by<Stream<Duration>>(
      () => WindowsPlayer.durationStream, () => IosPlayer.durationStream, () => AndroidPlayer.durationStream);
  static Stream<bool> get playingStream => _by<Stream<bool>>(
      () => WindowsPlayer.playingStream, () => IosPlayer.playingStream, () => AndroidPlayer.playingStream);
  static Stream<void> get completionStream => _by<Stream<void>>(
      () => WindowsPlayer.completionStream, () => IosPlayer.completionStream, () => AndroidPlayer.completionStream);

  static bool get isPlaying =>
      _by<bool>(() => WindowsPlayer.isPlaying, () => IosPlayer.isPlaying, () => AndroidPlayer.isPlaying);
  static bool get isPaused =>
      _by<bool>(() => WindowsPlayer.isPaused, () => IosPlayer.isPaused, () => AndroidPlayer.isPaused);
  static Duration get position =>
      _by<Duration>(() => WindowsPlayer.position, () => IosPlayer.position, () => AndroidPlayer.position);
  static Duration get duration =>
      _by<Duration>(() => WindowsPlayer.duration, () => IosPlayer.duration, () => AndroidPlayer.duration);

  static Future<void> play(String filePath) => _by<Future<void>>(
      () => WindowsPlayer.play(filePath), () => IosPlayer.play(filePath), () => AndroidPlayer.play(filePath));
  static Future<void> pause() => _by<Future<void>>(
      () => WindowsPlayer.pause(), () => IosPlayer.pause(), () => AndroidPlayer.pause());
  static Future<void> resume() => _by<Future<void>>(
      () => WindowsPlayer.resume(), () => IosPlayer.resume(), () => AndroidPlayer.resume());
  static Future<void> stop() => _by<Future<void>>(
      () => WindowsPlayer.stop(), () => IosPlayer.stop(), () => AndroidPlayer.stop());
  static Future<void> seek(Duration position) => _by<Future<void>>(
      () => WindowsPlayer.seek(position), () => IosPlayer.seek(position), () => AndroidPlayer.seek(position));

  static void dispose() {
    if (Platform.isWindows) {
      WindowsPlayer.dispose();
    } else if (Platform.isIOS) {
      IosPlayer.dispose();
    } else {
      AndroidPlayer.dispose();
    }
  }
}
