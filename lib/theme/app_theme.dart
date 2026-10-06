import 'package:flutter/material.dart';
import '../config/app_config.dart';

/// Один пресет кольорової теми: основний акцент (кнопки, іконки,
/// прогрес-бари) + другорядний (градієнти, підсвітка).
class ThemePreset {
  final String id;
  final String label;
  final Color primary;
  final Color secondary;
  const ThemePreset({required this.id, required this.label, required this.primary, required this.secondary});
}

/// Централізований доступ до кольорів теми. Раніше акцентні кольори
/// (0xFF7C5CFC / 0xFFFC5C9C) були жорстко "закопані" по всьому коду —
/// тепер AeroColors.primary/secondary (в songs_tab_desktop.dart) і
/// MaterialApp-тема (в main.dart) читають звідси, а не const-літерали.
/// Це не покриває 100% старих hardcoded кольорів по всіх файлах (їх
/// дуже багато й вони розкидані), але покриває весь "ПК режим" UI
/// (songs_tab_desktop.dart) і бекап-екран — саме там, де це найбільш
/// помітно.
class AppTheme {
  static const List<ThemePreset> presets = [
    ThemePreset(id: 'purple', label: 'Фіолетовий', primary: Color(0xFF7C5CFC), secondary: Color(0xFFFC5C9C)),
    ThemePreset(id: 'blue', label: 'Синій', primary: Color(0xFF2196F3), secondary: Color(0xFF00E5FF)),
    ThemePreset(id: 'green', label: 'Зелений', primary: Color(0xFF4CAF50), secondary: Color(0xFFCDDC39)),
    ThemePreset(id: 'orange', label: 'Помаранчевий', primary: Color(0xFFFF9800), secondary: Color(0xFFFFEB3B)),
    ThemePreset(id: 'red', label: 'Червоний', primary: Color(0xFFF44336), secondary: Color(0xFFFF6E40)),
    ThemePreset(id: 'mono', label: 'Монохром', primary: Color(0xFF9E9E9E), secondary: Color(0xFFE0E0E0)),
  ];

  static ThemePreset get current =>
      presets.firstWhere((p) => p.id == AppConfig.themeName, orElse: () => presets.first);

  static Color get primary => current.primary;
  static Color get secondary => current.secondary;
}
