import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/song.dart';
import '../player.dart';
import '../theme/app_theme.dart';
import '../theme/personalization.dart';

String _fmtDuration(Duration d) =>
    '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

/// Єдина палітра для міні- та повного плеєра. Коли в налаштуваннях
/// увімкнено шпалери — скло стає напівпрозорим і крізь нього видно фон.
class _PlayerSkin {
  // На мобільних фон задається через bgImagePath, а не wallpaperBg —
  // тому беремо уніфікований геттер, який це враховує.
  static bool get transparent => AppConfig.hasCustomBackground;
  static Color get accent => AppTheme.primary;
  static Color get accent2 => AppTheme.secondary;

  static Color get glassTop => Color(0xFF161622).withAlpha(transparent ? 74 : 236);
  static Color get glassBottom => Color(0xFF0B0B13).withAlpha(transparent ? 54 : 230);
  static Color get border => accent.withAlpha(transparent ? 92 : 66);
  static Color get textMuted => Color(0xFFB9B9D0).withAlpha(transparent ? 235 : 210);
}

/// Скляна поверхня — спільна для обох плеєрів.
class _Glass extends StatelessWidget {
  final Widget child;
  final double radius;
  const _Glass({required this.child, this.radius = 20});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_PlayerSkin.glassTop, _PlayerSkin.glassBottom],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: _PlayerSkin.border),
              boxShadow: [
                BoxShadow(
                  color: _PlayerSkin.accent.withAlpha(34),
                  blurRadius: 26,
                  spreadRadius: -10,
                ),
              ],
            ),
            child: child,
          ),
        ),
      );
}

/// Обкладинка з безпечним фолбеком і обмеженим decoding-розміром.
class _PlayerArt extends StatelessWidget {
  final String? path;
  final double size;
  final double radius;
  const _PlayerArt({this.path, required this.size, this.radius = 18});

  Widget _placeholder() => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [_PlayerSkin.accent, _PlayerSkin.accent2]),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Icon(Icons.music_note_rounded, size: size * 0.42, color: Colors.white),
      );

  @override
  Widget build(BuildContext context) {
    final exists = path != null && File(path!).existsSync();
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: exists
          ? Image.file(
              File(path!),
              width: size,
              height: size,
              fit: BoxFit.cover,
              cacheWidth: (size * 2).round(),
              cacheHeight: (size * 2).round(),
              errorBuilder: (_, _, _) => _placeholder(),
            )
          : _placeholder(),
    );
  }
}

/// Дає position/duration НАПРЯМУ зі стрімів плеєра — панель не «замерзає»,
/// навіть коли батьківський віджет не перемальовується.
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
          builder: (context, posSnap) => builder(
            context,
            posSnap.data ?? Duration.zero,
            durSnap.data ?? Duration.zero,
          ),
        ),
      );
}

/// Повзунок із стабільним перетягуванням: під час руху показує позицію
/// пальця, seek виконується один раз при відпусканні.
class _SeekBar extends StatefulWidget {
  final double trackHeight, thumbRadius, overlayRadius;
  const _SeekBar({
    this.trackHeight = 2,
    this.thumbRadius = 5,
    this.overlayRadius = 10,
  });

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
          data: SliderThemeData(
            trackHeight: widget.trackHeight,
            thumbShape: RoundSliderThumbShape(enabledThumbRadius: widget.thumbRadius),
            overlayShape: RoundSliderOverlayShape(overlayRadius: widget.overlayRadius),
            activeTrackColor: _PlayerSkin.accent,
            inactiveTrackColor: Colors.white.withAlpha(38),
            thumbColor: Colors.white,
            overlayColor: _PlayerSkin.accent.withAlpha(48),
          ),
          child: Slider(
            value: shown,
            onChangeStart: (v) => setState(() => _dragValue = v),
            onChanged: (v) => setState(() => _dragValue = v),
            onChangeEnd: (v) {
              if (duration.inSeconds > 0) {
                Player.seek(Duration(seconds: (v * duration.inSeconds).round()));
              }
              setState(() => _dragValue = null);
            },
          ),
        );
      });
}

class _PlayButton extends StatelessWidget {
  final bool isPlaying;
  final double size;
  final VoidCallback onPressed;
  const _PlayButton({
    required this.isPlaying,
    required this.onPressed,
    this.size = 64,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: [_PlayerSkin.accent, _PlayerSkin.accent2]),
          boxShadow: [
            BoxShadow(
              color: _PlayerSkin.accent.withAlpha(90),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: Colors.white,
            size: size * 0.55,
          ),
        ),
      );
}

class _SkipButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  const _SkipButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withAlpha(18),
          border: Border.all(color: Colors.white.withAlpha(22)),
        ),
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, color: _PlayerSkin.textMuted, size: 24),
        ),
      );
}

void _openFullPlayer(
  BuildContext context, {
  required Song song,
  required bool isPlaying,
  required VoidCallback onPlayPause,
  required VoidCallback onNext,
  required VoidCallback onPrev,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => MobileFullPlayer(
      song: song,
      isPlaying: isPlaying,
      onPlayPause: onPlayPause,
      onNext: onNext,
      onPrev: onPrev,
    ),
  );
}

/// Докований мобільний мініплеєр. Той самий скляний стиль, що й у повному.
class MobileMiniPlayer extends StatelessWidget {
  final Song song;
  final bool isPlaying;
  final Duration position, duration;
  final VoidCallback onPlayPause, onNext, onPrev, onStop;

  const MobileMiniPlayer({
    super.key,
    required this.song,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.onPlayPause,
    required this.onNext,
    required this.onPrev,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
      child: _Glass(
        radius: AppRadius.sheet,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const _SeekBar(trackHeight: 2, thumbRadius: 4, overlayRadius: 9),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 6, 8),
            child: Row(children: [
              // Тільки клікабельна область обкладинки/назви відкриває
              // повний плеєр — кнопки керування не викликають випадковий tap.
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _openFullPlayer(
                    context,
                    song: song,
                    isPlaying: isPlaying,
                    onPlayPause: onPlayPause,
                    onNext: onNext,
                    onPrev: onPrev,
                  ),
                  child: Row(children: [
                    _PlayerArt(path: song.coverPath, size: 42, radius: 12),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(song.title,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      _LiveProgress(builder: (context, position, duration) => Text(
                            '${_fmtDuration(position)} / ${_fmtDuration(duration)}',
                            style: TextStyle(color: _PlayerSkin.textMuted, fontSize: 10),
                          )),
                    ])),
                  ]),
                ),
              ),
              const SizedBox(width: 4),
              _SkipButton(icon: Icons.skip_previous_rounded, onPressed: onPrev),
              const SizedBox(width: 2),
              _PlayButton(size: 46, isPlaying: isPlaying, onPressed: onPlayPause),
              const SizedBox(width: 2),
              _SkipButton(icon: Icons.skip_next_rounded, onPressed: onNext),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
                icon: Icon(Icons.close_rounded, color: _PlayerSkin.textMuted, size: 20),
                onPressed: onStop,
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Повноекранний скляний плеєр. Акцентна обкладинка, назва, перемотка
/// і кнопки — усе в одій панелі, прозорій, коли ввімкнено шпалери.
class MobileFullPlayer extends StatelessWidget {
  final Song song;
  final bool isPlaying;
  final VoidCallback onPlayPause, onNext, onPrev;

  const MobileFullPlayer({
    super.key,
    required this.song,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onNext,
    required this.onPrev,
  });

  @override
  Widget build(BuildContext context) {
    final hasCover = song.coverPath != null && File(song.coverPath!).existsSync();
    final artSize = MediaQuery.of(context).size.width * 0.62;
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        // Розмите зображення обкладинки як тло (тільки без шпалер,
        // щоб фон користувача залишався видимим).
        if (hasCover && !_PlayerSkin.transparent)
          Positioned.fill(
            child: Opacity(
              opacity: 0.16,
              child: Image.file(File(song.coverPath!), fit: BoxFit.cover),
            ),
          ),
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_PlayerSkin.glassTop, _PlayerSkin.glassBottom],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            child: Column(children: [
              Container(width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(46),
                  borderRadius: BorderRadius.circular(2),
                )),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: Icon(Icons.close_rounded, color: _PlayerSkin.textMuted, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const Spacer(),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: _PlayerSkin.accent.withAlpha(70),
                      blurRadius: 42,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: _PlayerArt(path: song.coverPath, size: artSize, radius: 26),
              ),
              const SizedBox(height: 28),
              Text(song.title,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Text(song.artist,
                style: TextStyle(color: _PlayerSkin.textMuted, fontSize: 14)),
              const Spacer(),
              _Glass(
                radius: AppRadius.card,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
                  child: Column(children: [
                    const _SeekBar(trackHeight: 3, thumbRadius: 6, overlayRadius: 13),
                    _LiveProgress(builder: (context, position, duration) => Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_fmtDuration(position),
                              style: TextStyle(color: _PlayerSkin.textMuted, fontSize: 11)),
                            Text(_fmtDuration(duration),
                              style: TextStyle(color: _PlayerSkin.textMuted, fontSize: 11)),
                          ],
                        )),
                  ]),
                ),
              ),
              const SizedBox(height: 26),
              StreamBuilder<bool>(
                stream: Player.playingStream,
                initialData: isPlaying,
                builder: (context, snap) {
                  final playing = snap.data ?? isPlaying;
                  return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                    _SkipButton(
                      icon: Icons.skip_previous_rounded,
                      onPressed: () { Navigator.pop(context); onPrev(); },
                    ),
                    _PlayButton(size: 74, isPlaying: playing, onPressed: onPlayPause),
                    _SkipButton(
                      icon: Icons.skip_next_rounded,
                      onPressed: () { Navigator.pop(context); onNext(); },
                    ),
                  ]);
                },
              ),
              const Spacer(),
            ]),
          ),
        ),
      ]),
    );
  }
}
