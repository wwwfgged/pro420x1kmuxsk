import 'dart:io';
import 'package:flutter/material.dart';
import '../models/song.dart';

class MiniPlayerWidget extends StatelessWidget {
  final Song? song;
  final bool isPlaying;
  final Duration position, duration;
  final VoidCallback onPlayPause, onNext, onPrev, onStop, onExpand;
  const MiniPlayerWidget({super.key, this.song, required this.isPlaying, required this.position,
    required this.duration, required this.onPlayPause, required this.onNext,
    required this.onPrev, required this.onStop, required this.onExpand});

  String _fmt(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320, height: 120,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF12121A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A40)),
      ),
      child: Column(children: [
        Row(children: [
          if (song?.coverPath != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(File(song!.coverPath!), width: 48, height: 48, fit: BoxFit.cover))
          else
            Container(
              width: 48, height: 48,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF7C5CFC), Color(0xFFFC5C9C)]),
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              child: const Icon(Icons.music_note, color: Colors.white)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(song?.title ?? 'Немає пісні',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('${_fmt(position)} / ${_fmt(duration)}',
              style: const TextStyle(color: Color(0xFF6A6A88), fontSize: 10)),
          ])),
          IconButton(icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF6A6A88)),
            onPressed: onStop, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
          IconButton(icon: const Icon(Icons.open_in_full_rounded, size: 18, color: Color(0xFF6A6A88)),
            onPressed: onExpand, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
        ]),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(icon: const Icon(Icons.skip_previous_rounded, color: Color(0xFF6A6A88), size: 22),
            onPressed: onPrev, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
          IconButton(icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
            color: const Color(0xFF7C5CFC), size: 32),
            onPressed: onPlayPause, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
          IconButton(icon: const Icon(Icons.skip_next_rounded, color: Color(0xFF6A6A88), size: 22),
            onPressed: onNext, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
        ]),
      ]),
    );
  }
}

class MiniPlayerBar extends StatelessWidget {
  final Song song;
  final bool isPlaying;
  final Duration position, duration;
  final VoidCallback onPlayPause, onNext, onPrev, onStop, onMinimize;
  const MiniPlayerBar({super.key, required this.song, required this.isPlaying, required this.position,
    required this.duration, required this.onPlayPause, required this.onNext,
    required this.onPrev, required this.onStop, required this.onMinimize});

  String _fmt(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF12121A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A40)),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: song.coverPath != null
              ? Image.file(File(song.coverPath!), width: 40, height: 40, fit: BoxFit.cover)
              : Container(
                  width: 40, height: 40,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0xFF7C5CFC), Color(0xFFFC5C9C)]),
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  child: const Icon(Icons.music_note, color: Colors.white))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(song.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            maxLines: 1, overflow: TextOverflow.ellipsis),
          Text('${_fmt(position)} / ${_fmt(duration)}',
            style: const TextStyle(color: Color(0xFF6A6A88), fontSize: 10)),
        ])),
        IconButton(icon: const Icon(Icons.skip_previous_rounded, color: Color(0xFF6A6A88), size: 22),
          onPressed: onPrev, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
        IconButton(icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
          color: const Color(0xFF7C5CFC), size: 30),
          onPressed: onPlayPause, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
        IconButton(icon: const Icon(Icons.skip_next_rounded, color: Color(0xFF6A6A88), size: 22),
          onPressed: onNext, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
        IconButton(icon: const Icon(Icons.close_rounded, color: Color(0xFF6A6A88), size: 20),
          onPressed: onStop, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
        IconButton(icon: const Icon(Icons.remove_rounded, color: Color(0xFF6A6A88), size: 20),
          onPressed: onMinimize, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
      ]),
    );
  }
}

