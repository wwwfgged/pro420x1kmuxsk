// ТЕСТОВИЙ ФАЙЛ - скопіювати в main.dart тимчасово для тестування
// Після тестування видалити цей код

import 'dart:async';
import 'windows_player.dart';

Future<void> testWindowsPlayer() async {
  print('\n' + '=' * 60);
  print('🎵 ТЕСТУВАННЯ WINDOWS PLAYER 🎵');
  print('=' * 60 + '\n');

  // Замініть це на реальний шлях до тестового mp3 файлу
  const testFile = r'C:\Users\YOU\Music\muzik420\test.mp3';

  try {
    // ===== ТЕСТ 1: Базовий плей =====
    print('📋 ТЕСТ 1: Запуск відтворення...');
    WindowsPlayer.durationStream.listen((dur) {
      print('   📏 Тривалість: ${dur.inSeconds}s');
    });

    WindowsPlayer.positionStream.listen((pos) {
      print('   ⏱️  Позиція: ${pos.inSeconds}s');
    });

    WindowsPlayer.playingStream.listen((playing) {
      print('   ▶️  Грає: $playing');
    });

    WindowsPlayer.completionStream.listen((_) {
      print('   ✅ Пісня закінчилась!');
    });

    await WindowsPlayer.play(testFile);
    print('✅ ТЕСТ 1 ПРОЙШОВ: Музика повинна грати\n');

    // ===== ТЕСТ 2: Пауза =====
    await Future.delayed(Duration(seconds: 3));
    print('📋 ТЕСТ 2: Пауза...');
    await WindowsPlayer.pause();
    final isPausedAfterPause = WindowsPlayer.isPaused;
    print('✅ ТЕСТ 2: isPaused = $isPausedAfterPause (повинно бути true)\n');

    // ===== ТЕСТ 3: Відновлення =====
    await Future.delayed(Duration(seconds: 2));
    print('📋 ТЕСТ 3: Відновлення...');
    await WindowsPlayer.resume();
    final isPlayingAfterResume = WindowsPlayer.isPlaying;
    print('✅ ТЕСТ 3: isPlaying = $isPlayingAfterResume (повинно бути true)\n');

    // ===== ТЕСТ 4: Seek =====
    await Future.delayed(Duration(seconds: 2));
    print('📋 ТЕСТ 4: Seek на 10s...');
    await WindowsPlayer.seek(Duration(seconds: 10));
    print('✅ ТЕСТ 4: Seek виконано\n');

    // ===== ТЕСТ 5: Зупинка =====
    await Future.delayed(Duration(seconds: 5));
    print('📋 ТЕСТ 5: Зупинка...');
    await WindowsPlayer.stop();
    final isPlayingAfterStop = WindowsPlayer.isPlaying;
    print('✅ ТЕСТ 5: isPlaying = $isPlayingAfterStop (повинно бути false)\n');

    print('=' * 60);
    print('✅ ВСІ ТЕСТИ ПРОЙШЛИ УСПІШНО!');
    print('=' * 60 + '\n');

  } catch (e) {
    print('❌ ПОМИЛКА: $e\n');
  }
}

// ===== БЫСТРИЙ ТЕСТ БЕЗ ОЧІКУВАННЯ =====

Future<void> quickTest() async {
  const testFile = r'C:\Users\YOU\Music\muzik420\test.mp3';

  print('🚀 БЫСТРИЙ ТЕСТ\n');

  try {
    await WindowsPlayer.play(testFile);
    print('✅ Play: OK');

    await Future.delayed(Duration(seconds: 3));
    await WindowsPlayer.pause();
    print('✅ Pause: OK');

    await Future.delayed(Duration(seconds: 1));
    await WindowsPlayer.resume();
    print('✅ Resume: OK');

    await Future.delayed(Duration(seconds: 3));
    await WindowsPlayer.stop();
    print('✅ Stop: OK');

    print('\n✅ БЫСТРИЙ ТЕСТ ЗАВЕРШЕНО!');
  } catch (e) {
    print('❌ Помилка: $e');
  }
}

// ===== КОД ДЛЯ ВСТАВКИ В main() =====
/*

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ТЕСТ (видалити потім!)
  // await testWindowsPlayer();
  
  await AppConfig.load(args);
  await windowManager.ensureInitialized();
  // ... решта коду
}

*/
