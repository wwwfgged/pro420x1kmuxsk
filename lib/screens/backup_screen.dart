import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/song.dart';
import '../google_drive_service.dart';
import '../download_core.dart';
import '../config/app_config.dart';
import 'songs_tab_desktop.dart' show AeroColors, AeroGlass;

/// Окремий екран "Бекап та відновлення" — усе, що стосується Google Drive:
/// вхід/вихід, створення бекапу, відновлення, видалення бекапу з Drive.
class BackupScreen extends StatefulWidget {
  final List<Song> songs;
  final List<MusicPlaylist> playlists;
  final VoidCallback onDataChanged;
  const BackupScreen({super.key, required this.songs, required this.playlists,
    required this.onDataChanged});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _googleBusy = false;
  bool _opRunning = false;
  String _opStatus = '';
  double _opProgress = 0;
  bool _infoLoading = false;
  ({bool exists, int fileCount})? _backupInfo;

  @override
  void initState() {
    super.initState();
    if (GoogleDriveService.isSignedIn) _refreshBackupInfo();
  }

  Future<void> _refreshBackupInfo() async {
    setState(() => _infoLoading = true);
    final info = await GoogleDriveService.getBackupInfo();
    if (mounted) setState(() { _backupInfo = info; _infoLoading = false; });
  }

  Future<void> _handleGoogleConnect() async {
    if (GoogleDriveService.isSignedIn) {
      final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF12121A),
        content: const Text('Відключити Google акаунт?', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: const Text('Скасувати', style: TextStyle(color: Color(0xFF6A6A88)))),
          TextButton(onPressed: () => Navigator.pop(context, true),
            child: const Text('Відключити', style: TextStyle(color: Colors.red))),
        ]));
      if (ok == true) {
        await GoogleDriveService.signOut();
        if (mounted) setState(() => _backupInfo = null);
      }
      return;
    }

    setState(() => _googleBusy = true);
    try {
      final ok = await GoogleDriveService.signIn();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok ? '✅ Google акаунт підключено: ${GoogleDriveService.userEmail ?? ""}'
                            : '❌ Не вдалось увійти'),
          backgroundColor: ok ? const Color(0xFF4CAF50) : Colors.red,
          behavior: SnackBarBehavior.floating));
      }
      if (ok) await _refreshBackupInfo();
    } finally {
      if (mounted) setState(() => _googleBusy = false);
    }
  }

  Future<void> _handleBackup() async {
    setState(() { _opRunning = true; _opStatus = 'Починаю бекап...'; _opProgress = 0; });
    try {
      final base = await getMusicDir();
      final sourcesFile = File('${base.path}/${SourceStore.fileNameOf()}');
      final sources = await SourceStore.readAll(sourcesFile);

      final ok = await GoogleDriveService.backup(
        songs: widget.songs,
        playlists: widget.playlists,
        sources: sources,
        onProgress: (status, progress) {
          if (mounted) setState(() { _opStatus = status; _opProgress = progress; });
        });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok ? '✅ Бекап завершено' : '❌ Бекап не вдався'),
          backgroundColor: ok ? const Color(0xFF4CAF50) : Colors.red,
          behavior: SnackBarBehavior.floating));
      }
      if (ok) await _refreshBackupInfo();
    } finally {
      if (mounted) setState(() => _opRunning = false);
    }
  }

  Future<void> _handleRestore() async {
    final confirm = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF12121A),
      title: const Text('Відновити з бекапу?', style: TextStyle(color: Colors.white)),
      content: const Text(
        'Пісні з посиланням будуть перекачані заново, решта — завантажена з Drive. '
        'Це може зайняти багато часу залежно від розміру бібліотеки.',
        style: TextStyle(color: Color(0xFF9A9AB0))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false),
          child: const Text('Скасувати', style: TextStyle(color: Color(0xFF6A6A88)))),
        TextButton(onPressed: () => Navigator.pop(context, true),
          child: Text('Відновити', style: TextStyle(color: AeroColors.primary))),
      ]));
    if (confirm != true) return;

    setState(() { _opRunning = true; _opStatus = 'Починаю відновлення...'; _opProgress = 0; });
    try {
      final ok = await GoogleDriveService.restore(
        onProgress: (status, progress) {
          if (mounted) setState(() { _opStatus = status; _opProgress = progress; });
        });

      widget.onDataChanged();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok ? '✅ Відновлення завершено' : '❌ Відновлення не вдалось'),
          backgroundColor: ok ? const Color(0xFF4CAF50) : Colors.red,
          behavior: SnackBarBehavior.floating));
      }
    } finally {
      if (mounted) setState(() => _opRunning = false);
    }
  }

  Future<void> _handleDeleteBackup() async {
    final confirm = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF12121A),
      title: const Text('Видалити бекап з Drive?', style: TextStyle(color: Colors.white)),
      content: Text(
        'Буде видалено всю папку "muzik420_backup" разом з усіма файлами '
        '(${_backupInfo?.fileCount ?? "?"} шт.) на Google Drive. Локальні файли не постраждають. '
        'Дію неможливо скасувати.',
        style: const TextStyle(color: Color(0xFF9A9AB0))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false),
          child: const Text('Скасувати', style: TextStyle(color: Color(0xFF6A6A88)))),
        TextButton(onPressed: () => Navigator.pop(context, true),
          child: const Text('Видалити', style: TextStyle(color: Colors.red))),
      ]));
    if (confirm != true) return;

    setState(() { _opRunning = true; _opStatus = 'Видаляю бекап...'; _opProgress = 0; });
    try {
      final ok = await GoogleDriveService.deleteBackup();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok ? '✅ Бекап видалено' : '❌ Не вдалось видалити'),
          backgroundColor: ok ? const Color(0xFF4CAF50) : Colors.red,
          behavior: SnackBarBehavior.floating));
      }
      if (ok) await _refreshBackupInfo();
    } finally {
      if (mounted) setState(() => _opRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = GoogleDriveService.isSignedIn;
    final hasWallpaper = AppConfig.wallpaperBg && AppConfig.wallpaperPath != null;
    return Stack(children: [
      // Цей екран — окремий Navigator.push route (непрозорий за замовчуванням,
      // тому головний фон з MainScreen НЕ просвічує крізь нього). Тому тут
      // власна копія того самого матового шару шпалер.
      if (hasWallpaper) ...[
        Positioned.fill(child: Image.file(
          File(AppConfig.wallpaperPath!), fit: BoxFit.cover)),
        Positioned.fill(child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(color: Colors.black.withOpacity(0.55)))),
      ],
      Container(
        decoration: hasWallpaper ? null : const BoxDecoration(gradient: LinearGradient(
          colors: [Color(0xFF0A0A14), Color(0xFF0D0A18)],
          begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: SafeArea(child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context)),
            const SizedBox(width: 4),
            const Text('Бекап та відновлення',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800,
                decoration: TextDecoration.none)),
          ])),
        Expanded(child: ListView(padding: const EdgeInsets.all(20), children: [
          const Text('GOOGLE АКАУНТ', style: TextStyle(
            color: Color(0xFF6A6A88), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5,
            decoration: TextDecoration.none)),
          const SizedBox(height: 8),
          AeroGlass(padding: EdgeInsets.zero, borderRadius: BorderRadius.circular(12),
            child: _Tile(
              icon: signedIn ? Icons.check_circle_rounded : Icons.account_circle_rounded,
              iconColor: signedIn ? const Color(0xFF4CAF50) : const Color(0xFF6A6A88),
              title: signedIn ? (GoogleDriveService.userEmail ?? 'Підключено') : 'Не підключено',
              subtitle: signedIn ? 'Натисни, щоб відключити' : 'Натисни, щоб підключити',
              trailing: _googleBusy ? SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: AeroColors.primary)) : null,
              onTap: _googleBusy ? null : _handleGoogleConnect)),

          const SizedBox(height: 20),
          const Text('РЕЗЕРВНА КОПІЯ', style: TextStyle(
            color: Color(0xFF6A6A88), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5,
            decoration: TextDecoration.none)),
          const SizedBox(height: 8),
          AeroGlass(padding: EdgeInsets.zero, borderRadius: BorderRadius.circular(12),
            child: Column(children: [
              _Tile(icon: Icons.cloud_upload_rounded,
                iconColor: signedIn ? AeroColors.primary : const Color(0xFF3A3A50),
                title: 'Зробити бекап',
                subtitle: signedIn
                  ? '${widget.songs.length} пісень, ${widget.playlists.length} плейлістів'
                  : 'Спершу підключи акаунт',
                onTap: (signedIn && !_opRunning) ? _handleBackup : null),
              const Divider(color: Color(0xFF2A2A40), height: 1, indent: 14, endIndent: 14),
              _Tile(icon: Icons.cloud_download_rounded,
                iconColor: signedIn ? AeroColors.secondary : const Color(0xFF3A3A50),
                title: 'Відновити',
                subtitle: signedIn ? 'Завантажити бекап з Drive' : 'Спершу підключи акаунт',
                onTap: (signedIn && !_opRunning) ? _handleRestore : null),
              if (signedIn) ...[
                const Divider(color: Color(0xFF2A2A40), height: 1, indent: 14, endIndent: 14),
                _Tile(icon: Icons.delete_forever_rounded,
                  iconColor: (_backupInfo?.exists ?? false) ? Colors.red : const Color(0xFF3A3A50),
                  title: 'Видалити бекап з Drive',
                  subtitle: _infoLoading
                    ? 'Перевіряю...'
                    : (_backupInfo?.exists ?? false)
                      ? '${_backupInfo!.fileCount} файлів на Drive'
                      : 'Бекапу ще немає',
                  onTap: (!_opRunning && (_backupInfo?.exists ?? false)) ? _handleDeleteBackup : null),
              ],
            ])),

          if (_opRunning) Padding(
            padding: const EdgeInsets.only(top: 16),
            child: AeroGlass(padding: const EdgeInsets.all(14), borderRadius: BorderRadius.circular(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_opStatus, style: const TextStyle(color: Colors.white, fontSize: 13),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                ClipRRect(borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: _opProgress > 0 ? _opProgress : null,
                    backgroundColor: Colors.white.withOpacity(0.08),
                    valueColor: AlwaysStoppedAnimation(AeroColors.primary), minHeight: 4)),
              ]))),

          const SizedBox(height: 20),
          AeroGlass(padding: const EdgeInsets.all(12), borderRadius: BorderRadius.circular(10),
            color: Colors.blue.withOpacity(0.08),
            child: const Row(children: [
              Icon(Icons.info_outline_rounded, color: Colors.blue, size: 16),
              SizedBox(width: 8),
              Expanded(child: Text(
                'Пісні, завантажені з YouTube/TikTok, зберігаються в бекапі як посилання '
                '(не файлом) — це швидше й економить місце на Drive.',
                style: TextStyle(color: Colors.blue, fontSize: 11))),
            ])),
        ])),
      ])),
      ),
    ]);
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title, subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _Tile({required this.icon, required this.iconColor,
    required this.title, required this.subtitle, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) => Material(color: Colors.transparent,
    child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12),
    child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Row(children: [
      Container(width: 38, height: 38,
        decoration: BoxDecoration(color: iconColor.withOpacity(0.12), borderRadius: BorderRadius.circular(9)),
        child: Icon(icon, color: iconColor, size: 19)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
        Text(subtitle, style: const TextStyle(color: Color(0x886A6A88), fontSize: 12)),
      ])),
      if (trailing != null) trailing!,
    ]))));
}
