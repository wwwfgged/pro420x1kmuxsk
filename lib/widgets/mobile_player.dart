import 'dart:io';
import 'package:flutter/material.dart';
import '../models/song.dart';
import '../player.dart';
import '../theme/personalization.dart';

String _fmtDuration(Duration d) =>
    '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

/// Обкладинка пісні (або плейсхолдер з нотою), як у старій Android-версії.
class _SongCoverArt extends StatelessWidget {
  final String? coverPath;
  final double size;
  const _SongCoverArt({this.coverPath, this.size = 40});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * 0.25),
    child: (coverPath != null && File(coverPath!).existsSync())
      ? Image.file(File(coverPath!), width: size, height: size, fit: BoxFit.cover)
      : Container(width: size, height: size,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF7C5CFC), Color(0xFFFC5C9C)])),
          child: Icon(Icons.music_note_rounded, size: size * 0.5, color: Colors.white)));
}

/// Дає position/duration НАПРЯМУ зі стрімів плеєра (а не з батьківського
/// State через параметри конструктора) — тому працює живо навіть коли
/// батьківський віджет не перемальовується (як-от MobileFullPlayer у
/// bottom sheet, який інакше "замерзав" на момент відкриття).
class _LiveProgress extends StatelessWidget {
  final Widget Function(BuildContext context, Duration position, Duration duration) builder;
  const _LiveProgress({required this.builder});

  @override
  Widget build(BuildContext context) => StreamBuilder<Duration>(
    stream: Player.durationStream,
    initialData: Player.duration,
    builder: (context, durSnap) => StreamBuilder<Duration>(
      stream: Player.positionStream,
      initialData: Player.position,
      builder: (context, posSnap) =>
        builder(context, posSnap.data ?? Duration.zero, durSnap.data ?? Duration.zero)));
}

/// Повзунок перемотки зі СТАБІЛЬНИМ перетягуванням:
/// - поки палець на екрані (_dragValue != null) — показуємо позицію
///   пальця, ІГНОРУючи вхідні оновлення position зі стріму (інакше вони
///   "виривають" повзунок з-під пальця — саме це й викликало смикання);
/// - Player.seek() викликається ОДИН раз, лише коли палець відпущено
///   (onChangeEnd), а не на кожен проміжний tick під час руху.
class _SeekBar extends StatefulWidget {
  final double trackHeight, thumbRadius, overlayRadius;
  final Color thumbColor;
  const _SeekBar({this.trackHeight = 2, this.thumbRadius = 5, this.overlayRadius = 10,
    this.thumbColor = const Color(0xFF7C5CFC)});

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) => _LiveProgress(builder: (context, position, duration) {
    final liveProgress = duration.inSeconds > 0
      ? (position.inSeconds / duration.inSeconds).clamp(0.0, 1.0)
      : 0.0;
    final shown = (_dragValue ?? liveProgress).clamp(0.0, 1.0);
    return SliderTheme(
      data: SliderThemeData(trackHeight: widget.trackHeight,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: widget.thumbRadius),
        overlayShape: RoundSliderOverlayShape(overlayRadius: widget.overlayRadius),
        activeTrackColor: const Color(0xFF7C5CFC), inactiveTrackColor: const Color(0xFF2A2A40),
        thumbColor: widget.thumbColor, overlayColor: const Color(0xFF7C5CFC).withOpacity(0.2)),
      child: Slider(value: shown,
        onChangeStart: (v) => setState(() => _dragValue = v),
        onChanged: (v) => setState(() => _dragValue = v),
        onChangeEnd: (v) {
          if (duration.inSeconds > 0) {
            Player.seek(Duration(seconds: (v * duration.inSeconds).round()));
          }
          setState(() => _dragValue = null);
        }));
  });
}

/// Докований знизу мініплеєр для мобільного UI. На дотик відкриває
/// повноекранний плеєр (MobileFullPlayer) знизу вгору.
class MobileMiniPlayer extends StatelessWidget {
  final Song song;
  final bool isPlaying;
  final Duration position, duration;
  final VoidCallback onPlayPause, onNext, onPrev, onStop;

  const MobileMiniPlayer({super.key, required this.song, required this.isPlaying,
    required this.position, required this.duration,
    required this.onPlayPause, required this.onNext, required this.onPrev, required this.onStop});

  @override
  Widget build(BuildContext context) {
    final coverSize = MiniPlayerStyle.coverSize;
    final bgOpacity = MiniPlayerStyle.backgroundOpacity;
    final compact = MiniPlayerStyle.isCompact;
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => MobileFullPlayer(
          song: song, isPlaying: isPlaying,
          onPlayPause: onPlayPause, onNext: onNext, onPrev: onPrev)),
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.card),
          gradient: LinearGradient(
            colors: [Color(0xFF12121E).withOpacity(bgOpacity), Color(0xFF0D0D18).withOpacity(bgOpacity)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
          border: Border.all(color: const Color(0x337C5CFC), width: 0.5),
          boxShadow: [
            BoxShadow(color: const Color(0x557C5CFC), blurRadius: 16, spreadRadius: -4),
            BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4)),
          ]),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (!compact) const _SeekBar(),
          Padding(padding: EdgeInsets.fromLTRB(12, compact ? 6 : 0, 4, compact ? 6 : 8),
            child: Row(children: [
              _SongCoverArt(coverPath: song.coverPath, size: coverSize),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(song.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                if (!compact)
                  _LiveProgress(builder: (context, position, duration) =>
                    Text('${_fmtDuration(position)} / ${_fmtDuration(duration)}',
                      style: const TextStyle(color: Color(0xFF6A6A88), fontSize: 10))),
              ])),
              if (!compact)
                IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  icon: const Icon(Icons.skip_previous_rounded, color: Color(0xFF6A6A88), size: 26),
                  onPressed: onPrev),
              IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: Icon(isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                  color: const Color(0xFF7C5CFC), size: compact ? 28 : 34),
                onPressed: onPlayPause),
              if (!compact)
                IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  icon: const Icon(Icons.skip_next_rounded, color: Color(0xFF6A6A88), size: 26),
                  onPressed: onNext),
              IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
                icon: const Icon(Icons.close_rounded, color: Color(0xFF6A6A88), size: 22),
                onPressed: onStop),
            ])),
        ])));
  }
}

/// Повноекранний плеєр (bottom sheet, тягнеться на ~88% висоти екрану) —
/// велика обкладинка, повзунок, керування. position/duration/isPlaying
/// тепер читаються напряму зі стрімів (_LiveProgress / StreamBuilder),
/// а не заморожені на момент відкриття sheet.
class MobileFullPlayer extends StatelessWidget {
  final Song song;
  final bool isPlaying;
  final VoidCallback onPlayPause, onNext, onPrev;

  const MobileFullPlayer({super.key, required this.song, required this.isPlaying,
    required this.onPlayPause, required this.onNext, required this.onPrev});

  @override
  Widget build(BuildContext context) {
    final hasCover = song.coverPath != null && File(song.coverPath!).existsSync();
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xEE0D0D1A), Color(0xEE0A0A14)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: Stack(children: [
        if (hasCover)
          Positioned.fill(child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: Opacity(opacity: 0.07,
              child: Image.file(File(song.coverPath!), fit: BoxFit.cover)))),
        SafeArea(child: Column(children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(
            color: const Color(0xFF2A2A40), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 28),
          Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: const Color(0xFF7C5CFC).withOpacity(0.35),
                blurRadius: 40, offset: const Offset(0, 20))]),
            child: ClipRRect(borderRadius: BorderRadius.circular(24),
              child: _SongCoverArt(coverPath: song.coverPath, size: 240))),
          const SizedBox(height: 28),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(song.title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis)),
          const SizedBox(height: 6),
          Text(song.artist, style: const TextStyle(color: Color(0xFF6A6A88), fontSize: 15)),
          const SizedBox(height: 28),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(children: [
              const _SeekBar(trackHeight: 3, thumbRadius: 7, overlayRadius: 14, thumbColor: Colors.white),
              _LiveProgress(builder: (context, position, duration) =>
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(_fmtDuration(position), style: const TextStyle(color: Color(0xFF6A6A88), fontSize: 12)),
                  Text(_fmtDuration(duration), style: const TextStyle(color: Color(0xFF6A6A88), fontSize: 12)),
                ])),
            ])),
          const SizedBox(height: 20),
          StreamBuilder<bool>(
            stream: Player.playingStream,
            initialData: isPlaying,
            builder: (context, snap) {
              final playing = snap.data ?? isPlaying;
              return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                IconButton(icon: const Icon(Icons.skip_previous_rounded, size: 38, color: Color(0xFF6A6A88)),
                  onPressed: () { Navigator.pop(context); onPrev(); }),
                Container(width: 72, height: 72,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF7C5CFC), Color(0xFFFC5C9C)]),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: const Color(0xFF7C5CFC).withOpacity(0.4),
                      blurRadius: 24, offset: const Offset(0, 8))]),
                  child: IconButton(
                    icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 40, color: Colors.white),
                    onPressed: onPlayPause)),
                IconButton(icon: const Icon(Icons.skip_next_rounded, size: 38, color: Color(0xFF6A6A88)),
                  onPressed: () { Navigator.pop(context); onNext(); }),
              ]);
            }),
          const SizedBox(height: 12),
        ])),
      ]));
  }
}
