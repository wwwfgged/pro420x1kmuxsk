import 'dart:io';
import 'package:flutter/material.dart';
import '../models/song.dart';
import '../widgets/song_tile.dart';
import '../widgets/common.dart';
import '../config/app_config.dart';
import '../theme/app_theme.dart';
import '../theme/personalization.dart';

class SongsTab extends StatelessWidget {
  final List<Song> songs;
  final List<MusicPlaylist> playlists;
  final Song? currentSong;
  final Function(Song) onPlay;
  final Function(Song, MusicPlaylist) onPlayPlaylist;
  final VoidCallback onRefresh;
  final bool editMode;
  final VoidCallback onToggleEdit;
  final Function(Song, {bool inPlaylist}) onSongMenu;
  final VoidCallback onCreatePlaylist;
  final Function(MusicPlaylist) onDeletePlaylist;
  final VoidCallback onVersionTap;

  const SongsTab({super.key,
    required this.songs, required this.playlists, this.currentSong,
    required this.onPlay, required this.onPlayPlaylist, required this.onRefresh,
    required this.editMode, required this.onToggleEdit, required this.onSongMenu,
    required this.onCreatePlaylist, required this.onDeletePlaylist,
    required this.onVersionTap,
  });

  void _showHeaderMenu(BuildContext context) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(color: Color(0xFF12121A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: const Color(0xFF2A2A40), borderRadius: BorderRadius.circular(2))),
          MenuTile(icon: Icons.create_new_folder_rounded, color: const Color(0xFFFC5C9C),
            label: 'Новий плейліст',
            onTap: () { Navigator.pop(context); onCreatePlaylist(); }),
          MenuTile(icon: Icons.refresh_rounded, color: const Color(0xFF4CAF50),
            label: 'Оновити список',
            onTap: () { Navigator.pop(context); onRefresh(); }),
        ])));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(child: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Row(children: [
          if (AppConfig.avatarPath != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.avatar > 100 ? 100 : AppRadius.avatar),
              child: Image.file(File(AppConfig.avatarPath!), width: 28, height: 28, fit: BoxFit.cover)),
            const SizedBox(width: 8),
          ],
          ShaderMask(
            shaderCallback: (b) => LinearGradient(
              colors: [AppTheme.primary, AppTheme.secondary]).createShader(b),
            child: Text(AppConfig.displayName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white))),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onVersionTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Text('v5.1',
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11, fontFamily: 'monospace')),
            ),
          ),
          const Spacer(),
          GestureDetector(onTap: onToggleEdit, child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: editMode ? const Color(0xFF7C5CFC).withOpacity(0.2) : Colors.transparent,
              border: Border.all(color: editMode ? const Color(0xFF7C5CFC) : const Color(0xFF2A2A40)),
              borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(editMode ? Icons.check_rounded : Icons.edit_rounded,
                color: editMode ? const Color(0xFF7C5CFC) : const Color(0xFF6A6A88), size: 15),
              const SizedBox(width: 4),
              Text(editMode ? 'Готово' : 'Ред.', style: TextStyle(
                color: editMode ? const Color(0xFF7C5CFC) : const Color(0xFF6A6A88),
                fontSize: 12, fontWeight: FontWeight.w600)),
            ]))),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF6A6A88), size: 24),
            padding: EdgeInsets.zero, constraints: const BoxConstraints(),
            onPressed: () => _showHeaderMenu(context)),
        ])),
      const SizedBox(height: 8),
      Expanded(child: (songs.isEmpty && playlists.isEmpty)
        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(color: const Color(0xFF12121A), borderRadius: BorderRadius.circular(28)),
              child: const Icon(Icons.music_off_rounded, size: 60, color: Color(0xFF6A6A88))),
            const SizedBox(height: 20),
            const Text('Немає пісень', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('Завантаж або імпортуй музику',
              style: TextStyle(color: Color(0xFF6A6A88), fontSize: 14)),
          ]))
        : ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
            if (songs.isNotEmpty) ...[
              SectionHeader(icon: Icons.music_note_rounded, title: 'Пісні', count: songs.length),
              ...songs.map((s) => SongTile(
                song: s,
                active: currentSong?.filePath == s.filePath,
                editMode: editMode,
                onTap: () => onPlay(s),
                onMenu: () => onSongMenu(s))),
            ],
            if (playlists.isNotEmpty) ...[
              const SizedBox(height: 8),
              SectionHeader(icon: Icons.queue_music_rounded, title: 'Плейлісти', count: playlists.length),
              ...playlists.map((pl) => PlaylistTile(
                playlist: pl,
                currentSong: currentSong,
                editMode: editMode,
                onDelete: () => onDeletePlaylist(pl),
                onPlaySong: (s) => onPlayPlaylist(s, pl),
                onSongMenu: (s) => onSongMenu(s, inPlaylist: true),
              )),
            ],
          ])),
    ]));
  }
}

