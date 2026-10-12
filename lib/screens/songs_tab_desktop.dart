import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/song.dart';
import '../widgets/song_tile.dart';
import '../config/app_config.dart';
import '../google_drive_service.dart';
import 'backup_screen.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../theme/personalization.dart';
import '../platform_utils.dart';

// ================================================================
// AERO GLASS DESIGN SYSTEM
// ================================================================

class AeroColors {
  static const bg = Color(0xFF0A0A12);
  static const glass = Color(0x99121220);
  static const glassBorder = Color(0x337C5CFC);
  static const glassLight = Color(0x22FFFFFF);
  // Раніше const-літерали — тепер читаються з обраної теми
  // (AppConfig.themeName / AppTheme.presets), змінюються через
  // Debug меню (5 тапів по версії в Налаштуваннях).
  static Color get primary => AppTheme.primary;
  static Color get secondary => AppTheme.secondary;
  static const glow = Color(0x557C5CFC);
  static const textSecondary = Color(0xAAFFFFFF);
}

class AeroGlass extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final BorderRadius? borderRadius;
  final Color? color;
  final bool showBorder;
  final bool showGlow;

  const AeroGlass({super.key, required this.child, this.padding,
    this.borderRadius, this.color, this.showBorder = true, this.showGlow = false});

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color ?? AeroColors.glass,
      borderRadius: borderRadius ?? BorderRadius.circular(AppRadius.card),
      border: showBorder ? Border.all(color: AeroColors.glassBorder, width: 0.5) : null,
      boxShadow: [
        if (showGlow) BoxShadow(color: AeroColors.glow, blurRadius: 20, spreadRadius: -4),
        BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
      ],
      gradient: const LinearGradient(
        colors: [Color(0x33FFFFFF), Color(0x05FFFFFF)],
        begin: Alignment.topLeft, end: Alignment.bottomRight)),
    child: child);
}

// ================================================================
// SONGS TAB DESKTOP
// ================================================================
class SongsTabDesktop extends StatefulWidget {
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
  final VoidCallback onSettings;

  const SongsTabDesktop({super.key,
    required this.songs, required this.playlists, this.currentSong,
    required this.onPlay, required this.onPlayPlaylist, required this.onRefresh,
    required this.editMode, required this.onToggleEdit, required this.onSongMenu,
    required this.onCreatePlaylist, required this.onDeletePlaylist,
    required this.onVersionTap, required this.onSettings});

  @override
  State<SongsTabDesktop> createState() => _SongsTabDesktopState();
}

class _SongsTabDesktopState extends State<SongsTabDesktop> {
  MusicPlaylist? _selectedPlaylist;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  List<Song> get _visibleSongs {
    final songs = _selectedPlaylist == null ? widget.songs : _selectedPlaylist!.songs;
    if (_searchQuery.isEmpty) return songs;
    return songs.where((s) =>
      s.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      s.artist.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Container(
    decoration: AppConfig.wallpaperBg ? const BoxDecoration(color: Colors.transparent) : const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF0A0A14), Color(0xFF0D0A18), Color(0xFF080810)], begin: Alignment.topLeft, end: Alignment.bottomRight, stops: [0, 0.5, 1])),

    child: Row(children: [



      _AeroSidebar(
        playlists: widget.playlists,
        selectedPlaylist: _selectedPlaylist,
        currentSong: widget.currentSong,
        onSelectAll: () => setState(() => _selectedPlaylist = null),
        onSelectPlaylist: (pl) => setState(() => _selectedPlaylist = pl),
        onCreatePlaylist: widget.onCreatePlaylist,
        onDeletePlaylist: widget.onDeletePlaylist,
        onRefresh: widget.onRefresh,
        onSettings: widget.onSettings,
        onVersionTap: widget.onVersionTap,
        testMode: AppConfig.testMode),
      Container(width: 1, decoration: const BoxDecoration(gradient: LinearGradient(
        colors: [Colors.transparent, Color(0x447C5CFC), Colors.transparent],
        begin: Alignment.topCenter, end: Alignment.bottomCenter))),
      Expanded(child: Column(children: [
        _AeroHeader(
          title: _selectedPlaylist?.name ?? 'Всі пісні',
          count: _visibleSongs.length,
          editMode: widget.editMode,
          onToggleEdit: widget.onToggleEdit,
          searchCtrl: _searchCtrl,
          onSearch: (q) => setState(() => _searchQuery = q)),
        Expanded(child: _visibleSongs.isEmpty
          ? _AeroEmptyState(hasSearch: _searchQuery.isNotEmpty,
              onClearSearch: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); })
          : _AeroSongsTable(
              songs: _visibleSongs, currentSong: widget.currentSong,
              editMode: widget.editMode,
              onPlay: (s) => _selectedPlaylist == null
                ? widget.onPlay(s) : widget.onPlayPlaylist(s, _selectedPlaylist!),
              onMenu: (s) => widget.onSongMenu(s, inPlaylist: _selectedPlaylist != null))),
      ])),
    ]));
}

// ================================================================
// SIDEBAR
// ================================================================
class _AeroSidebar extends StatelessWidget {
  final List<MusicPlaylist> playlists;
  final MusicPlaylist? selectedPlaylist;
  final Song? currentSong;
  final VoidCallback onSelectAll, onCreatePlaylist, onRefresh, onVersionTap, onSettings;
  final Function(MusicPlaylist) onSelectPlaylist, onDeletePlaylist;
  final bool testMode;

  const _AeroSidebar({
    required this.playlists, this.selectedPlaylist, this.currentSong,
    required this.onSelectAll, required this.onSelectPlaylist,
    required this.onCreatePlaylist, required this.onDeletePlaylist,
    required this.onRefresh, required this.onVersionTap, required this.onSettings, required this.testMode});

  @override
  Widget build(BuildContext context) => Container(
    width: 220,
    decoration: BoxDecoration(gradient: LinearGradient(
      colors: AppConfig.wallpaperBg
        ? [const Color(0xCC0D0D1A), const Color(0xAA0A0A14)]
        : [const Color(0xDD0D0D1A), const Color(0xBB0A0A14)],
      begin: Alignment.topCenter, end: Alignment.bottomCenter)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
        child: Row(children: [
          if (AppConfig.avatarPath != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.file(File(AppConfig.avatarPath!), width: 20, height: 20, fit: BoxFit.cover)),
            const SizedBox(width: 6),
          ],
          ShaderMask(
            shaderCallback: (b) => LinearGradient(
              colors: [AeroColors.primary, AeroColors.secondary]).createShader(b),
            child: Text(AppConfig.displayName,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white))),
          const SizedBox(width: 6),
          GestureDetector(onTap: onVersionTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: AeroColors.glow,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AeroColors.glassBorder, width: 0.5)),
              child: Text('v5.2',
                style: TextStyle(color: AeroColors.primary, fontSize: 9, fontFamily: 'monospace')))),
        ])),
      if (testMode)
        Padding(padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
          child: AeroGlass(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            borderRadius: BorderRadius.circular(6),
            color: Colors.orange.withOpacity(0.15),
            child: Row(mainAxisSize: MainAxisSize.min, children: const [
              Icon(Icons.science_rounded, color: Colors.orange, size: 12),
              SizedBox(width: 4),
              Text('TEST MODE', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.w700)),
            ]))),
      _AeroSidebarItem(icon: Icons.music_note_rounded, label: 'Всі пісні',
        active: selectedPlaylist == null, onTap: onSelectAll),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Container(height: 0.5, decoration: const BoxDecoration(gradient: LinearGradient(
          colors: [Colors.transparent, Color(0x447C5CFC), Colors.transparent])))),
      Padding(padding: const EdgeInsets.fromLTRB(14, 2, 8, 4),
        child: Row(children: [
          const Text('ПЛЕЙЛІСТИ', style: TextStyle(
            color: Color(0x886A6A88), fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
          const Spacer(),
          GestureDetector(onTap: onCreatePlaylist,
            child: Container(padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: AeroColors.glow, borderRadius: BorderRadius.circular(4)),
              child: Icon(Icons.add_rounded, color: AeroColors.primary, size: 12))),
        ])),
      Expanded(child: ListView(padding: const EdgeInsets.only(bottom: 8),
        children: playlists.map((pl) {
          final hasActive = pl.songs.any((s) => s.filePath == currentSong?.filePath);
          return _AeroSidebarItem(
            icon: Icons.queue_music_rounded, label: pl.name, count: pl.songs.length,
            active: selectedPlaylist?.name == pl.name, hasActive: hasActive,
            onTap: () => onSelectPlaylist(pl), onDelete: () => onDeletePlaylist(pl));
        }).toList())),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Container(height: 0.5, color: const Color(0x222A2A40))),
      Padding(padding: const EdgeInsets.all(8),
        child: GestureDetector(onTap: onRefresh,
          child: AeroGlass(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            borderRadius: BorderRadius.circular(6),
            color: AeroColors.glassLight,
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.refresh_rounded, color: AeroColors.textSecondary, size: 14),
              SizedBox(width: 6),
              Text('Оновити', style: TextStyle(color: AeroColors.textSecondary, fontSize: 12)),
            ])))),
    ]));
}

class _AeroSidebarItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final int? count;
  final bool active, hasActive;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _AeroSidebarItem({required this.icon, required this.label, this.count,
    required this.active, this.hasActive = false, required this.onTap, this.onDelete});

  @override
  State<_AeroSidebarItem> createState() => _AeroSidebarItemState();
}

class _AeroSidebarItemState extends State<_AeroSidebarItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() => _hovered = false),
    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: GestureDetector(onTap: widget.onTap,
        child: AnimatedContainer(duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: widget.active ? const LinearGradient(
              colors: [Color(0x337C5CFC), Color(0x11FC5C9C)],
              begin: Alignment.centerLeft, end: Alignment.centerRight) : null,
            color: widget.active ? null : _hovered ? AeroColors.glassLight : null,
            border: widget.active ? Border.all(color: AeroColors.glassBorder, width: 0.5) : null),
          child: Row(children: [
            Icon(widget.icon,
              color: widget.active ? AeroColors.primary
                : widget.hasActive ? AeroColors.primary.withOpacity(0.5)
                : const Color(0xFF6A6A88), size: 15),
            const SizedBox(width: 8),
            Expanded(child: Text(widget.label,
              style: TextStyle(
                color: widget.active ? Colors.white : AeroColors.textSecondary,
                fontSize: 13, fontWeight: widget.active ? FontWeight.w600 : FontWeight.normal),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
            if (widget.count != null)
              Text('${widget.count}', style: const TextStyle(color: Color(0x776A6A88), fontSize: 11)),
            if (widget.onDelete != null && (_hovered || widget.active)) ...[
              const SizedBox(width: 4),
              GestureDetector(onTap: widget.onDelete,
                child: const Icon(Icons.close_rounded, color: Color(0x776A6A88), size: 13)),
            ],
          ])))));
}

// ================================================================
// HEADER
// ================================================================
class _AeroHeader extends StatelessWidget {
  final String title;
  final int count;
  final bool editMode;
  final VoidCallback onToggleEdit;
  final TextEditingController searchCtrl;
  final Function(String) onSearch;

  const _AeroHeader({required this.title, required this.count, required this.editMode,
    required this.onToggleEdit, required this.searchCtrl, required this.onSearch});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(24, 14, 16, 12),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0x220D0D1A), Colors.transparent],
        begin: Alignment.topCenter, end: Alignment.bottomCenter),
      border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05)))),
    child: Row(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
        Text('$count пісень', style: const TextStyle(color: Color(0x886A6A88), fontSize: 11)),
      ]),
      const SizedBox(width: 20),
      Expanded(child: AeroGlass(borderRadius: BorderRadius.circular(8), padding: EdgeInsets.zero,
        child: SizedBox(height: 34,
          child: TextField(controller: searchCtrl, onChanged: onSearch,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: const InputDecoration(
              hintText: 'Пошук...', hintStyle: TextStyle(color: Color(0x776A6A88), fontSize: 13),
              prefixIcon: Icon(Icons.search_rounded, color: Color(0x776A6A88), size: 16),
              border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 8)))))),
      const SizedBox(width: 12),
      GestureDetector(onTap: onToggleEdit,
        child: AeroGlass(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          borderRadius: BorderRadius.circular(8),
          color: editMode ? AeroColors.glow : null,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(editMode ? Icons.check_rounded : Icons.edit_rounded,
              color: editMode ? AeroColors.primary : AeroColors.textSecondary, size: 14),
            const SizedBox(width: 6),
            Text(editMode ? 'Готово' : 'Редагувати',
              style: TextStyle(
                color: editMode ? AeroColors.primary : AeroColors.textSecondary,
                fontSize: 12, fontWeight: FontWeight.w500)),
          ]))),
    ]));
}

// ================================================================
// SONGS TABLE
// ================================================================
class _AeroSongsTable extends StatelessWidget {
  final List<Song> songs;
  final Song? currentSong;
  final bool editMode;
  final Function(Song) onPlay, onMenu;

  const _AeroSongsTable({required this.songs, this.currentSong,
    required this.editMode, required this.onPlay, required this.onMenu});

  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(24, 8, 24, 6),
      child: Row(children: [
        const SizedBox(width: 48),
        Expanded(flex: 3, child: Text('#  НАЗВА', style: TextStyle(
          color: Colors.white.withOpacity(0.3), fontSize: 10,
          fontWeight: FontWeight.w700, letterSpacing: 0.8))),
        Expanded(flex: 2, child: Text('ВИКОНАВЕЦЬ', style: TextStyle(
          color: Colors.white.withOpacity(0.3), fontSize: 10,
          fontWeight: FontWeight.w700, letterSpacing: 0.8))),
        const SizedBox(width: 40),
      ])),
    Container(height: 0.5, margin: const EdgeInsets.symmetric(horizontal: 24),
      color: Colors.white.withOpacity(0.06)),
    Expanded(child: ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: songs.length,
      itemBuilder: (_, i) => _AeroTableRow(
        index: i + 1, song: songs[i],
        active: currentSong?.filePath == songs[i].filePath,
        editMode: editMode, onPlay: () => onPlay(songs[i]), onMenu: () => onMenu(songs[i])))),
  ]);
}

class _AeroTableRow extends StatefulWidget {
  final int index;
  final Song song;
  final bool active, editMode;
  final VoidCallback onPlay, onMenu;

  const _AeroTableRow({required this.index, required this.song, required this.active,
    required this.editMode, required this.onPlay, required this.onMenu});

  @override
  State<_AeroTableRow> createState() => _AeroTableRowState();
}

class _AeroTableRowState extends State<_AeroTableRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() => _hovered = false),
    child: GestureDetector(onTap: widget.onPlay,
      child: AnimatedContainer(duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: widget.active ? const LinearGradient(
            colors: [Color(0x227C5CFC), Color(0x11FC5C9C)]) : null,
          color: widget.active ? null : _hovered ? AeroColors.glassLight : null,
          border: widget.active ? Border.all(color: AeroColors.glassBorder, width: 0.5) : null,
          boxShadow: widget.active ? [BoxShadow(color: AeroColors.glow, blurRadius: 8, spreadRadius: -2)] : null),
        child: Row(children: [
          SongCover(coverPath: widget.song.coverPath, active: widget.active, size: 36),
          const SizedBox(width: 12),
          SizedBox(width: 24,
            child: _hovered || widget.active
              ? Icon(widget.active ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: AeroColors.primary, size: 18)
              : Text('${widget.index}',
                  style: const TextStyle(color: Color(0x776A6A88), fontSize: 12))),
          const SizedBox(width: 8),
          Expanded(flex: 3, child: Text(widget.song.title,
            style: TextStyle(
              color: widget.active ? AeroColors.primary : Colors.white,
              fontSize: 13, fontWeight: widget.active ? FontWeight.w600 : FontWeight.normal),
            maxLines: 1, overflow: TextOverflow.ellipsis)),
          Expanded(flex: 2, child: Text(widget.song.artist,
            style: const TextStyle(color: Color(0x886A6A88), fontSize: 12),
            maxLines: 1, overflow: TextOverflow.ellipsis)),
          SizedBox(width: 32,
            child: (_hovered || widget.editMode)
              ? GestureDetector(onTap: widget.onMenu,
                  child: const Icon(Icons.more_horiz_rounded, color: Color(0x776A6A88), size: 18))
              : null),
        ]))));
}

// ================================================================
// EMPTY STATE
// ================================================================
class _AeroEmptyState extends StatelessWidget {
  final bool hasSearch;
  final VoidCallback onClearSearch;
  const _AeroEmptyState({required this.hasSearch, required this.onClearSearch});

  @override
  Widget build(BuildContext context) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center, children: [
      AeroGlass(padding: const EdgeInsets.all(24), borderRadius: BorderRadius.circular(20),
        showGlow: true,
        child: Icon(hasSearch ? Icons.search_off_rounded : Icons.music_off_rounded,
          size: 48, color: AeroColors.primary.withOpacity(0.5))),
      const SizedBox(height: 16),
      Text(hasSearch ? 'Нічого не знайдено' : 'Немає пісень',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
      const SizedBox(height: 6),
      Text(hasSearch ? 'Спробуй інший пошук' : 'Завантаж або імпортуй музику',
        style: const TextStyle(color: Color(0x886A6A88), fontSize: 12)),
      if (hasSearch) ...[
        const SizedBox(height: 12),
        GestureDetector(onTap: onClearSearch,
          child: AeroGlass(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            borderRadius: BorderRadius.circular(8),
            child: Text('Очистити пошук',
              style: TextStyle(color: AeroColors.primary, fontSize: 13)))),
      ],
    ]));
}

// ================================================================
// AERO PLAYER BAR
// ================================================================
class AeroPlayerBar extends StatelessWidget {
  final Song song;
  final bool isPlaying;
  final Duration position, duration;
  final VoidCallback onPlayPause, onNext, onPrev, onStop, onMinimize;
  final Function(Duration)? onSeek;

  const AeroPlayerBar({super.key, required this.song, required this.isPlaying,
    required this.position, required this.duration,
    required this.onPlayPause, required this.onNext,
    required this.onPrev, required this.onStop, required this.onMinimize,
    this.onSeek});

  String _fmt(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final progress = duration.inMilliseconds > 0
      ? position.inMilliseconds / duration.inMilliseconds : 0.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [Color(0xCC12121E), Color(0xCC0D0D18)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        border: Border.all(color: AeroColors.glassBorder, width: 0.5),
        boxShadow: [
          BoxShadow(color: AeroColors.glow, blurRadius: 16, spreadRadius: -4),
          BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4)),
        ]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        LayoutBuilder(
          builder: (context, constraints) {
            void handleSeek(double dx) {
              if (onSeek == null || duration.inMilliseconds <= 0) return;
              final fraction = (dx / constraints.maxWidth).clamp(0.0, 1.0);
              onSeek!(Duration(milliseconds: (fraction * duration.inMilliseconds).round()));
            }
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => handleSeek(d.localPosition.dx),
              onHorizontalDragUpdate: (d) => handleSeek(d.localPosition.dx),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  child: LinearProgressIndicator(value: progress,
                    backgroundColor: Colors.white.withOpacity(0.05),
                    valueColor: AlwaysStoppedAnimation(AeroColors.primary), minHeight: 2)),
              ),
            );
          },
        ),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(children: [
            ClipRRect(borderRadius: BorderRadius.circular(8),
              child: song.coverPath != null
                ? Image.file(File(song.coverPath!), width: 38, height: 38, fit: BoxFit.cover)
                : Container(width: 38, height: 38,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [AeroColors.primary, AeroColors.secondary]),
                      borderRadius: const BorderRadius.all(Radius.circular(8))),
                    child: const Icon(Icons.music_note, color: Colors.white, size: 18))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(song.title, style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('${_fmt(position)} / ${_fmt(duration)}',
                style: const TextStyle(color: Color(0x886A6A88), fontSize: 10)),
            ])),
            _AeroBtn(icon: Icons.skip_previous_rounded, onTap: onPrev),
            const SizedBox(width: 4),
            GestureDetector(onTap: onPlayPause,
              child: Container(width: 36, height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [AeroColors.primary, AeroColors.secondary]),
                  boxShadow: [BoxShadow(color: AeroColors.glow, blurRadius: 10)]),
                child: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white, size: 20))),
            const SizedBox(width: 4),
            _AeroBtn(icon: Icons.skip_next_rounded, onTap: onNext),
            const SizedBox(width: 8),
            _AeroBtn(icon: Icons.close_rounded, onTap: onStop, size: 18),
            _AeroBtn(icon: Icons.remove_rounded, onTap: onMinimize, size: 18),
          ])),
      ]));
  }
}

class _AeroBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  const _AeroBtn({required this.icon, required this.onTap, this.size = 20});

  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: Padding(padding: const EdgeInsets.all(4),
      child: Icon(icon, color: AeroColors.textSecondary, size: size)));
}

// ================================================================
// AERO BOTTOM NAV (з Settings)
// ================================================================
class AeroBottomNav extends StatelessWidget {
  final int current;
  final Function(int) onChange;
  const AeroBottomNav({super.key, required this.current, required this.onChange});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: AppConfig.wallpaperBg
          ? [const Color(0xAA0D0D18), const Color(0x880A0A14)]
          : [const Color(0xDD0D0D18), const Color(0xDD0A0A14)],
        begin: Alignment.topCenter, end: Alignment.bottomCenter),
      border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
      boxShadow: AppConfig.wallpaperBg ? [
        BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, -4)),
      ] : null),
    child: SafeArea(top: false,
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _AeroNavItem(icon: Icons.music_note_rounded, label: 'Пісні',
            active: current == 0, onTap: () => onChange(0)),
          _AeroNavItem(icon: Icons.download_rounded, label: 'Завантажити',
            active: current == 1, onTap: () => onChange(1)),
          _AeroNavItem(icon: Icons.settings_rounded, label: 'Налаштування',
            active: current == 2, onTap: () => onChange(2)),
        ]))));
}

class _AeroNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _AeroNavItem({required this.icon, required this.label,
    required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: AnimatedContainer(duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: active ? const LinearGradient(colors: [Color(0x337C5CFC), Color(0x11FC5C9C)]) : null,
        border: active ? Border.all(color: AeroColors.glassBorder, width: 0.5) : null),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: active ? AeroColors.primary : const Color(0xFF6A6A88), size: 22),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10,
          color: active ? AeroColors.primary : const Color(0xFF6A6A88),
          fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
      ])));
}


// ================================================================
// SETTINGS SCREEN
// ================================================================
class SettingsScreen extends StatefulWidget {
  final VoidCallback onEasterEgg;
  final List<Song> songs;
  final List<MusicPlaylist> playlists;
  final VoidCallback onDataChanged;
  final VoidCallback? onWallpaperChanged;
  const SettingsScreen({super.key, required this.onEasterEgg,
    required this.songs, required this.playlists, required this.onDataChanged,
    this.onWallpaperChanged});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _eggTaps = 0;
  int _versionTaps = 0;
  Timer? _versionTapTimer;

  void _onVersionTextTap() {
    _versionTaps++;
    _versionTapTimer?.cancel();
    _versionTapTimer = Timer(const Duration(milliseconds: 900), () => _versionTaps = 0);
    if (_versionTaps >= 5) {
      _versionTaps = 0;
      _versionTapTimer?.cancel();
      _showDebugMenu();
    }
  }

  void _showDebugMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF12121E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => StatefulBuilder(builder: (sheetContext, sheetSetState) {
        return SafeArea(child: SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(20), child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.terminal_rounded, color: Color(0xFFFC5C9C), size: 20),
            const SizedBox(width: 8),
            const Text('Debug меню', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ]),
          const SizedBox(height: 4),
          const Text('Приховані експериментальні перемикачі.',
            style: TextStyle(color: Color(0xFF6A6A88), fontSize: 12)),
          const SizedBox(height: 20),

          const Text('КОЛІР ТЕМИ', style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6A6A88), letterSpacing: 0.5)),
          const SizedBox(height: 10),
          Wrap(spacing: 12, runSpacing: 12, children: AppTheme.presets.map((preset) {
            final selected = AppConfig.themeName == preset.id;
            return GestureDetector(
              onTap: () async {
                await AppConfig.setThemeName(preset.id);
                sheetSetState(() {});
                setState(() {});
                widget.onWallpaperChanged?.call();
              },
              child: Column(children: [
                Container(width: 40, height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [preset.primary, preset.secondary]),
                    border: Border.all(
                      color: selected ? Colors.white : Colors.transparent, width: 2.5),
                    boxShadow: selected
                      ? [BoxShadow(color: preset.primary.withOpacity(0.5), blurRadius: 10)]
                      : null),
                  child: selected
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                    : null),
                const SizedBox(height: 4),
                Text(preset.label, style: const TextStyle(fontSize: 10, color: Color(0xFF9A9AB8))),
              ]));
          }).toList()),

          if (isMobilePlatform) ...[
            const SizedBox(height: 24),
            const Text('ІНШЕ', style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6A6A88), letterSpacing: 0.5)),
            const SizedBox(height: 8),
            _ToggleTile(
              icon: Icons.desktop_windows_rounded,
              iconColor: const Color(0xFFFC5C9C),
              title: 'ПК режим',
              subtitle: 'Показати десктопний інтерфейс (Aero Glass) на телефоні',
              value: AppConfig.desktopLayout,
              onChanged: (v) async {
                await AppConfig.setDesktopLayout(v);
                sheetSetState(() {});   // оновити вигляд перемикача в самому bottom sheet
                setState(() {});        // оновити SettingsScreen
                widget.onWallpaperChanged?.call(); // оновити MainScreen (перемкнути IndexedStack)
              }),
          ],
        ]))));
      }));
  }

  @override
  void dispose() {
    _versionTapTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasWallpaper = AppConfig.wallpaperBg && AppConfig.wallpaperPath != null;
    // Матовий фон шпалер тепер малюється ГЛОБАЛЬНО в main.dart (по всіх
    // вкладках), тож тут просто прозорий фон, якщо він увімкнутий, або
    // звичайний градієнт, якщо ні.
    return Container(
      decoration: hasWallpaper
        ? null
        : const BoxDecoration(gradient: LinearGradient(
            colors: [Color(0xFF0A0A14), Color(0xFF0D0A18)],
            begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: _settingsContent(context),
    );
  }

  Widget _settingsContent(BuildContext context) =>
    SafeArea(child: ListView(padding: const EdgeInsets.all(24), children: [
      Row(children: [
        ShaderMask(
          shaderCallback: (b) => LinearGradient(
            colors: [AeroColors.primary, AeroColors.secondary]).createShader(b),
          child: const Text('Налаштування',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white))),
        const Spacer(),
        GestureDetector(
          onTap: () { _eggTaps++; if (_eggTaps >= 7) { _eggTaps = 0; widget.onEasterEgg(); } },
          child: const Icon(Icons.settings_rounded, color: Color(0x226A6A88), size: 20)),
      ]),
      const SizedBox(height: 4),
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _onVersionTextTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text('${AppConfig.displayName} v5.2', style: const TextStyle(color: Color(0x886A6A88), fontSize: 12)))),
      const SizedBox(height: 10),
      AeroGlass(
        padding: const EdgeInsets.all(10),
        borderRadius: BorderRadius.circular(8),
        color: Colors.blue.withOpacity(0.1),
        child: const Row(children: [
          Icon(Icons.info_rounded, color: Colors.blue, size: 14),
          SizedBox(width: 8),
          Expanded(child: Text(
            'Налаштування зберігаються автоматично.',
            style: TextStyle(color: Colors.blue, fontSize: 11))),
        ])),
      const SizedBox(height: 20),

      _SettingsSection(title: 'ПЕРСОНАЛІЗАЦІЯ', children: [
        _SliderSettingsTile(
          icon: Icons.text_fields_rounded, iconColor: const Color(0xFF2196F3),
          title: 'Розмір шрифту',
          valueLabel: '${(AppConfig.textScale * 100).round()}%',
          value: AppConfig.textScale, min: 0.85, max: 1.3, divisions: 9,
          onChanged: (v) async {
            await AppConfig.setTextScale(v);
            setState(() {});
            widget.onWallpaperChanged?.call();
          }),
        if (isMobilePlatform)
          _SettingsTile(
            icon: Icons.smartphone_rounded, iconColor: const Color(0xFFFF9800),
            title: 'Стиль мініплеєра',
            subtitle: switch (AppConfig.miniPlayerStyle) {
              'compact' => 'Компактний', 'large' => 'Великий', 'transparent' => 'Прозорий', _ => 'Звичайний'},
            trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF6A6A88)),
            onTap: () async {
              const styles = ['compact', 'comfortable', 'large', 'transparent'];
              final idx = styles.indexOf(AppConfig.miniPlayerStyle);
              await AppConfig.setMiniPlayerStyle(styles[(idx + 1) % styles.length]);
              setState(() {});
              widget.onWallpaperChanged?.call();
            }),
        _SliderSettingsTile(
          icon: Icons.view_list_rounded, iconColor: AeroColors.secondary,
          title: 'Щільність списку пісень',
          valueLabel: AppConfig.listDensityScale <= 0.85 ? 'Компактно'
            : (AppConfig.listDensityScale >= 1.25 ? 'Великий' : 'Зручно'),
          value: AppConfig.listDensityScale, min: 0.75, max: 1.4, divisions: 13,
          onChanged: (v) async {
            await AppConfig.setListDensityScale(v);
            setState(() {});
            widget.onWallpaperChanged?.call();
          }),
      ]),
      const SizedBox(height: 16),

      _SettingsSection(title: 'ДИЗАЙН', children: [
        if (isMobilePlatform)
          _SettingsTile(
            icon: Icons.image_rounded,
            iconColor: const Color(0xFF4CAF50),
            title: 'Зображення фону',
            subtitle: AppConfig.bgImagePath != null
              ? 'Вибрано з галереї'
              : 'Не вибрано — торкнись, щоб обрати',
            trailing: AppConfig.bgImagePath != null
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF6A6A88), size: 18),
                  onPressed: () async {
                    await AppConfig.setBgImagePath(null);
                    setState(() {});
                    widget.onWallpaperChanged?.call();
                  })
              : const Icon(Icons.chevron_right_rounded, color: Color(0xFF6A6A88)),
            onTap: () async {
              final picker = ImagePicker();
              final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
              if (img != null) {
                await AppConfig.setBgImagePath(await persistPickedImage(img.path, 'bg_image'));
                setState(() {});
                widget.onWallpaperChanged?.call();
              }
            })
        else
          _ToggleTile(
            icon: Icons.wallpaper_rounded,
            iconColor: const Color(0xFF4CAF50),
            title: 'Шпалери як фон',
            subtitle: 'Шпалери робочого столу за фоном плеєра',
            value: AppConfig.wallpaperBg,
            onChanged: (v) async {
              await AppConfig.setWallpaperBg(v);
              setState(() {});
              widget.onWallpaperChanged?.call();
            }),
      ]),

      const SizedBox(height: 16),

      _SettingsSection(title: 'ДАНІ', children: [
        _SettingsTile(
          icon: GoogleDriveService.isSignedIn ? Icons.cloud_done_rounded : Icons.cloud_outlined,
          iconColor: GoogleDriveService.isSignedIn ? const Color(0xFF4CAF50) : AeroColors.primary,
          title: 'Бекап та відновлення',
          subtitle: GoogleDriveService.isSignedIn
            ? 'Підключено: ${GoogleDriveService.userEmail ?? ""}'
            : 'Google Drive — вхід, бекап, відновлення',
          trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF6A6A88)),
          onTap: () async {
            await Navigator.push(context, MaterialPageRoute(
              builder: (_) => BackupScreen(
                songs: widget.songs, playlists: widget.playlists,
                onDataChanged: widget.onDataChanged)));
            if (mounted) setState(() {});
          },
        ),
      ]),

      const SizedBox(height: 16),

      if (AppConfig.testMode)
        _SettingsSection(title: 'РОЗРОБКА (TEST MODE)', children: [
          _SettingsTile(icon: Icons.science_rounded, iconColor: Colors.orange,
            title: 'Тестовий режим активний',
            subtitle: 'Запущено з ключем --test'),
        ]),

      if (AppConfig.testMode) const SizedBox(height: 16),

      _SettingsSection(title: 'ПРО ДОДАТОК', children: [
        _SettingsTile(icon: Icons.info_outline_rounded, iconColor: const Color(0xFF4CAF50),
          title: 'Версія', subtitle: 'pro420x1kmuxsk v5.2 ($platformLabel)'),
        _SettingsTile(icon: Icons.folder_rounded, iconColor: AeroColors.secondary,
          title: 'Папка музики', subtitle: AppConfig.musicDirDisplay),
        _SettingsTile(icon: Icons.save_rounded, iconColor: AeroColors.primary,
          title: 'Конфіг', subtitle: AppConfig.cfgPathDisplay),
        _SettingsTile(icon: Icons.code_rounded, iconColor: AeroColors.primary,
          title: 'Фреймворк', subtitle: 'Flutter 3.41.9 • ${Platform.isWindows ? "Windows x64" : platformLabel}'),
      ]),
    ]));
}


class _StatusBadge extends StatelessWidget {
  final bool active;
  final Color activeColor;
  const _StatusBadge({required this.active, required this.activeColor});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: active ? activeColor.withOpacity(0.15) : Colors.white.withOpacity(0.05),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: active ? activeColor.withOpacity(0.4) : Colors.white.withOpacity(0.1))),
    child: Text(active ? 'ON' : 'OFF',
      style: TextStyle(color: active ? activeColor : const Color(0xFF6A6A88),
        fontSize: 11, fontWeight: FontWeight.w700)));
}

class _SliderSettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String valueLabel;
  final double value, min, max;
  final int divisions;
  final ValueChanged<double> onChanged;
  const _SliderSettingsTile({required this.icon, required this.iconColor, required this.title,
    required this.valueLabel, required this.value, required this.min, required this.max,
    required this.divisions, required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 34, height: 34,
          decoration: BoxDecoration(color: iconColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: iconColor, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Text(title,
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500))),
        Text(valueLabel, style: TextStyle(color: iconColor, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
      SliderTheme(data: SliderThemeData(trackHeight: 2,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
        activeTrackColor: iconColor, inactiveTrackColor: const Color(0xFF2A2A40),
        thumbColor: iconColor, overlayColor: iconColor.withOpacity(0.2)),
        child: Slider(value: value, min: min, max: max, divisions: divisions, onChanged: onChanged)),
    ]));
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: const TextStyle(
        color: Color(0x776A6A88), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2))),
    AeroGlass(padding: const EdgeInsets.symmetric(vertical: 4),
      borderRadius: BorderRadius.circular(12),
      child: Column(children: children)),
  ]);
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title, subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _SettingsTile({required this.icon, required this.iconColor,
    required this.title, required this.subtitle, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) => Material(color: Colors.transparent,
    child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(10),
    child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    child: Row(children: [
      Container(width: 34, height: 34,
        decoration: BoxDecoration(color: iconColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: iconColor, size: 18)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
        Text(subtitle, style: const TextStyle(color: Color(0x886A6A88), fontSize: 12)),
      ])),
      if (trailing != null) trailing!,
    ]))));
}

class _CodeSection extends StatelessWidget {
  final List<String> lines;
  const _CodeSection({required this.lines});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
    child: AeroGlass(
      padding: const EdgeInsets.all(12),
      borderRadius: BorderRadius.circular(8),
      color: const Color(0x110A0A0A),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: lines.map((l) => l.isEmpty
          ? const SizedBox(height: 4)
          : Padding(padding: const EdgeInsets.symmetric(vertical: 1),
              child: Text(l, style: TextStyle(
                color: l.startsWith('#') || l.startsWith('*')
                  ? const Color(0x556A6A88)
                  : const Color(0xBB7C5CFC),
                fontSize: 11, fontFamily: 'monospace')))).toList())));
}

// ================================================================
// TOGGLE TILE
// ================================================================
class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title, subtitle;
  final bool value;
  final Function(bool) onChanged;

  const _ToggleTile({required this.icon, required this.iconColor,
    required this.title, required this.subtitle,
    required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    child: Row(children: [
      Container(width: 34, height: 34,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: iconColor, size: 18)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
        Text(subtitle, style: const TextStyle(color: Color(0x886A6A88), fontSize: 11)),
      ])),
      GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44, height: 24,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: value
              ? LinearGradient(colors: [AeroColors.primary, AeroColors.secondary])
              : null,
            color: value ? null : const Color(0xFF2A2A40),
            border: Border.all(
              color: value ? AeroColors.primary : const Color(0xFF3A3A50),
              width: 0.5)),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 18, height: 18,
              margin: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)])))),
      ),
    ]));
}

