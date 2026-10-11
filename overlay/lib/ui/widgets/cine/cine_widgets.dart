// Moonfin Cine: componentes compartidos con estética de plataforma de
// streaming (filas de carátulas, Top 10, cabecera destacada, botones y foco
// con el mando a distancia). Los usan la portada, las bibliotecas, Seerr y la
// ficha de detalle.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';

import '../../../preference/preference_constants.dart';
import '../../../preference/user_preferences.dart';
import '../../../util/platform_detection.dart';
import '../bounded_network_image.dart';
import '../navigation_layout.dart';

/// Compila con --dart-define=CINE_CLASSIC_UI=true para recuperar las
/// pantallas originales de Moonfin.
const bool kCineUi = !bool.fromEnvironment('CINE_CLASSIC_UI');

const Color cineRed = Color(0xFFE50914);
const Color cineBg = Color(0xFF000000);
const Color cineSurface = Color(0xFF141414);
const Color cineCardBg = Color(0xFF232323);
const Color cineGreyButton = Color(0x806D6D6E);
const Color cineMuted = Color(0xFFB3B3B3);
const Color cineGreen = Color(0xFF46D369);

String cineText(BuildContext context, String es, String en) =>
    Localizations.localeOf(context).languageCode == 'es' ? es : en;

bool get cineIsTv => !PlatformDetection.useMobileUi;

bool cineIsActivateKey(LogicalKeyboardKey key) =>
    key == LogicalKeyboardKey.enter ||
    key == LogicalKeyboardKey.numpadEnter ||
    key == LogicalKeyboardKey.select ||
    key == LogicalKeyboardKey.space ||
    key == LogicalKeyboardKey.gameButtonA;

void cineFocusNavbar() {
  final focusNavbar = NavigationLayout.focusNavbarNotifier.value;
  if (focusNavbar != null) focusNavbar();
}

bool get cineNavbarIsLeft =>
    GetIt.instance<UserPreferences>().get(UserPreferences.navbarPosition) ==
    NavbarPosition.left;

double cineSidePadding(BuildContext context) {
  if (PlatformDetection.useMobileUi) return 12;
  final w = MediaQuery.sizeOf(context).width * 0.045;
  if (!cineNavbarIsLeft) return w;
  return w < 96 ? 96 : w + 24;
}

double cinePosterWidth(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (PlatformDetection.useMobileUi) return (w / 3.4).clamp(96.0, 150.0);
  return (w / 7.6).clamp(120.0, 240.0);
}

String cineTmdbImage(String? path, int width) {
  if (path == null || path.isEmpty) return '';
  if (path.startsWith('http')) return path;
  return 'https://image.tmdb.org/t/p/w$width$path';
}

String cineRuntime(BuildContext context, int? ticks) {
  if (ticks == null || ticks <= 0) return '';
  final minutes = (ticks / 600000000).round();
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h h' : '$h h $m min';
}

// ---------------------------------------------------------------------------
// Foco: un elemento enfocable que se maneja igual con el mando de Android TV,
// el de Samsung (Tizen), el teclado o el dedo.
// ---------------------------------------------------------------------------

typedef CineArrowHandler = bool Function(TraversalDirection direction);

class CineFocusable extends StatefulWidget {
  final FocusNode? focusNode;
  final bool autofocus;
  final VoidCallback? onActivate;
  final VoidCallback? onLongPress;

  /// Se llama antes de mover el foco. Devuelve true si lo ha gestionado.
  final CineArrowHandler? onArrow;

  /// Se llama cuando no hay nada más hacia arriba / izquierda.
  final VoidCallback? onUpEdge;
  final VoidCallback? onLeftEdge;
  final ValueChanged<bool>? onFocusChange;
  final double scrollAlignment;
  final Widget Function(BuildContext context, bool focused) builder;

  const CineFocusable({
    super.key,
    this.focusNode,
    this.autofocus = false,
    this.onActivate,
    this.onLongPress,
    this.onArrow,
    this.onUpEdge,
    this.onLeftEdge,
    this.onFocusChange,
    this.scrollAlignment = 0.5,
    required this.builder,
  });

  @override
  State<CineFocusable> createState() => _CineFocusableState();
}

class _CineFocusableState extends State<CineFocusable> {
  bool _focused = false;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (event is KeyDownEvent && cineIsActivateKey(key)) {
      if (widget.onActivate == null) return KeyEventResult.ignored;
      widget.onActivate!();
      return KeyEventResult.handled;
    }
    final TraversalDirection? dir;
    if (key == LogicalKeyboardKey.arrowUp) {
      dir = TraversalDirection.up;
    } else if (key == LogicalKeyboardKey.arrowDown) {
      dir = TraversalDirection.down;
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      dir = TraversalDirection.left;
    } else if (key == LogicalKeyboardKey.arrowRight) {
      dir = TraversalDirection.right;
    } else {
      dir = null;
    }
    if (dir == null) return KeyEventResult.ignored;
    if (widget.onArrow != null && widget.onArrow!(dir)) {
      return KeyEventResult.handled;
    }
    if (node.focusInDirection(dir)) return KeyEventResult.handled;
    if (dir == TraversalDirection.up && widget.onUpEdge != null) {
      widget.onUpEdge!();
      return KeyEventResult.handled;
    }
    if (dir == TraversalDirection.left && widget.onLeftEdge != null) {
      widget.onLeftEdge!();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onKeyEvent: _onKey,
      onFocusChange: (f) {
        if (mounted) setState(() => _focused = f);
        widget.onFocusChange?.call(f);
        if (f) {
          Scrollable.ensureVisible(
            context,
            alignment: widget.scrollAlignment,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
          );
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onActivate,
        onLongPress: widget.onLongPress,
        child: widget.builder(context, _focused),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Botones
// ---------------------------------------------------------------------------

class CineButton extends StatelessWidget {
  final FocusNode? focusNode;
  final IconData? icon;
  final String label;
  final bool primary;
  final bool expand;
  final bool autofocus;
  final VoidCallback onTap;
  final VoidCallback? onUpEdge;
  final VoidCallback? onLeftEdge;

  const CineButton({
    super.key,
    this.focusNode,
    this.icon,
    required this.label,
    required this.primary,
    required this.onTap,
    this.expand = false,
    this.autofocus = false,
    this.onUpEdge,
    this.onLeftEdge,
  });

  @override
  Widget build(BuildContext context) {
    final tv = cineIsTv;
    return CineFocusable(
      focusNode: focusNode,
      autofocus: autofocus,
      onActivate: onTap,
      onUpEdge: onUpEdge,
      onLeftEdge: onLeftEdge,
      scrollAlignment: 0.8,
      builder: (context, focused) {
        // En TV el botón enfocado se vuelve blanco; en táctil, el principal.
        final white = tv ? focused : primary;
        final fg = white ? Colors.black : Colors.white;
        final text = Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: fg,
            fontSize: tv ? 20 : 16,
            fontWeight: FontWeight.w700,
          ),
        );
        return AnimatedScale(
          scale: tv && focused ? 1.06 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: EdgeInsets.symmetric(
              horizontal: tv ? 26 : 18,
              vertical: tv ? 12 : 9,
            ),
            decoration: BoxDecoration(
              color: white ? Colors.white : cineGreyButton,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: fg, size: tv ? 30 : 26),
                  const SizedBox(width: 8),
                ],
                if (expand) Flexible(child: text) else text,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Chip de contorno (Series · Películas · Categorías…).
class CineChip extends StatelessWidget {
  final String label;
  final bool selected;
  final IconData? trailingIcon;
  final VoidCallback onTap;
  final FocusNode? focusNode;
  final VoidCallback? onUpEdge;
  final VoidCallback? onLeftEdge;

  const CineChip({
    super.key,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.trailingIcon,
    this.focusNode,
    this.onUpEdge,
    this.onLeftEdge,
  });

  @override
  Widget build(BuildContext context) {
    final tv = cineIsTv;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: CineFocusable(
        focusNode: focusNode,
        onActivate: onTap,
        onUpEdge: onUpEdge,
        onLeftEdge: onLeftEdge,
        builder: (context, focused) {
          final filled = selected || focused;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: EdgeInsets.symmetric(
              horizontal: tv ? 20 : 14,
              vertical: tv ? 9 : 6,
            ),
            decoration: BoxDecoration(
              color: filled ? Colors.white : const Color(0x33000000),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xB3FFFFFF)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: filled ? Colors.black : Colors.white,
                    fontSize: tv ? 18 : 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (trailingIcon != null) ...[
                  const SizedBox(width: 4),
                  Icon(
                    trailingIcon,
                    size: tv ? 22 : 18,
                    color: filled ? Colors.black : Colors.white,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tarjetas y filas
// ---------------------------------------------------------------------------

/// Todo lo que una tarjeta necesita, venga de Jellyfin o de Seerr.
class CineTile {
  final String id;
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final double progress;
  final String? badge;
  final Color badgeColor;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const CineTile({
    required this.id,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.imageUrl,
    this.progress = 0,
    this.badge,
    this.badgeColor = cineRed,
    this.onLongPress,
  });
}

class CineCard extends StatelessWidget {
  final CineTile tile;
  final double width;
  final double imageHeight;
  final bool caption;
  final bool playOverlay;
  final FocusNode? focusNode;
  final VoidCallback? onUpEdge;
  final VoidCallback? onLeftEdge;

  const CineCard({
    super.key,
    required this.tile,
    required this.width,
    required this.imageHeight,
    this.caption = false,
    this.playOverlay = false,
    this.focusNode,
    this.onUpEdge,
    this.onLeftEdge,
  });

  @override
  Widget build(BuildContext context) {
    final tv = cineIsTv;
    final url = tile.imageUrl;
    final placeholder = Container(
      color: cineCardBg,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      child: Text(
        tile.title,
        textAlign: TextAlign.center,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: cineMuted, fontSize: 13),
      ),
    );

    final art = ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: width,
        height: imageHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (url != null && url.isNotEmpty)
              BoundedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                minWidth: 160,
                maxWidth: 720,
                fadeInDuration: const Duration(milliseconds: 150),
                errorBuilder: (_, _, _) => placeholder,
              )
            else
              placeholder,
            if (tile.badge != null)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: tile.badgeColor,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(4),
                    ),
                  ),
                  child: Text(
                    tile.badge!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            if (tile.progress > 0)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: 4,
                  color: const Color(0x99555555),
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: tile.progress.clamp(0.02, 1.0),
                    child: const ColoredBox(color: cineRed),
                  ),
                ),
              ),
            if (playOverlay)
              const Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x80000000),
                    border: Border.fromBorderSide(
                      BorderSide(color: Colors.white, width: 1.5),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    return CineFocusable(
      focusNode: focusNode,
      onActivate: tile.onTap,
      onLongPress: tile.onLongPress,
      onUpEdge: onUpEdge,
      onLeftEdge: onLeftEdge,
      builder: (context, focused) => SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedScale(
              scale: tv && focused ? 1.08 : 1.0,
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: tv && focused ? Colors.white : Colors.transparent,
                    width: 3,
                  ),
                  boxShadow: tv && focused
                      ? const [
                          BoxShadow(color: Color(0xCC000000), blurRadius: 18),
                        ]
                      : const [],
                ),
                child: art,
              ),
            ),
            if (caption) ...[
              const SizedBox(height: 6),
              Text(
                tile.subtitle == null
                    ? tile.title
                    : '${tile.title}\n${tile.subtitle}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: focused ? Colors.white : cineMuted,
                  fontSize: tv ? 15 : 12,
                  height: 1.25,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Widget cineSectionTitle(
  BuildContext context,
  String title, {
  double? topPadding,
}) {
  final mobile = PlatformDetection.useMobileUi;
  return Padding(
    padding: EdgeInsets.fromLTRB(
      cineSidePadding(context),
      topPadding ?? (mobile ? 18 : 26),
      16,
      mobile ? 8 : 12,
    ),
    child: Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: const Color(0xFFE5E5E5),
        fontSize: mobile ? 18 : 24,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// Fila horizontal de carátulas.
class CineRow extends StatelessWidget {
  final String title;
  final List<CineTile> tiles;
  final bool landscape;
  final bool playOverlay;
  final VoidCallback? onNearEnd;

  const CineRow({
    super.key,
    required this.title,
    required this.tiles,
    this.landscape = false,
    this.playOverlay = false,
    this.onNearEnd,
  });

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();
    final posterW = cinePosterWidth(context);
    final cardW = landscape ? posterW * 1.75 : posterW;
    final imageH = landscape ? cardW * 9 / 16 : posterW * 1.5;
    final rowH = imageH + (landscape ? 56 : 0) + 24;
    final pad = cineSidePadding(context);
    final leftEdge = cineNavbarIsLeft ? cineFocusNavbar : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        cineSectionTitle(context, title),
        SizedBox(
          height: rowH,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: EdgeInsets.symmetric(horizontal: pad, vertical: 8),
            itemCount: tiles.length,
            itemBuilder: (context, index) {
              if (onNearEnd != null && index >= tiles.length - 6) {
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => onNearEnd!(),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: CineCard(
                  tile: tiles[index],
                  width: cardW,
                  imageHeight: imageH,
                  caption: landscape,
                  playOverlay: playOverlay,
                  onLeftEdge: index == 0 ? leftEdge : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Fila "Top 10" con números gigantes contorneados.
class CineTop10Row extends StatelessWidget {
  final String title;
  final List<CineTile> tiles;

  const CineTop10Row({super.key, required this.title, required this.tiles});

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();
    final posterW = cinePosterWidth(context);
    final posterH = posterW * 1.5;
    final numberW = posterW * 0.62;
    final pad = cineSidePadding(context);
    final leftEdge = cineNavbarIsLeft ? cineFocusNavbar : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        cineSectionTitle(context, title),
        SizedBox(
          height: posterH + 24,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: EdgeInsets.symmetric(horizontal: pad, vertical: 8),
            itemCount: tiles.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: numberW,
                      height: posterH,
                      child: FittedBox(
                        fit: BoxFit.contain,
                        alignment: Alignment.bottomRight,
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 200,
                            fontWeight: FontWeight.w900,
                            height: 1.0,
                            letterSpacing: -12,
                            foreground: Paint()
                              ..style = PaintingStyle.stroke
                              ..strokeWidth = 6
                              ..color = const Color(0xFF8C8C8C),
                          ),
                        ),
                      ),
                    ),
                    CineCard(
                      tile: tiles[index],
                      width: posterW,
                      imageHeight: posterH,
                      onLeftEdge: index == 0 ? leftEdge : null,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Rejilla de carátulas (Más títulos similares, Ver todo…).
class CineGrid extends StatelessWidget {
  final List<CineTile> tiles;
  final int? columns;
  final FocusNode? firstFocusNode;
  final VoidCallback? onUpEdge;

  const CineGrid({
    super.key,
    required this.tiles,
    this.columns,
    this.firstFocusNode,
    this.onUpEdge,
  });

  @override
  Widget build(BuildContext context) {
    final pad = cineSidePadding(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth - pad * 2;
        final cols = columns ??
            (PlatformDetection.useMobileUi
                ? 3
                : (available / 190).floor().clamp(4, 9));
        const gap = 8.0;
        final w = (available - gap * (cols - 1)) / cols;
        final leftEdge = cineNavbarIsLeft ? cineFocusNavbar : null;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: pad),
          child: Wrap(
            spacing: gap,
            runSpacing: gap + 4,
            children: [
              for (var i = 0; i < tiles.length; i++)
                CineCard(
                  tile: tiles[i],
                  width: w,
                  imageHeight: w * 1.5,
                  focusNode: i == 0 ? firstFocusNode : null,
                  onUpEdge: i < cols ? onUpEdge : null,
                  onLeftEdge: i % cols == 0 ? leftEdge : null,
                ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Cabecera destacada
// ---------------------------------------------------------------------------

class CineHeroData {
  final String title;
  final String? overview;
  final String? backdropUrl;
  final String? posterUrl;
  final String? logoUrl;
  final String metaLine;
  final String? eyebrow;

  const CineHeroData({
    required this.title,
    this.overview,
    this.backdropUrl,
    this.posterUrl,
    this.logoUrl,
    this.metaLine = '',
    this.eyebrow,
  });
}

Widget cineTitleOrLogo(
  CineHeroData data,
  double maxWidth,
  double fontSize,
  TextAlign align,
) {
  final title = Text(
    data.title,
    textAlign: align,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      color: Colors.white,
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      height: 1.05,
      shadows: const [Shadow(blurRadius: 12, color: Colors.black87)],
    ),
  );
  final logo = data.logoUrl;
  if (logo == null || logo.isEmpty) return title;
  return ConstrainedBox(
    constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: fontSize * 3),
    child: BoundedNetworkImage(
      imageUrl: logo,
      fit: BoxFit.contain,
      alignment: align == TextAlign.center
          ? Alignment.bottomCenter
          : Alignment.bottomLeft,
      minWidth: 320,
      maxWidth: 800,
      priority: ImageFetchPriority.high,
      errorBuilder: (_, _, _) => title,
    ),
  );
}

/// Cabecera a pantalla completa (TV / horizontal) o carátula grande (móvil).
class CineHero extends StatelessWidget {
  final CineHeroData data;

  /// Botones, de izquierda a derecha. Se reciben ya construidos.
  final List<Widget> Function(bool expand) buttons;

  /// Espacio extra arriba en móvil (para la barra de chips).
  final double mobileTopInset;

  const CineHero({
    super.key,
    required this.data,
    required this.buttons,
    this.mobileTopInset = 56,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final portrait = size.height > size.width;
    if (PlatformDetection.useMobileUi && portrait) {
      return _posterCard(context, size);
    }
    return _fullBleed(context, size);
  }

  Widget _eyebrow() {
    final e = data.eyebrow;
    if (e == null || e.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4,
            height: 16,
            color: cineRed,
          ),
          const SizedBox(width: 8),
          Text(
            e.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              letterSpacing: 2.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _posterCard(BuildContext context, Size size) {
    final backdrop = data.backdropUrl;
    final useBackdrop = backdrop != null && backdrop.isNotEmpty;
    final image = useBackdrop ? backdrop : data.posterUrl;
    final showTitle = useBackdrop || image == null || image.isEmpty;
    final topInset = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, topInset + mobileTopInset, 16, 8),
      child: AspectRatio(
        aspectRatio: 0.78,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(color: Color(0x66000000), blurRadius: 24),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (image != null && image.isNotEmpty)
                  BoundedNetworkImage(
                    imageUrl: image,
                    fit: BoxFit.cover,
                    alignment: useBackdrop
                        ? const Alignment(0.15, 0)
                        : Alignment.center,
                    minWidth: 480,
                    maxWidth: 1280,
                    priority: ImageFetchPriority.high,
                    errorBuilder: (_, _, _) =>
                        const ColoredBox(color: cineCardBg),
                  )
                else
                  const ColoredBox(color: cineCardBg),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.35, 0.7, 1.0],
                      colors: [
                        Color(0x00000000),
                        Color(0x99000000),
                        Color(0xF2000000),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _eyebrow(),
                      if (showTitle) ...[
                        cineTitleOrLogo(data, size.width * 0.6, 30,
                            TextAlign.center),
                        const SizedBox(height: 10),
                      ],
                      Text(
                        data.metaLine,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(children: buttons(true)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fullBleed(BuildContext context, Size size) {
    final tv = cineIsTv;
    final height = tv ? size.height * 0.78 : size.height * 0.72;
    final image = data.backdropUrl ?? data.posterUrl;
    final sidePad = cineSidePadding(context);
    final overview = data.overview;
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (image != null && image.isNotEmpty)
            BoundedNetworkImage(
              imageUrl: image,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              minWidth: 960,
              maxWidth: 1920,
              priority: ImageFetchPriority.high,
              fadeInDuration: const Duration(milliseconds: 300),
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: [0.0, 0.45, 0.8],
                colors: [
                  Color(0xE6000000),
                  Color(0x66000000),
                  Color(0x00000000),
                ],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.6, 1.0],
                colors: [Color(0x00000000), cineBg],
              ),
            ),
          ),
          Positioned(
            left: sidePad,
            bottom: height * 0.14,
            width: size.width * (tv ? 0.42 : 0.5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _eyebrow(),
                cineTitleOrLogo(
                  data,
                  size.width * 0.32,
                  tv ? 52 : 44,
                  TextAlign.start,
                ),
                const SizedBox(height: 14),
                if (data.metaLine.isNotEmpty)
                  Text(
                    data.metaLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                if (overview != null && overview.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    overview,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      height: 1.35,
                      shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                Row(mainAxisSize: MainAxisSize.min, children: buttons(false)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Barra superior de móvil: transparente sobre la cabecera y negra al bajar.
class CineMobileTopBar extends StatelessWidget {
  final ValueListenable<double> scrollOffset;
  final Widget? leading;
  final List<Widget> chips;

  const CineMobileTopBar({
    super.key,
    required this.scrollOffset,
    required this.chips,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return ValueListenableBuilder<double>(
      valueListenable: scrollOffset,
      builder: (context, offset, child) {
        final t = (offset / 160).clamp(0.0, 1.0);
        return Container(
          padding: EdgeInsets.fromLTRB(16, topInset + 8, 16, 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.lerp(const Color(0xB3000000), cineBg, t)!,
                Color.lerp(const Color(0x00000000), cineBg, t)!,
              ],
            ),
          ),
          child: child,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(height: 8)],
          if (chips.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: chips),
            ),
        ],
      ),
    );
  }
}

/// Título grande de página (Series, Películas, Seerr…) para TV y móvil.
Widget cinePageTitle(BuildContext context, String title) {
  final tv = cineIsTv;
  return Text(
    title,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      color: Colors.white,
      fontSize: tv ? 34 : 24,
      fontWeight: FontWeight.w800,
    ),
  );
}

/// Diálogo de lista a pantalla completa (selector de temporada, géneros…).
Future<int?> showCinePicker(
  BuildContext context, {
  required List<String> options,
  required int selected,
}) {
  return showGeneralDialog<int>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'cine_picker',
    barrierColor: const Color(0xE6000000),
    pageBuilder: (context, _, _) {
      final tv = cineIsTv;
      return Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < options.length; i++)
                        CineFocusable(
                          autofocus: i == (selected < 0 ? 0 : selected),
                          onActivate: () => Navigator.of(context).pop(i),
                          builder: (context, focused) => AnimatedScale(
                            scale: focused ? 1.12 : 1.0,
                            duration: const Duration(milliseconds: 120),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: tv ? 12 : 10,
                                horizontal: 24,
                              ),
                              child: Text(
                                options[i],
                                style: TextStyle(
                                  color: i == selected || focused
                                      ? Colors.white
                                      : cineMuted,
                                  fontSize: i == selected
                                      ? (tv ? 28 : 22)
                                      : (tv ? 24 : 18),
                                  fontWeight: i == selected
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.black),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
