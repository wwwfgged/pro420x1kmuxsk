import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/song.dart';
import '../download_core.dart';

class DownloadTab extends StatelessWidget {
  final VoidCallback onSongAdded;
  const DownloadTab({super.key, required this.onSongAdded});

  @override
  Widget build(BuildContext context) => SafeArea(child: Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ShaderMask(
          shaderCallback: (b) => const LinearGradient(
            colors: [Color(0xFF7C5CFC), Color(0xFFFC5C9C)]).createShader(b),
          child: const Text('Завантажити',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white))),
        const Text('pro420x1kmuxsk v5.1',
          style: TextStyle(color: Color(0xFF6A6A88), fontSize: 11)),
      ])),
    Expanded(child: UniversalDownloader(onSongAdded: onSongAdded)),
  ]));
}

class UniversalDownloader extends StatefulWidget {
  final VoidCallback onSongAdded;
  const UniversalDownloader({super.key, required this.onSongAdded});

  @override
  State<UniversalDownloader> createState() => _UniversalDownloaderState();
}

class _UniversalDownloaderState extends State<UniversalDownloader> {
  final _ctrl = TextEditingController();
  final _plCtrl = TextEditingController();
  bool _loading = false;
  String _status = '';
  String? _thumbUrl;
  double _progress = 0;
  String _progressText = '';

  bool get _isYtPlaylist => _ctrl.text.contains('playlist?list=') ||
    (_ctrl.text.contains('youtube') && _ctrl.text.contains('list='));
  bool get _isYt => _ctrl.text.contains('youtube.com') || _ctrl.text.contains('youtu.be');
  bool get _isTt => _ctrl.text.contains('tiktok.com');

  String get _detectedType {
    final url = _ctrl.text.trim();
    if (url.isEmpty) return '';
    if (url.contains('tiktok.com')) return 'TikTok відео';
    if (_isYtPlaylist) return 'YouTube Плейліст';
    if (url.contains('youtube.com') || url.contains('youtu.be')) return 'YouTube Відео';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final type = _detectedType;
    return SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(decoration: BoxDecoration(color: const Color(0xFF12121A),
          borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF2A2A40))),
          child: TextField(controller: _ctrl, style: const TextStyle(color: Colors.white, fontSize: 14),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Вставте посилання YouTube або TikTok',
              hintStyle: TextStyle(color: Color(0xFF6A6A88), fontSize: 13),
              prefixIcon: Icon(Icons.link_rounded, color: Color(0xFF7C5CFC)),
              border: InputBorder.none, contentPadding: EdgeInsets.all(16)))),
        if (type.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF7C5CFC).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF7C5CFC).withOpacity(0.3))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.auto_awesome_rounded, color: Color(0xFF7C5CFC), size: 14),
              const SizedBox(width: 6),
              Text('Визначено: $type',
                style: const TextStyle(color: Color(0xFF7C5CFC), fontSize: 12, fontWeight: FontWeight.w600)),
            ])),
        ],
        if (_isYtPlaylist) ...[
          const SizedBox(height: 12),
          const Text('Назва папки (плейлісту)', style: TextStyle(color: Color(0xFF6A6A88), fontSize: 13)),
          const SizedBox(height: 8),
          Container(decoration: BoxDecoration(color: const Color(0xFF12121A),
            borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF2A2A40))),
            child: TextField(controller: _plCtrl, style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Назва плейлісту...',
                hintStyle: TextStyle(color: Color(0xFF6A6A88), fontSize: 13),
                prefixIcon: Icon(Icons.folder_rounded, color: Color(0xFFFC5C9C)),
                border: InputBorder.none, contentPadding: EdgeInsets.all(16)))),
        ],
        const SizedBox(height: 14),
        GestureDetector(onTap: _loading ? null : _download,
          child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: _loading ? null : const LinearGradient(colors: [Color(0xFF7C5CFC), Color(0xFFFC5C9C)]),
              color: _loading ? const Color(0xFF2A2A40) : null,
              borderRadius: BorderRadius.circular(16)),
            child: Center(child: _loading
              ? Row(mainAxisSize: MainAxisSize.min, children: [
                  const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C5CFC))),
                  const SizedBox(width: 12),
                  Text('Завантаження... $_progressText',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ])
              : const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.download_rounded, color: Colors.white), SizedBox(width: 8),
                  Text('Завантажити', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                ])))),
        if (_loading && _progress > 0) ...[
          const SizedBox(height: 12),
          ClipRRect(borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: _progress,
              backgroundColor: const Color(0xFF2A2A40),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF7C5CFC)), minHeight: 8)),
          const SizedBox(height: 6),
          Text('${(_progress * 100).toInt()}%  $_progressText',
            style: const TextStyle(color: Color(0xFF6A6A88), fontSize: 12)),
        ],
        if (_thumbUrl != null) ...[
          const SizedBox(height: 16),
          ClipRRect(borderRadius: BorderRadius.circular(16),
            child: Image.network(_thumbUrl!, width: double.infinity, height: 170, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink())),
        ],
        if (_status.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFF12121A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF2A2A40))),
            child: Text(_status,
              style: const TextStyle(color: Color(0xFFE8E8F0), fontSize: 13, height: 1.6))),
        ],
      ]));
  }

  Future<void> _download() async {
    final url = _ctrl.text.trim();
    if (url.isEmpty) { setState(() => _status = '⚠️ Вставте посилання'); return; }
    if (_isYtPlaylist) {
      await _downloadYtPlaylist(url);
    } else if (_isYt) {
      await _downloadYtVideo(url);
    } else if (_isTt) {
      await _downloadTikTok(url);
    } else {
      setState(() => _status = '⚠️ Не розпізнано. Підтримується: YouTube, YouTube Playlist, TikTok');
    }
  }

  Future<void> _downloadYtVideo(String url) async {
    setState(() { _loading = true; _status = 'Підключаюсь...'; _progress = 0.05; _thumbUrl = null; });
    try {
      // Показуємо мініатюру якомога раніше (окремим швидким запитом),
      // сама логіка завантаження — у спільній download_core.dart,
      // яку так само використовує відновлення з Google Drive.
      final yt = YoutubeExplode();
      try {
        final video = await yt.videos.get(url);
        if (mounted) setState(() => _thumbUrl = video.thumbnails.highResUrl);
      } catch (_) {} finally { yt.close(); }

      final path = await downloadYoutubeVideo(url, onProgress: (status, progress) {
        if (mounted) setState(() { _status = status; _progress = progress; });
      });

      if (path != null) {
        widget.onSongAdded();
      } else {
        setState(() => _loading = false);
      }
      if (mounted && path != null) setState(() => _loading = false);
    } catch (e) {
      setState(() { _status = '❌ Помилка: $e'; _loading = false; _progress = 0; });
    }
  }

  Future<void> _downloadYtPlaylist(String url) async {
    final plName = _plCtrl.text.trim();
    if (plName.isEmpty) { setState(() => _status = '⚠️ Введіть назву папки плейлісту'); return; }
    setState(() { _loading = true; _status = 'Отримую плейліст...'; _progress = 0.05; _thumbUrl = null; });
    final yt = YoutubeExplode();
    try {
      final base = await getMusicDir();
      final plDir = Directory('${base.path}/$plName');
      if (!await plDir.exists()) await plDir.create();
      final playlist = await yt.playlists.get(url);
      final videos = await yt.playlists.getVideos(playlist.id).toList();
      final total = videos.length;
      setState(() {
        _status = 'Знайдено: "${playlist.title}"\n$total відео';
        _progress = 0.10;
        _thumbUrl = videos.isNotEmpty ? videos.first.thumbnails.highResUrl : null;
      });
      int done = 0;
      for (final v in videos) {
        if (!mounted) break;
        setState(() {
          _status = '[${done+1}/$total] ${v.title}';
          _progress = 0.10 + (done / total) * 0.88;
          _progressText = '${done+1}/$total';
        });
        try {
          final safe = v.title.replaceAll(RegExp(r'[<>:"/\\|?*#]'), '').trim();
          try {
            final t = await http.get(Uri.parse(v.thumbnails.highResUrl)).timeout(const Duration(seconds: 8));
            if (t.statusCode == 200) await File('${plDir.path}/$safe.jpg').writeAsBytes(t.bodyBytes);
          } catch (_) {}
          StreamManifest manifest;
          try {
            manifest = await yt.videos.streams.getManifest(v.id,
              ytClients: [YoutubeApiClient.androidVr, YoutubeApiClient.safari, YoutubeApiClient.ios]);
          } catch (_) { manifest = await yt.videos.streams.getManifest(v.id); }
          StreamInfo? info;
          String fp;
          if (manifest.muxed.isNotEmpty) {
            info = manifest.muxed.sortByVideoQuality().first; fp = '${plDir.path}/$safe.mp4';
          } else if (manifest.audioOnly.isNotEmpty) {
            info = manifest.audioOnly.withHighestBitrate(); fp = '${plDir.path}/$safe.mp4';
          } else { done++; continue; }
          final sink = File(fp).openWrite();
          await for (final chunk in yt.videos.streams.get(info)) { sink.add(chunk); }
          await sink.flush(); await sink.close();
          try {
            final sourcesFile = File('${base.path}/${SourceStore.fileNameOf()}');
            await SourceStore.set(sourcesFile, fp, 'https://youtube.com/watch?v=${v.id.value}');
          } catch (_) {}
        } catch (_) {}
        done++;
      }
      setState(() {
        _status = '✅ Плейліст "$plName" завантажено!\n$done/$total відео';
        _progress = 1.0; _progressText = ''; _loading = false;
      });
      widget.onSongAdded();
    } catch (e) {
      setState(() { _status = '❌ Помилка: $e'; _loading = false; _progress = 0; });
    } finally { yt.close(); }
  }

  Future<void> _downloadTikTok(String url) async {
    setState(() { _loading = true; _status = 'Підключаюсь до TikTok...'; _progress = 0.05; _thumbUrl = null; });
    try {
      final path = await downloadTikTokVideo(url, onProgress: (status, progress) {
        if (mounted) setState(() { _status = status; _progress = progress; });
      });
      if (path != null) {
        widget.onSongAdded();
      }
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      setState(() { _status = '❌ Помилка: $e'; _loading = false; _progress = 0; });
    }
  }
}
