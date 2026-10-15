// TaquitoFlix: Taquito animado para las esperas (arranque de la app y carga
// del reproductor). Mueve las orejas, sube y baja la cabeza con su sombra y
// parpadea de vez en cuando. Las capas las genera branding/make_layers.py.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CineTaquitoLoader extends StatefulWidget {
  final double size;

  const CineTaquitoLoader({super.key, this.size = 120});

  @override
  State<CineTaquitoLoader> createState() => _CineTaquitoLoaderState();
}

class _CineTaquitoLoaderState extends State<CineTaquitoLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat();

  static const _base = 'assets/icons/taquito_layer_';

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _layer(String name) => SvgPicture.asset(
        '$_base$name.svg',
        width: widget.size,
        height: widget.size,
        placeholderBuilder: (_) => const SizedBox.shrink(),
      );

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final body = _layer('body');
    final earLeft = _layer('ear_left');
    final earRight = _layer('ear_right');
    final face = _layer('face');
    final blink = _layer('blink');
    return SizedBox(
      width: size,
      height: size * 1.14,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          // Dos botes por vuelta, orejas al doble de ritmo y un parpadeo.
          final hop = math.sin(t * 4 * math.pi);
          final bob = -hop.abs() * size * 0.05;
          final ear = math.sin(t * 8 * math.pi) * 0.10;
          final blinking = t > 0.90 && t < 0.945;
          final shadow = 1 - hop.abs() * 0.25;
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                bottom: 0,
                child: Container(
                  width: size * 0.56 * shadow,
                  height: size * 0.07,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35 * shadow),
                    borderRadius: BorderRadius.all(Radius.elliptical(size, size * 0.07)),
                  ),
                ),
              ),
              Transform.translate(
                offset: Offset(0, bob),
                child: SizedBox(
                  width: size,
                  height: size,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      body,
                      Transform.rotate(
                        angle: -ear,
                        alignment: const Alignment(-0.23, -0.12),
                        child: earLeft,
                      ),
                      Transform.rotate(
                        angle: ear,
                        alignment: const Alignment(0.23, -0.12),
                        child: earRight,
                      ),
                      face,
                      Opacity(opacity: blinking ? 1 : 0, child: blink),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
