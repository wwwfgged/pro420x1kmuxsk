import 'dart:io';

/// Визначає РЕАЛЬНИЙ формат аудіофайлу за першими байтами (а не за
/// розширенням). Повертає: mp4 | m4a | mp3 | aac | ogg | webm, або null.
///
/// Навіщо: TikTok віддає звук (music_info.play) як голий mp3/aac без
/// розширення в URL, а код зберігав його як ".mp4". Windows і Android
/// визначають формат за вмістом і відтворюють таке, а iOS (AVPlayer)
/// довіряє розширенню — mp3 під іменем .mp4 дає помилку -11829
/// "Не вдається відкрити".
Future<String?> sniffAudioExt(String path) async {
  try {
    final raf = await File(path).open();
    final b = await raf.read(16);
    await raf.close();
    if (b.length < 12) return null;
    String s(int from, int to) => String.fromCharCodes(b.sublist(from, to));
    if (s(4, 8) == 'ftyp') return s(8, 12) == 'M4A ' ? 'm4a' : 'mp4';
    if (s(0, 3) == 'ID3') return 'mp3';
    if (s(0, 4) == 'OggS') return 'ogg';
    if (b[0] == 0x1A && b[1] == 0x45 && b[2] == 0xDF && b[3] == 0xA3) return 'webm';
    if (b[0] == 0xFF && (b[1] & 0xE0) == 0xE0) {
      // Біти шару (layer) == 00 → це ADTS AAC, інакше MPEG audio (mp3).
      return (b[1] & 0x06) == 0 ? 'aac' : 'mp3';
    }
    return null;
  } catch (_) {
    return null;
  }
}

/// mp4 і m4a — один і той самий контейнер, між собою взаємозамінні.
bool sameAudioKind(String a, String b) {
  const mp4 = {'mp4', 'm4a'};
  return a == b || (mp4.contains(a) && mp4.contains(b));
}

String extensionOf(String path) {
  final dot = path.lastIndexOf('.');
  return dot >= 0 ? path.substring(dot + 1).toLowerCase() : '';
}

/// Якщо розширення не збігається з реальним форматом — перейменовує файл
/// і повертає новий шлях (інакше повертає той самий).
Future<String> fixAudioExtension(String path) async {
  final real = await sniffAudioExt(path);
  if (real == null || sameAudioKind(extensionOf(path), real)) return path;
  final dot = path.lastIndexOf('.');
  final newPath = '${dot >= 0 ? path.substring(0, dot) : path}.$real';
  try {
    final target = File(newPath);
    if (await target.exists()) await target.delete();
    await File(path).rename(newPath);
    return newPath;
  } catch (_) {
    return path;
  }
}
