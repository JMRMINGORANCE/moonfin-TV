// TaquitoFlix: tarjeta de "Siguiente episodio" al estilo Netflix. La dibuja la
// tarjeta de Moonfin (NextUpOverlay), que sigue llevando la cuenta atrás, el
// foco del mando y las acciones; aquí solo cambia el aspecto.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/models/aggregated_item.dart';
import '../bounded_network_image.dart';
import 'cine_widgets.dart';

/// Devuelve la tarjeta ya colocada en la esquina inferior derecha.
Widget cineNextUpCard(
  BuildContext context, {
  required AggregatedItem item,
  required String? imageUrl,
  required int timeoutMs,
  required Animation<double> countdown,
  required VoidCallback onPlayNext,
  required VoidCallback onDismiss,
  FocusNode? focusNode,
  FocusNode? dismissFocusNode,
}) {
  final tv = cineIsTv;
  return Positioned(
    right: tv ? 48 : 16,
    left: tv ? null : 16,
    bottom: tv ? 120 : 96,
    child: _CineNextUpCard(
      item: item,
      imageUrl: imageUrl,
      timeoutMs: timeoutMs,
      countdown: countdown,
      onPlayNext: onPlayNext,
      onDismiss: onDismiss,
      focusNode: focusNode,
      dismissFocusNode: dismissFocusNode,
    ),
  );
}

class _CineNextUpCard extends StatelessWidget {
  final AggregatedItem item;
  final String? imageUrl;
  final int timeoutMs;
  final Animation<double> countdown;
  final VoidCallback onPlayNext;
  final VoidCallback onDismiss;
  final FocusNode? focusNode;
  final FocusNode? dismissFocusNode;

  const _CineNextUpCard({
    required this.item,
    required this.imageUrl,
    required this.timeoutMs,
    required this.countdown,
    required this.onPlayNext,
    required this.onDismiss,
    this.focusNode,
    this.dismissFocusNode,
  });

  @override
  Widget build(BuildContext context) {
    final tv = cineIsTv;
    final thumbW = tv ? 240.0 : 128.0;
    final number = item.parentIndexNumber != null && item.indexNumber != null
        ? 'T${item.parentIndexNumber}:E${item.indexNumber}'
        : null;
    final title = number == null ? item.name : '$number  ${item.name}';
    final thumb = ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: thumbW,
        height: thumbW * 9 / 16,
        child: imageUrl == null
            ? const ColoredBox(color: cineCardBg)
            : BoundedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                minWidth: 200,
                maxWidth: 480,
                errorBuilder: (_, _, _) => const ColoredBox(color: cineCardBg),
              ),
      ),
    );
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          cineText(context, 'SIGUIENTE EPISODIO', 'NEXT EPISODE'),
          style: TextStyle(
            color: cineMuted,
            fontSize: tv ? 15 : 11,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: tv ? 22 : 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
    final buttons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _NextUpButton(
          label: cineText(context, 'Ver créditos', 'Watch credits'),
          primary: false,
          focusNode: dismissFocusNode,
          onTap: onDismiss,
        ),
        const SizedBox(width: 10),
        _NextUpButton(
          label: cineText(context, 'Siguiente episodio', 'Next episode'),
          icon: Icons.play_arrow_rounded,
          primary: true,
          autofocus: focusNode == null,
          focusNode: focusNode,
          countdown: timeoutMs > 0 ? countdown : null,
          onTap: onPlayNext,
        ),
      ],
    );
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: EdgeInsets.all(tv ? 16 : 12),
        decoration: BoxDecoration(
          color: const Color(0xE6141414),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 24)],
        ),
        child: tv
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  thumb,
                  const SizedBox(width: 18),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [text, const SizedBox(height: 14), buttons],
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      thumb,
                      const SizedBox(width: 12),
                      Expanded(child: text),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerRight, child: buttons),
                ],
              ),
      ),
    );
  }
}

/// Botón de la tarjeta. El principal es blanco y se va llenando durante la
/// cuenta atrás, como en Netflix.
class _NextUpButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final bool primary;
  final bool autofocus;
  final FocusNode? focusNode;
  final Animation<double>? countdown;
  final VoidCallback onTap;

  const _NextUpButton({
    required this.label,
    required this.primary,
    required this.onTap,
    this.icon,
    this.autofocus = false,
    this.focusNode,
    this.countdown,
  });

  @override
  State<_NextUpButton> createState() => _NextUpButtonState();
}

class _NextUpButtonState extends State<_NextUpButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final tv = cineIsTv;
    final fg = widget.primary ? Colors.black : Colors.white;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, color: fg, size: tv ? 26 : 20),
          const SizedBox(width: 6),
        ],
        Text(
          widget.label,
          style: TextStyle(
            color: fg,
            fontSize: tv ? 18 : 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
    final countdown = widget.countdown;
    return Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent && cineIsActivateKey(event.logicalKey)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: tv && _focused ? 1.06 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: widget.primary
                  ? const Color(0xFFBDBDBD)
                  : const Color(0x33FFFFFF),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: tv && _focused ? Colors.white : Colors.transparent,
                width: 2,
              ),
            ),
            child: Stack(
              children: [
                if (widget.primary)
                  Positioned.fill(
                    child: countdown == null
                        ? const ColoredBox(color: Colors.white)
                        : AnimatedBuilder(
                            animation: countdown,
                            builder: (context, _) => FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: countdown.value.clamp(0.0, 1.0),
                              child: const ColoredBox(color: Colors.white),
                            ),
                          ),
                  ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: tv ? 20 : 14,
                    vertical: tv ? 11 : 8,
                  ),
                  child: content,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
