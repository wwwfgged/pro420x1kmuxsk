import 'package:flutter/material.dart';
import '../models/song.dart';
import 'song_tile.dart';

class EditOpt {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback? onTap;
  EditOpt(this.icon, this.color, this.label, this.onTap);
}

class EditSheet extends StatelessWidget {
  final String title;
  final List<EditOpt> options;
  const EditSheet({super.key, required this.title, required this.options});

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.85,
    ),
    child: Container(
      decoration: const BoxDecoration(color: Color(0xFF12121A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: const Color(0xFF2A2A40), borderRadius: BorderRadius.circular(2))),
        Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
          maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ...options.map((o) => Material(color: Colors.transparent,
                child: InkWell(onTap: o.onTap, borderRadius: BorderRadius.circular(12),
                  child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    child: Row(children: [
                      Container(width: 38, height: 38,
                        decoration: BoxDecoration(color: o.color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                        child: Icon(o.icon, color: o.onTap != null ? o.color : o.color.withOpacity(0.3), size: 18)),
                      const SizedBox(width: 12),
                      Text(o.label, style: TextStyle(
                        color: o.onTap != null ? Colors.white : const Color(0xFF4A4A60),
                        fontSize: 14, fontWeight: FontWeight.w500)),
                    ])))))
            ]),
          ),
        ),
      ]),
    ),
  );
}

class MenuTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  const MenuTile({super.key, required this.icon, required this.color, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(color: Colors.transparent,
    child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12),
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
        child: Row(children: [
          Container(width: 42, height: 42,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22)),
          const SizedBox(width: 14),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
        ]))));
}

class SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;
  const SectionHeader({super.key, required this.icon, required this.title, required this.count});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(children: [
      Icon(icon, color: const Color(0xFF7C5CFC), size: 18),
      const SizedBox(width: 6),
      Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
      const SizedBox(width: 6),
      Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: const Color(0xFF7C5CFC).withOpacity(0.2),
          borderRadius: BorderRadius.circular(8)),
        child: Text('$count', style: const TextStyle(
          color: Color(0xFF7C5CFC), fontSize: 11, fontWeight: FontWeight.w600))),
    ]));
}

class PlaylistTile extends StatefulWidget {
  final MusicPlaylist playlist;
  final Song? currentSong;
  final bool editMode;
  final VoidCallback onDelete;
  final Function(Song) onPlaySong;
  final Function(Song) onSongMenu;
  const PlaylistTile({super.key, required this.playlist, this.currentSong, required this.editMode,
    required this.onDelete, required this.onPlaySong, required this.onSongMenu});

  @override
  State<PlaylistTile> createState() => _PlaylistTileState();
}

class _PlaylistTileState extends State<PlaylistTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final pl = widget.playlist;
    final hasActive = pl.songs.any((s) => s.filePath == widget.currentSong?.filePath);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: hasActive ? const Color(0xFF7C5CFC).withOpacity(0.1) : const Color(0xFF12121A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hasActive ? const Color(0xFF7C5CFC).withOpacity(0.4) : const Color(0xFF2A2A40))),
      child: Column(children: [
        InkWell(borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Container(width: 46, height: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF7C5CFC), Color(0xFFFC5C9C)]),
                  borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.queue_music_rounded, color: Colors.white, size: 24)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(pl.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white)),
                Text('${pl.songs.length} пісень', style: const TextStyle(color: Color(0xFF6A6A88), fontSize: 12)),
              ])),
              if (widget.editMode)
                IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                  padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                  onPressed: widget.onDelete),
              const SizedBox(width: 4),
              AnimatedRotation(turns: _expanded ? 0.5 : 0, duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF6A6A88), size: 22)),
            ]))),
        if (_expanded) ...[
          const Divider(color: Color(0xFF2A2A40), height: 1),
          ...pl.songs.map((s) => SongTile(
            song: s,
            active: widget.currentSong?.filePath == s.filePath,
            editMode: widget.editMode,
            onTap: () => widget.onPlaySong(s),
            onMenu: () => widget.onSongMenu(s),
            indent: true)),
        ],
      ]));
  }
}

class BottomNav extends StatelessWidget {
  final int current;
  final Function(int) onChange;
  const BottomNav({super.key, required this.current, required this.onChange});

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(color: Color(0xFF12121A),
      border: Border(top: BorderSide(color: Color(0xFF2A2A40)))),
    child: SafeArea(top: false, child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        NavItem(icon: Icons.music_note_rounded, label: 'Пісні', active: current == 0, onTap: () => onChange(0)),
        NavItem(icon: Icons.download_rounded, label: 'Завантажити', active: current == 1, onTap: () => onChange(1)),
      ]))));
}

class NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const NavItem({super.key, required this.icon, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: AnimatedContainer(duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF7C5CFC).withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(12)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: active ? const Color(0xFF7C5CFC) : const Color(0xFF6A6A88), size: 26),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11,
          color: active ? const Color(0xFF7C5CFC) : const Color(0xFF6A6A88),
          fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
      ])));
}

