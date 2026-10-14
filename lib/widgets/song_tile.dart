import 'dart:io';
import 'package:flutter/material.dart';
import '../models/song.dart';
import '../theme/personalization.dart';

class SongTile extends StatelessWidget {
  final Song song;
  final bool active;
  final bool editMode;
  final VoidCallback onTap;
  final VoidCallback onMenu;
  final bool indent;
  const SongTile({super.key, required this.song, required this.active, required this.editMode,
    required this.onTap, required this.onMenu, this.indent = false});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    curve: Curves.easeOutCubic,
    margin: EdgeInsets.only(bottom: 8, left: indent ? 8 : 0),
    decoration: BoxDecoration(
      color: active ? const Color(0xFF7C5CFC).withOpacity(0.15) : const Color(0xFF0F0F1A),
      borderRadius: BorderRadius.circular(AppRadius.card),
      border: Border.all(color: active ? const Color(0xFF7C5CFC).withOpacity(0.4) : const Color(0xFF2A2A40))),
    child: ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: ListDensity.verticalPadding),
      leading: AnimatedScale(
        scale: active ? 1.04 : 1,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: SongCover(coverPath: song.coverPath, active: active, size: ListDensity.coverSize),
      ),
      title: Text(song.title, style: TextStyle(fontWeight: FontWeight.w600,
        color: active ? const Color(0xFF7C5CFC) : Colors.white, fontSize: ListDensity.titleFontSize),
        maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: editMode
        ? IconButton(icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF6A6A88), size: 20),
            padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: onMenu)
        : (active ? const Icon(Icons.equalizer_rounded, color: Color(0xFF7C5CFC), size: 20) : null),
      onTap: onTap));
}

class SongCover extends StatelessWidget {
  final String? coverPath;
  final bool active;
  final double size;
  const SongCover({super.key, this.coverPath, required this.active, required this.size});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * 0.2),
    child: coverPath != null
      ? Image.file(File(coverPath!), width: size, height: size, fit: BoxFit.cover)
      : Container(width: size, height: size,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: active
              ? [const Color(0xFF7C5CFC), const Color(0xFFFC5C9C)]
              : [const Color(0xFF2A2A40), const Color(0xFF1A1A28)]),
            borderRadius: BorderRadius.circular(size * 0.2)),
          child: Icon(Icons.music_note_rounded,
            color: active ? Colors.white : const Color(0xFF6A6A88), size: size * 0.48)));
}

