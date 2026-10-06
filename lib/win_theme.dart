import 'dart:ffi';
import 'package:ffi/ffi.dart';

/// Windows 11 (і 10 build 19041+) слідує системній світлій/темній темі для
/// РАМКИ вікна (title bar), незалежно від того, який темний UI малює сам
/// Flutter всередині. Якщо в користувача Windows у світлій темі — рамка
/// стає білою, хоча весь застосунок темний. Це виправляється прямим
/// викликом DwmSetWindowAttribute(DWMWA_USE_IMMERSIVE_DARK_MODE).
class WinTheme {
  static const _dwmwaUseImmersiveDarkMode = 20;

  static bool _applied = false;

  /// Примусово зробити рамку вікна темною. Викликати один раз після того,
  /// як вікно вже показане й у фокусі (GetForegroundWindow має повернути
  /// саме наше вікно).
  static void forceDarkTitleBar() {
    if (_applied) return;
    try {
      final user32 = DynamicLibrary.open('user32.dll');
      final dwmapi = DynamicLibrary.open('dwmapi.dll');

      final getForegroundWindow = user32
          .lookupFunction<IntPtr Function(), int Function()>('GetForegroundWindow');

      final dwmSetWindowAttribute = dwmapi.lookupFunction<
          Int32 Function(IntPtr hwnd, Uint32 attr, Pointer<Int32> value, Uint32 size),
          int Function(int hwnd, int attr, Pointer<Int32> value, int size)>('DwmSetWindowAttribute');

      final hwnd = getForegroundWindow();
      if (hwnd == 0) {
        print('[WinTheme] hwnd не знайдено, пропускаю');
        return;
      }

      final value = calloc<Int32>()..value = 1;
      try {
        dwmSetWindowAttribute(hwnd, _dwmwaUseImmersiveDarkMode, value, sizeOf<Int32>());
        _applied = true;
        print('[WinTheme] ✅ Темна рамка вікна застосована (hwnd=$hwnd)');
      } finally {
        calloc.free(value);
      }
    } catch (e) {
      print('[WinTheme] Не вдалось застосувати темну рамку: $e');
    }
  }
}
