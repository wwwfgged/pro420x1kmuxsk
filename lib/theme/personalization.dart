import '../config/app_config.dart';

/// Централізовані радіуси заокруглення — читаються з обраного стилю
/// (AppConfig.cornerStyle: 'rounded' | 'sharp'). Використовується як
/// дефолт у AeroGlass та ключових картках (мініплеєр, картки пісень,
/// налаштування), а не як абсолютна заміна КОЖНОГО BorderRadius у
/// застосунку (декоративні дрібні елементи — бейджі, індикатори —
/// лишаються як є).
class AppRadius {
  static bool get _sharp => AppConfig.cornerStyle == 'sharp';

  static double get card => _sharp ? 4 : 16;
  static double get button => _sharp ? 4 : 14;
  static double get sheet => _sharp ? 8 : 20;
  static double get chip => _sharp ? 3 : 12;
  static double get avatar => _sharp ? 6 : 999; // 999 ~ повне коло для аватарки
}

/// Щільність списку пісень — тепер неперервна (керується повзунком),
/// а не 3 фіксовані пресети. scale: 0.75 (компактний) .. 1.4 (великий).
class ListDensity {
  static double get scale => AppConfig.listDensityScale;

  static double get tileHeight => 44 + 32 * ((scale - 0.75) / 0.65).clamp(0.0, 1.0);
  static double get coverSize => 32 + 24 * ((scale - 0.75) / 0.65).clamp(0.0, 1.0);
  static double get titleFontSize => 12 + 4 * ((scale - 0.75) / 0.65).clamp(0.0, 1.0);
  static double get verticalPadding => 3 + 8 * ((scale - 0.75) / 0.65).clamp(0.0, 1.0);
}

/// Пресети стилю мініплеєра (докований знизу, мобільний UI).
class MiniPlayerStyle {
  static String get current => AppConfig.miniPlayerStyle;

  static bool get isCompact => current == 'compact';
  static bool get isLarge => current == 'large';
  static bool get isTransparent => current == 'transparent';

  static double get coverSize => isCompact ? 32 : (isLarge ? 52 : 40);
  static double get height => isCompact ? 56 : (isLarge ? 88 : 72);
  static double get backgroundOpacity => isTransparent ? 0.35 : 0.85;
}
