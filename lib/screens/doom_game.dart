import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MiniDoomGame extends StatefulWidget {
  const MiniDoomGame({super.key});
  @override
  State<MiniDoomGame> createState() => _MiniDoomGameState();
}

class _MiniDoomGameState extends State<MiniDoomGame> with SingleTickerProviderStateMixin {
  double _playerX = 2.5;
  double _playerY = 2.5;
  double _playerAngle = 0.0;
  int _health = 100;
  int _ammo = 50;
  int _kills = 0;
  bool _shooting = false;
  bool _gameOver = false;
  bool _win = false;

  final List<List<int>> _map = [
    [1,1,1,1,1],
    [1,0,0,0,1],
    [1,0,1,0,1],
    [1,0,0,0,1],
    [1,1,1,1,1],
  ];

  List<Map<String, double>> _enemies = [
    {'x': 1.5, 'y': 1.5, 'health': 3},
    {'x': 3.5, 'y': 1.5, 'health': 3},
    {'x': 1.5, 'y': 3.5, 'health': 3},
  ];

  late AnimationController _animController;
  Timer? _gameLoop;
  final Set<String> _keys = {};

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 100))..repeat();
    _gameLoop = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!_gameOver && !_win) _update();
    });
  }

  void _update() {
    const speed = 0.05;
    double newX = _playerX;
    double newY = _playerY;

    if (_keys.contains('w') || _keys.contains('arrowup')) {
      newX += speed * cos(_playerAngle);
      newY += speed * sin(_playerAngle);
    }
    if (_keys.contains('s') || _keys.contains('arrowdown')) {
      newX -= speed * cos(_playerAngle);
      newY -= speed * sin(_playerAngle);
    }
    if (_keys.contains('a') || _keys.contains('arrowleft')) {
      setState(() => _playerAngle -= 0.05);
    }
    if (_keys.contains('d') || _keys.contains('arrowright')) {
      setState(() => _playerAngle += 0.05);
    }

    if (newX > 0 && newX < 5 && newY > 0 && newY < 5) {
      if (_map[newY.toInt()][newX.toInt()] == 0) {
        setState(() { _playerX = newX; _playerY = newY; });
      }
    }

    for (var enemy in _enemies) {
      if (enemy['health']! <= 0) continue;
      final dx = _playerX - enemy['x']!;
      final dy = _playerY - enemy['y']!;
      final dist = sqrt(dx * dx + dy * dy);
      if (dist < 0.5) {
        setState(() => _health -= 1);
        if (_health <= 0) setState(() => _gameOver = true);
      } else if (dist < 3) {
        final ex = enemy['x']! + (dx / dist) * 0.02;
        final ey = enemy['y']! + (dy / dist) * 0.02;
        if (_map[ey.toInt()][ex.toInt()] == 0) {
          enemy['x'] = ex;
          enemy['y'] = ey;
        }
      }
    }

    if (_enemies.every((e) => e['health']! <= 0)) {
      setState(() => _win = true);
    }
  }

  void _shoot() {
    if (_ammo <= 0 || _gameOver || _win) return;
    setState(() { _ammo--; _shooting = true; });

    for (var enemy in _enemies) {
      if (enemy['health']! <= 0) continue;
      final dx = enemy['x']! - _playerX;
      final dy = enemy['y']! - _playerY;
      final dist = sqrt(dx * dx + dy * dy);
      if (dist > 3) continue;
      final angleToEnemy = atan2(dy, dx);
      double angleDiff = (angleToEnemy - _playerAngle).abs();
      if (angleDiff > pi) angleDiff = 2 * pi - angleDiff;
      if (angleDiff < 0.3) {
        enemy['health'] = enemy['health']! - 1;
        if (enemy['health']! <= 0) setState(() => _kills++);
      }
    }

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _shooting = false);
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _gameLoop?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: RawKeyboardListener(
        focusNode: FocusNode()..requestFocus(),
        onKey: (event) {
          final key = event.logicalKey.keyLabel.toLowerCase();
          if (event is RawKeyDownEvent) {
            _keys.add(key);
          } else if (event is RawKeyUpEvent) {
            _keys.remove(key);
          }
        },
        child: GestureDetector(
          onTap: _shoot,
          child: Stack(children: [
            CustomPaint(
              painter: DoomPainter(
                playerX: _playerX, playerY: _playerY, playerAngle: _playerAngle,
                map: _map, enemies: _enemies, shooting: _shooting,
              ),
              size: Size.infinite,
            ),
            Positioned(bottom: 20, left: 20,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('❤️ $_health', style: const TextStyle(color: Colors.red, fontSize: 24, fontWeight: FontWeight.bold)),
                Text('🔫 $_ammo', style: const TextStyle(color: Colors.yellow, fontSize: 20)),
                Text('💀 $_kills', style: const TextStyle(color: Colors.orange, fontSize: 20)),
              ])),
            Positioned(bottom: 20, right: 20,
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: const [
                Text('W/S - рух', style: TextStyle(color: Colors.white54, fontSize: 12)),
                Text('A/D - поворот', style: TextStyle(color: Colors.white54, fontSize: 12)),
                Text('TAP - стріляти', style: TextStyle(color: Colors.white54, fontSize: 12)),
              ])),
            const Center(child: Text('+', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold))),
            if (_shooting) Container(color: Colors.red.withOpacity(0.1)),
            if (_gameOver)
              Container(color: Colors.black87,
                child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('💀 YOU DIED', style: TextStyle(color: Colors.red, fontSize: 48, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C5CFC)),
                    child: const Text('Назад до плеєра')),
                ]))),
            if (_win)
              Container(color: Colors.black87,
                child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('🔥 YOU WIN!', style: TextStyle(color: Colors.green, fontSize: 48, fontWeight: FontWeight.bold)),
                  Text('Kills: $_kills', style: const TextStyle(color: Colors.orange, fontSize: 24)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C5CFC)),
                    child: const Text('Назад до плеєра')),
                ]))),
            Positioned(top: 20, left: 20,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context))),
          ]),
        ),
      ),
    );
  }
}

class DoomPainter extends CustomPainter {
  final double playerX, playerY, playerAngle;
  final List<List<int>> map;
  final List<Map<String, double>> enemies;
  final bool shooting;

  DoomPainter({
    required this.playerX, required this.playerY, required this.playerAngle,
    required this.map, required this.enemies, required this.shooting,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const fov = pi / 3;
    final numRays = size.width.toInt();
    final halfH = size.height / 2;

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, halfH), Paint()..color = const Color(0xFF1A0A2E));
    canvas.drawRect(Rect.fromLTWH(0, halfH, size.width, halfH), Paint()..color = const Color(0xFF2A1A0A));

    for (int i = 0; i < numRays; i++) {
      final rayAngle = playerAngle - fov / 2 + (i / numRays) * fov;
      final dist = _castRay(rayAngle);
      final wallH = (size.height / dist) * 0.8;
      final bright = (1 - dist / 8).clamp(0.0, 1.0);
      final wallColor = Color.fromRGBO((124 * bright).toInt(), (92 * bright).toInt(), (252 * bright).toInt(), 1);
      canvas.drawLine(
        Offset(i.toDouble(), halfH - wallH / 2),
        Offset(i.toDouble(), halfH + wallH / 2),
        Paint()..color = wallColor..strokeWidth = 1);
    }

    for (var enemy in enemies) {
      if (enemy['health']! <= 0) continue;
      final dx = enemy['x']! - playerX;
      final dy = enemy['y']! - playerY;
      final dist = sqrt(dx * dx + dy * dy);
      final angleToEnemy = atan2(dy, dx);
      double angleDiff = angleToEnemy - playerAngle;
      while (angleDiff > pi) angleDiff -= 2 * pi;
      while (angleDiff < -pi) angleDiff += 2 * pi;
      if (angleDiff.abs() < pi / 3) {
        final screenX = size.width / 2 + (angleDiff / (pi / 3)) * size.width / 2;
        final enemyH = (size.height / dist) * 0.6;
        final color = (1 - dist / 5).clamp(0.2, 1.0);
        canvas.drawRect(
          Rect.fromCenter(center: Offset(screenX, halfH), width: enemyH * 0.5, height: enemyH),
          Paint()..color = Color.fromRGBO((252 * color).toInt(), (92 * color).toInt(), (92 * color).toInt(), 1));
      }
    }
  }

  double _castRay(double angle) {
    double rayX = playerX;
    double rayY = playerY;
    final dx = cos(angle) * 0.05;
    final dy = sin(angle) * 0.05;
    for (int i = 0; i < 200; i++) {
      rayX += dx; rayY += dy;
      final mx = rayX.toInt(); final my = rayY.toInt();
      if (mx < 0 || mx >= 5 || my < 0 || my >= 5) return 8;
      if (map[my][mx] == 1) return sqrt((rayX - playerX) * (rayX - playerX) + (rayY - playerY) * (rayY - playerY));
    }
    return 8;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

