import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import '../platform_utils.dart';

/// Конфігурація додатку pro420x1kmuxsk v5.4 (Windows)
/// 
/// Ключі запуску:
///   --help        Показати список ключів
///   --test        Увімкнути тестовий режим
///   --linold      Запустити в мобільному (старому) режимі
///
/// Приклад:
///   muzik420_new.exe --test
///   muzik420_new.exe --linold
///   muzik420_new.exe --help

class AppConfig {
  static bool _testMode = false;
  static bool get testMode => _testMode;

  // На Android за замовчуванням мобільний UI (SongsTab), на Windows —
  // ПК-розкладка (SongsTabDesktop). --linold перемикає вручну.
  static bool _desktopLayout = !isMobilePlatform;
  static bool get desktopLayout => _desktopLayout;

  static bool _wallpaperBg = false;
  static bool get wallpaperBg => _wallpaperBg;

  static bool _firstLaunchDone = false;
  static bool get firstLaunchDone => _firstLaunchDone;
  static Future<void> markFirstLaunchDone() async {
    _firstLaunchDone = true;
    await _save();
  }

  /// Сесійний (не зберігається) прапорець — показує екран першого
  /// запуску примусово, для тестування, незалежно від firstLaunchDone.
  /// Вмикається ключем --startlogo.
  static bool _forceOnboarding = false;
  static bool get forceOnboarding => _forceOnboarding;
  static void dismissForceOnboarding() => _forceOnboarding = false;

  static String _themeName = 'blue'; // ТИМЧАСОВО для тесту — за замовчуванням було 'purple'
  static String get themeName => _themeName;
  static Future<void> setThemeName(String id) async {
    _themeName = id;
    await _save();
  }

  // ===== Персоналізація =====
  static String? _customAppName;
  static String get displayName => (_customAppName != null && _customAppName!.trim().isNotEmpty)
    ? _customAppName!.trim() : 'pro420x1kmuxsk';
  static Future<void> setCustomAppName(String? name) async {
    _customAppName = name;
    await _save();
  }

  static String? _avatarPath;
  static String? get avatarPath => _avatarPath;
  static Future<void> setAvatarPath(String? path) async {
    _avatarPath = path;
    await _save();
  }

  static String _cornerStyle = 'rounded'; // 'rounded' | 'sharp'
  static String get cornerStyle => _cornerStyle;
  static Future<void> setCornerStyle(String style) async {
    _cornerStyle = style;
    await _save();
  }

  static double _textScale = 1.0; // 0.9 компакт / 1.0 звичайний / 1.15 великий
  static double get textScale => _textScale;
  static Future<void> setTextScale(double scale) async {
    _textScale = scale;
    await _save();
  }

  static String _miniPlayerStyle = 'comfortable'; // 'compact' | 'comfortable' | 'large' | 'transparent'
  static String get miniPlayerStyle => _miniPlayerStyle;
  static Future<void> setMiniPlayerStyle(String style) async {
    _miniPlayerStyle = style;
    await _save();
  }

  static String _listDensity = 'comfortable'; // застаріле, лишено для сумісності зі старим config.json
  static double _listDensityScale = 1.0; // 0.75 (компактний) .. 1.4 (великий), керується повзунком
  static double get listDensityScale => _listDensityScale;
  static Future<void> setListDensityScale(double scale) async {
    _listDensityScale = scale;
    await _save();
  }

  static String? _wallpaperPath;
  static String? get wallpaperPath => _wallpaperPath;

  /// Android-аналог "шпалер робочого столу" — тут немає такого
  /// системного поняття, тож користувач вибирає зображення з галереї.
  static String? _bgImagePath;
  static String? get bgImagePath => _bgImagePath;

  /// Уніфікований доступ до фонового зображення незалежно від
  /// платформи — щоб UI-код (main.dart) не розгалужувався сам.
  static bool get hasCustomBackground =>
      isMobilePlatform ? _bgImagePath != null : (_wallpaperBg && _wallpaperPath != null);

  static String? get backgroundImagePath =>
      isMobilePlatform ? _bgImagePath : _wallpaperPath;

  static Future<void> setBgImagePath(String? path) async {
    _bgImagePath = path;
    await _save();
  }

  /// На Android шлях до конфігурації обчислюється асинхронно один раз
  /// при старті (через path_provider) і кешується тут, бо
  /// getApplicationDocumentsDirectory() не має синхронного еквіваленту.
  static String? _androidCfgDir;

  static String get _cfgPath {
    if (isMobilePlatform) {
      final dir = _androidCfgDir ?? '.';
      return '$dir/config.json';
    }
    final appData = Platform.environment['APPDATA'];
    if (appData != null && appData.isNotEmpty) {
      return '$appData/muzik420/config.json';
    }
    // Фолбек, якщо APPDATA чомусь недоступний
    final userProfile = Platform.environment['USERPROFILE'] ?? 'C:/Users/user';
    return '$userProfile/AppData/Roaming/muzik420/config.json';
  }

  /// Показати шлях у людському вигляді для екрану "Про додаток"
  static String get cfgPathDisplay => _cfgPath;

  static String get musicDirDisplay {
    if (Platform.isIOS) {
      return 'Файли → На iPhone → pro420x1kmuxsk';
    }
    if (isMobilePlatform) {
      return 'Android/data/.../files/pro420x1kmuxsk';
    }
    final userProfile = Platform.environment['USERPROFILE'] ?? 'C:/Users/user';
    return '$userProfile/Music/muzik420';
  }

  /// Завантажити конфігурацію + обробити аргументи командного рядка
  static Future<void> load(List<String> args) async {
    // Обробка ключів запуску (актуально лише для Windows/desktop —
    // на Android args завжди порожній список).
    if (args.contains('--help') || args.contains('-help') || args.contains('-h')) {
      _printHelp();
      exit(0);
    }

    if (isMobilePlatform) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        _androidCfgDir = dir.path;
      } catch (e) {
        print('[AppConfig] Android cfg dir error: $e');
      }
    }

    // Завантажуємо збережені налаштування
    try {
      final file = File(_cfgPath);
      if (await file.exists()) {
        final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        _desktopLayout = json['desktopLayout'] as bool? ?? !isMobilePlatform;
        _firstLaunchDone = json['firstLaunchDone'] as bool? ?? false;
        _themeName = json['themeName'] as String? ?? 'purple';
        _customAppName = json['customAppName'] as String?;
        _avatarPath = json['avatarPath'] as String?;
        if (_avatarPath != null && !File(_avatarPath!).existsSync()) _avatarPath = null;
        _cornerStyle = json['cornerStyle'] as String? ?? 'rounded';
        _textScale = (json['textScale'] as num?)?.toDouble() ?? 1.0;
        _miniPlayerStyle = json['miniPlayerStyle'] as String? ?? 'comfortable';
        _listDensity = json['listDensity'] as String? ?? 'comfortable';
        _listDensityScale = (json['listDensityScale'] as num?)?.toDouble() ?? 1.0;
        _wallpaperBg = json['wallpaperBg'] as bool? ?? false;
        _bgImagePath = json['bgImagePath'] as String?;
        if (_bgImagePath != null && !File(_bgImagePath!).existsSync()) {
          _bgImagePath = null;
        }
        // testMode НЕ зберігаємо - тільки через ключ
      }
    } catch (e) {
      print('[AppConfig] Load error: $e');
    }

    // Ключі перезаписують збережені налаштування
    if (args.contains('--test') || args.contains('-test')) {
      _testMode = true;
      print('[AppConfig] ⚠️ ТЕСТОВИЙ РЕЖИМ (--test)');
    }

    if (args.contains('--linold') || args.contains('-linold')) {
      _desktopLayout = false;
      print('[AppConfig] 📱 МОБІЛЬНИЙ РЕЖИМ (--linold)');
    }

    if (args.contains('--startlogo') || args.contains('-startlogo')) {
      _forceOnboarding = true;
      print('[AppConfig] 🧪 Екран першого запуску (--startlogo)');
    }

    if (_wallpaperBg) await _loadWallpaper();
  }

  static void _printHelp() {
    print('''
╔══════════════════════════════════════════════╗
║        pro420x1kmuxsk v5.4 (Windows)        ║
╚══════════════════════════════════════════════╝

Використання:
  muzik420_new.exe [ключі]

Ключі:
  --help     Показати цю довідку і вийти
  --test     Увімкнути тестовий режим (для розробки)
             Показує додаткову інформацію в UI
  --linold   Запустити в мобільному (старому) режимі
             Вимикає ПК дизайн (sidebar, таблиця)
  --startlogo Показати екран першого запуску (для тестування)
             Не впливає на збережений стан firstLaunchDone

Приклади:
  muzik420_new.exe
  muzik420_new.exe --test
  muzik420_new.exe --linold
  muzik420_new.exe --startlogo
  muzik420_new.exe --test --linold

Налаштування зберігаються в:
  %APPDATA%/muzik420/config.json

Музика знаходиться в:
  %USERPROFILE%/Music/muzik420/
''');
  }

  /// Зберегти конфігурацію (без testMode - він тільки через ключ)
  static Future<void> _save() async {
    try {
      final file = File(_cfgPath);
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode({
        'desktopLayout': _desktopLayout,
        'firstLaunchDone': _firstLaunchDone,
        'themeName': _themeName,
        'customAppName': _customAppName,
        'avatarPath': _avatarPath,
        'cornerStyle': _cornerStyle,
        'textScale': _textScale,
        'miniPlayerStyle': _miniPlayerStyle,
        'listDensity': _listDensity,
        'listDensityScale': _listDensityScale,
        'wallpaperBg': _wallpaperBg,
        'bgImagePath': _bgImagePath,
      }));
    } catch (e) {
      print('[AppConfig] Save error: $e');
    }
  }

  /// Перемикачі
  static Future<void> setDesktopLayout(bool value) async {
    _desktopLayout = value;
    await _save();
  }

  static Future<void> setWallpaperBg(bool value) async {
    _wallpaperBg = value;
    if (value) await _loadWallpaper();
    else _wallpaperPath = null;
    await _save();
  }

  /// Завантажити шпалери робочого столу (Windows).
  /// Windows завжди кешує поточні шпалери робочого стола сюди —
  /// не треба ніяких зовнішніх команд (gsettings/magick — то було
  /// з Linux-версії і на Windows не існує).
  /// На Android аналога "шпалер робочого столу" немає — фіча вимкнена.
  static Future<void> _loadWallpaper() async {
    if (!Platform.isWindows) return;
    try {
      final appData = Platform.environment['APPDATA'];
      if (appData == null || appData.isEmpty) {
        print('[AppConfig] Wallpaper: APPDATA недоступний');
        return;
      }
      final cached = '$appData/Microsoft/Windows/Themes/TranscodedWallpaper';
      if (await File(cached).exists()) {
        _wallpaperPath = cached;
        print('[AppConfig] Wallpaper: $_wallpaperPath');
        return;
      }
      print('[AppConfig] Wallpaper: файл кешу шпалер не знайдено');
    } catch (e) {
      print('[AppConfig] Wallpaper error: $e');
    }
  }

  static Future<void> reloadWallpaper() async {
    if (_wallpaperBg) await _loadWallpaper();
  }
}

