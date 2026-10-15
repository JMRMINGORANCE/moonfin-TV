// TaquitoFlix: protector de pantalla de la tele. Pasa los fondos de Taquito
// (los genera branding/make_wallpapers.py y el script de marca los deja en
// assets/images) con un fundido y un zoom lento, y enseña la hora y el logo.
// Moonfin se encarga de cuándo aparece y de quitarlo al tocar el mando.

import 'dart:async';

import 'package:flutter/material.dart';

class CineScreensaver extends StatefulWidget {
  const CineScreensaver({super.key});

  static const wallpapers = [
    'assets/images/taquito_wall_1.jpg',
    'assets/images/taquito_wall_2.jpg',
    'assets/images/taquito_wall_3.jpg',
  ];

  @override
  State<CineScreensaver> createState() => _CineScreensaverState();
}

class _CineScreensaverState extends State<CineScreensaver> {
  static const _slide = Duration(seconds: 20);

  int _index = 0;
  Timer? _timer;
  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_slide, (_) {
      if (mounted) {
        setState(() => _index = (_index + 1) % CineScreensaver.wallpapers.length);
      }
    });
    _clockTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final w in CineScreensaver.wallpapers) {
      precacheImage(AssetImage(w), context);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final time =
        '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}';
    // La hora y el logo cambian de esquina en cada fondo, para no marcar la
    // pantalla de la tele.
    final flip = _index.isOdd;
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 1500),
            child: _KenBurns(
              key: ValueKey(_index),
              asset: CineScreensaver.wallpapers[_index],
              duration: _slide,
              reverse: flip,
            ),
          ),
          // Velo suave para que la hora se lea sobre cualquier fondo.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.25, 0.75, 1.0],
                colors: [
                  Color(0x66000000),
                  Color(0x00000000),
                  Color(0x00000000),
                  Color(0x88000000),
                ],
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 1500),
            top: size.height * 0.06,
            left: flip ? null : size.width * 0.05,
            right: flip ? size.width * 0.05 : null,
            child: Opacity(
              opacity: 0.9,
              child: Image.asset(
                'assets/images/logo_and_text.png',
                height: size.height * 0.07,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 1500),
            bottom: size.height * 0.07,
            right: flip ? null : size.width * 0.05,
            left: flip ? size.width * 0.05 : null,
            child: Text(
              time,
              style: TextStyle(
                color: Colors.white,
                fontSize: size.height * 0.09,
                fontWeight: FontWeight.w300,
                letterSpacing: 2,
                shadows: const [Shadow(blurRadius: 16, color: Colors.black)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Un fondo con zoom muy lento (efecto Ken Burns).
class _KenBurns extends StatelessWidget {
  final String asset;
  final Duration duration;
  final bool reverse;

  const _KenBurns({
    super.key,
    required this.asset,
    required this.duration,
    required this.reverse,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      builder: (context, t, child) {
        final scale = reverse ? 1.10 - 0.08 * t : 1.02 + 0.08 * t;
        final dx = (reverse ? -1 : 1) * 0.02 * t;
        return Transform.scale(
          scale: scale,
          alignment: Alignment(dx * 20, 0),
          child: child,
        );
      },
      child: Image.asset(
        asset,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => const ColoredBox(color: Colors.black),
      ),
    );
  }
}
