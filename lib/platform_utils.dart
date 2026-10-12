import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Мобільна платформа (Android або iOS) — для всіх місць, де код раніше
/// перевіряв лише Platform.isAndroid і на iPhone помилково потрапляв у
/// "десктопну" гілку (ПК-розкладка, шлях %APPDATA%, шпалери Windows тощо).
bool get isMobilePlatform => Platform.isAndroid || Platform.isIOS;

/// Назва платформи для екрану "Про додаток".
String get platformLabel =>
    Platform.isAndroid ? 'Android' : (Platform.isIOS ? 'iOS' : 'Windows');

/// image_picker повертає файл у ТИМЧАСОВІЙ теці (кеш), який система
/// може очистити — через це фон/аватар "зникали" після перезапуску.
/// Копіюємо вибране зображення в постійну теку застосунку і повертаємо
/// новий шлях. Ім'я з міткою часу, щоб Image.file не показував старий кеш.
Future<String> persistPickedImage(String sourcePath, String name) async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final dot = sourcePath.lastIndexOf('.');
    final ext = dot >= 0 ? sourcePath.substring(dot + 1).toLowerCase() : 'jpg';
    final dest = '${dir.path}/${name}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await File(sourcePath).copy(dest);
    return dest;
  } catch (_) {
    return sourcePath;
  }
}
