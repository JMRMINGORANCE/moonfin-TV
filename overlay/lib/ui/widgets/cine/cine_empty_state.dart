// TaquitoFlix: estados vacíos y de error con Taquito, en lugar de mensajes
// técnicos ("Sin resultados", "Sin conexión con el servidor"…).

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'cine_widgets.dart';

class CineEmptyState extends StatelessWidget {
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData actionIcon;

  /// Más pequeño, para huecos dentro de una pantalla.
  final bool compact;

  const CineEmptyState({
    super.key,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.actionIcon = Icons.refresh_rounded,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final tv = cineIsTv;
    final size = compact ? (tv ? 110.0 : 90.0) : (tv ? 170.0 : 140.0);
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 32,
          vertical: compact ? 24 : 48,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // El logo de carga ya es la cabeza de Taquito (lo pone el script
              // de marca); si falta, un icono neutro.
              SizedBox(
                width: size,
                height: size,
                child: SvgPicture.asset(
                  'assets/icons/moonfin_logo.svg',
                  placeholderBuilder: (_) => Icon(
                    Icons.pets_rounded,
                    size: size * 0.6,
                    color: cineMuted,
                  ),
                ),
              ),
              SizedBox(height: compact ? 14 : 22),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: tv ? 26 : 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (message != null && message!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: cineMuted,
                    fontSize: tv ? 18 : 14,
                    height: 1.35,
                  ),
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                SizedBox(height: compact ? 16 : 24),
                CineButton(
                  autofocus: tv,
                  icon: actionIcon,
                  label: actionLabel!,
                  primary: true,
                  onTap: onAction!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
