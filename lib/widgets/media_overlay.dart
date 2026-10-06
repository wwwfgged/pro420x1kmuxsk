import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/song.dart';
import '../screens/songs_tab_desktop.dart' show AeroColors, AeroGlass;

/// Компактний медіа-плеєр overlay (стиль Windows 11)
/// З'являється при наведенні мишки на нижній правий кут
/// або при натисканні на іконку плеєра

class MediaOverlay extends StatefulWidget {
  final Song? song;
  final bool isPlaying;
  final Duration position, duration;
  final VoidCallback onPlayPause, onNext, onPrev, onStop, onMinimize;
  final Function(Duration)? onSeek;

  const MediaOverlay({super.key,
    this.song, required this.isPlaying,
    required this.position, required this.duration,
    required this.onPlayPause, required this.onNext,
    required this.onPrev, required this.onStop,
    required this.onMinimize, this.onSeek});

  @override
  State<MediaOverlay> createState() => _MediaOverlayState();
}

class _MediaOverlayState extends State<MediaOverlay>
    with SingleTickerProviderStateMixin {
  bool _visible = false;
  bool _hovered = false;
  Timer? _hideTimer;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 250));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));

    // Показуємо при зміні пісні
    if (widget.song != null) _show();
  }

  @override
  void didUpdateWidget(MediaOverlay old) {
    super.didUpdateWidget(old);
    if (widget.song != old.song && widget.song != null) {
      _show();
    }
  }

  void _show() {
    setState(() => _visible = true);
    _animCtrl.forward(from: 0);
    _resetTimer();
  }

  void _hide() {
    _animCtrl.reverse().then((_) {
      if (mounted && !_hovered) setState(() => _visible = false);
    });
  }

  void _resetTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (!_hovered) _hide();
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  String _fmt(Duration d) =>
    '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  double get _progress => widget.duration.inMilliseconds > 0
    ? widget.position.inMilliseconds / widget.duration.inMilliseconds
    : 0.0;

  @override
  Widget build(BuildContext context) {
    if (widget.song == null) return const SizedBox.shrink();

    return Stack(children: [
      // Trigger zone — ТІЛЬКИ у правому нижньому куті (де з'являється картка),
      // а не на всю ширину. І hitTestBehavior: translucent, інакше MouseRegion
      // "з'їдає" кліки по AeroBottomNav навіть без власного обробника тапу —
      // саме через це не перемикались вкладки Налаштування/Завантаження,
      // коли грала музика.
      Positioned(
        bottom: 0, right: 0, width: 340,
        child: MouseRegion(
          hitTestBehavior: HitTestBehavior.translucent,
          onEnter: (_) { _show(); setState(() => _hovered = true); },
          onExit: (_) { setState(() => _hovered = false); _resetTimer(); },
          child: const SizedBox(height: 60))),

      // Media overlay card
      if (_visible)
        Positioned(
          bottom: 70, right: 16,
          left: null, top: null,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width - 32,
            ),
            child: MouseRegion(
            onEnter: (_) {
              setState(() => _hovered = true);
              _hideTimer?.cancel();
            },
            onExit: (_) {
              setState(() => _hovered = false);
              _resetTimer();
            },
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: _MediaCard(
                  song: widget.song!,
                  isPlaying: widget.isPlaying,
                  position: widget.position,
                  duration: widget.duration,
                  progress: _progress,
                  fmt: _fmt,
                  onPlayPause: widget.onPlayPause,
                  onNext: widget.onNext,
                  onPrev: widget.onPrev,
                  onStop: widget.onStop,
                  onMinimize: widget.onMinimize,
                  onSeek: (v) {
                    if (widget.onSeek != null && widget.duration.inMilliseconds > 0) {
                      final ms = (v.clamp(0.0, 1.0) * widget.duration.inMilliseconds).round();
                      widget.onSeek!(Duration(milliseconds: ms));
                    }
                  },
                ))))))
    ]);
  }
}

class _MediaCard extends StatelessWidget {
  final Song song;
  final bool isPlaying;
  final Duration position, duration;
  final double progress;
  final String Function(Duration) fmt;
  final VoidCallback onPlayPause, onNext, onPrev, onStop, onMinimize;
  final Function(double) onSeek;

  const _MediaCard({
    required this.song, required this.isPlaying,
    required this.position, required this.duration,
    required this.progress, required this.fmt,
    required this.onPlayPause, required this.onNext,
    required this.onPrev, required this.onStop,
    required this.onMinimize, required this.onSeek});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xEE12121E), Color(0xEE0D0D18)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        border: Border.all(color: AeroColors.glassBorder, width: 0.5),
        boxShadow: [
          BoxShadow(color: AeroColors.glow, blurRadius: 20, spreadRadius: -4),
          BoxShadow(color: Colors.black.withOpacity(0.5),
            blurRadius: 24, offset: const Offset(0, 8)),
        ]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Cover + info
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(children: [
            // Cover
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: song.coverPath != null
                ? Image.file(File(song.coverPath!),
                    width: 52, height: 52, fit: BoxFit.cover)
                : Container(width: 52, height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AeroColors.primary, AeroColors.secondary]),
                      borderRadius: const BorderRadius.all(Radius.circular(10))),
                    child: const Icon(Icons.music_note,
                      color: Colors.white, size: 26))),
            const SizedBox(width: 12),

            // Title + time
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(song.title,
                style: const TextStyle(
                  color: Colors.white, fontSize: 14,
                  fontWeight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(song.artist,
                style: const TextStyle(
                  color: Color(0x886A6A88), fontSize: 11),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text('${fmt(position)} / ${fmt(duration)}',
                style: const TextStyle(
                  color: Color(0x666A6A88), fontSize: 10)),
            ])),

            // Close
            GestureDetector(
              onTap: onStop,
              child: Container(
                padding: const EdgeInsets.all(4),
                child: const Icon(Icons.close_rounded,
                  color: Color(0x776A6A88), size: 16))),
          ])),

        // Progress bar (клікабельний + перетягуваний для перемотки)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              void handleSeek(double dx) {
                final fraction = (dx / constraints.maxWidth).clamp(0.0, 1.0);
                onSeek(fraction);
              }
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) => handleSeek(details.localPosition.dx),
                onHorizontalDragUpdate: (details) => handleSeek(details.localPosition.dx),
                child: Padding(
                  // Невелика вертикальна "подушка" — легше поцілити пальцем/мишкою
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      backgroundColor: Colors.white.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation(AeroColors.primary),
                      minHeight: 3)),
                ),
              );
            },
          ),
        ),

        // Controls
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Minimize
              _Btn(icon: Icons.remove_rounded,
                onTap: onMinimize, size: 18,
                color: const Color(0x776A6A88)),
              const Spacer(),

              // Prev
              _Btn(icon: Icons.skip_previous_rounded,
                onTap: onPrev, size: 22),

              const SizedBox(width: 8),

              // Play/Pause — головна кнопка
              GestureDetector(
                onTap: onPlayPause,
                child: Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AeroColors.primary, AeroColors.secondary]),
                    boxShadow: [
                      BoxShadow(color: AeroColors.glow, blurRadius: 12)]),
                  child: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white, size: 22))),

              const SizedBox(width: 8),

              // Next
              _Btn(icon: Icons.skip_next_rounded,
                onTap: onNext, size: 22),

              const Spacer(),

              // Empty space for symmetry
              const SizedBox(width: 34),
            ])),
      ]));
  }
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final Color color;

  const _Btn({required this.icon, required this.onTap,
    this.size = 20, this.color = AeroColors.textSecondary});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.all(6),
      child: Icon(icon, color: color, size: size)));
}

