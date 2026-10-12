import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../config/app_config.dart';
import '../platform_utils.dart';
import '../google_drive_service.dart';

/// Wizard першого запуску: вітання → де зберігається музика →
/// Google Drive (опційно) → дизайн (шпалери/фон, платформозалежно) →
/// готово. Показується один раз, доки AppConfig.firstLaunchDone == false.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;
  bool _signingIn = false;

  static const _total = 4;

  void _next() {
    if (_page < _total - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    await AppConfig.markFirstLaunchDone();
    AppConfig.dismissForceOnboarding();
    widget.onDone();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0A0A0F),
    body: SafeArea(child: Column(children: [
      const SizedBox(height: 12),
      // Індикатор кроків
      Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(_total, (i) =>
        AnimatedContainer(duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: i == _page ? 22 : 8, height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: i <= _page ? const Color(0xFF7C5CFC) : const Color(0xFF2A2A40))))),
      Expanded(child: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (i) => setState(() => _page = i),
        children: [
          _WelcomeStep(onNext: _next),
          _MusicFolderStep(onNext: _next),
          _GoogleDriveStep(onNext: _next, signingIn: _signingIn,
            onSignIn: () async {
              setState(() => _signingIn = true);
              await GoogleDriveService.signIn();
              if (mounted) setState(() => _signingIn = false);
            }),
          _DesignStep(onFinish: _finish),
        ])),
    ])));
}

class _StepScaffold extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? extra;
  final String buttonLabel;
  final VoidCallback onNext;
  final Widget? secondaryAction;

  const _StepScaffold({required this.icon, required this.iconColor, required this.title,
    required this.subtitle, this.extra, required this.buttonLabel, required this.onNext,
    this.secondaryAction});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 32),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 96, height: 96,
        decoration: BoxDecoration(shape: BoxShape.circle,
          gradient: LinearGradient(colors: [iconColor.withOpacity(0.25), iconColor.withOpacity(0.05)]),
          border: Border.all(color: iconColor.withOpacity(0.4))),
        child: Icon(icon, size: 44, color: iconColor)),
      const SizedBox(height: 28),
      Text(title, textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
      const SizedBox(height: 10),
      Text(subtitle, textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 14, color: Color(0xFF9A9AB8), height: 1.4)),
      if (extra != null) ...[const SizedBox(height: 20), extra!],
      const SizedBox(height: 36),
      SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
        onPressed: onNext,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7C5CFC), foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0),
        child: Text(buttonLabel, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)))),
      if (secondaryAction != null) ...[const SizedBox(height: 10), secondaryAction!],
      const SizedBox(height: 24),
    ]));
}

class _WelcomeStep extends StatelessWidget {
  final VoidCallback onNext;
  const _WelcomeStep({required this.onNext});
  @override
  Widget build(BuildContext context) => _StepScaffold(
    icon: Icons.music_note_rounded, iconColor: const Color(0xFF7C5CFC),
    title: 'Вітаємо в pro420x1kmuxsk',
    subtitle: 'Твій особистий музичний плеєр — з завантаженням із YouTube/TikTok, '
      'плейлистами й резервним копіюванням у Google Drive.\n\nНалаштуємо кілька речей за хвилину.',
    buttonLabel: 'Почати', onNext: onNext);
}

class _MusicFolderStep extends StatelessWidget {
  final VoidCallback onNext;
  const _MusicFolderStep({required this.onNext});
  @override
  Widget build(BuildContext context) => _StepScaffold(
    icon: Icons.folder_rounded, iconColor: const Color(0xFF4CAF50),
    title: 'Де зберігається музика',
    subtitle: 'Всі завантажені пісні й обкладинки автоматично зберігаються тут:',
    extra: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF12121E), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A40))),
      child: Text(AppConfig.musicDirDisplay, textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, color: Color(0xFF7C5CFC), fontFamily: 'monospace'))),
    buttonLabel: 'Далі', onNext: onNext);
}

class _GoogleDriveStep extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onSignIn;
  final bool signingIn;
  const _GoogleDriveStep({required this.onNext, required this.onSignIn, required this.signingIn});
  @override
  Widget build(BuildContext context) => _StepScaffold(
    icon: Icons.cloud_rounded, iconColor: const Color(0xFF2196F3),
    title: 'Резервне копіювання',
    subtitle: GoogleDriveService.isSignedIn
      ? 'Вхід виконано: ${GoogleDriveService.userEmail ?? ""}\nТвої плейлисти можна зберігати в Google Drive.'
      : 'Увійди через Google, щоб мати змогу зберігати й відновлювати плейлисти з Google Drive. '
        'Можна зробити це й пізніше в Налаштуваннях.',
    buttonLabel: GoogleDriveService.isSignedIn ? 'Далі' : 'Пропустити',
    onNext: onNext,
    secondaryAction: GoogleDriveService.isSignedIn ? null : TextButton(
      onPressed: signingIn ? null : onSignIn,
      child: signingIn
        ? const SizedBox(width: 18, height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2196F3)))
        : const Text('Увійти через Google', style: TextStyle(color: Color(0xFF2196F3)))));
}

class _DesignStep extends StatefulWidget {
  final VoidCallback onFinish;
  const _DesignStep({required this.onFinish});
  @override
  State<_DesignStep> createState() => _DesignStepState();
}

class _DesignStepState extends State<_DesignStep> {
  @override
  Widget build(BuildContext context) => _StepScaffold(
    icon: Icons.palette_rounded, iconColor: const Color(0xFFFC5C9C),
    title: 'Готово!',
    subtitle: Platform.isWindows
      ? 'Можеш увімкнути шпалери робочого столу як фон плеєра прямо зараз — або будь-коли пізніше в Налаштуваннях.'
      : 'Можеш вибрати зображення з галереї як фон плеєра прямо зараз — або будь-коли пізніше в Налаштуваннях.',
    extra: Platform.isWindows
      ? _WallpaperToggleInline(onChanged: () => setState(() {}))
      : _BgImagePickerInline(onChanged: () => setState(() {})),
    buttonLabel: 'Почати користуватись', onNext: widget.onFinish);
}

class _WallpaperToggleInline extends StatelessWidget {
  final VoidCallback onChanged;
  const _WallpaperToggleInline({required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    decoration: BoxDecoration(color: const Color(0xFF12121E), borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF2A2A40))),
    child: Row(children: [
      const Expanded(child: Text('Шпалери як фон', style: TextStyle(fontSize: 13, color: Colors.white))),
      Switch(value: AppConfig.wallpaperBg, activeColor: const Color(0xFF7C5CFC),
        onChanged: (v) async { await AppConfig.setWallpaperBg(v); onChanged(); }),
    ]));
}

class _BgImagePickerInline extends StatelessWidget {
  final VoidCallback onChanged;
  const _BgImagePickerInline({required this.onChanged});
  @override
  Widget build(BuildContext context) => Material(color: Colors.transparent, child: InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: () async {
      final img = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90);
      if (img != null) { await AppConfig.setBgImagePath(await persistPickedImage(img.path, 'bg_image')); onChanged(); }
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: const Color(0xFF12121E), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A40))),
      child: Row(children: [
        const Icon(Icons.image_rounded, color: Color(0xFF4CAF50), size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(AppConfig.bgImagePath != null ? 'Зображення вибрано ✓' : 'Обрати зображення з галереї',
          style: const TextStyle(fontSize: 13, color: Colors.white))),
      ]))));
}
