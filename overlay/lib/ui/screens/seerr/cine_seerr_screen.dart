// TaquitoFlix: sección Seerr al estilo de las plataformas de streaming.
//
// Muestra directamente todas las categorías del explorador de Seerr (las
// mismas que "Explorar más": tendencias, populares, próximos estrenos, géneros
// de películas y series, estudios, cadenas, lista de seguimiento y las filas
// que el administrador haya creado en Seerr), sin solicitudes ni problemas:
// con la aprobación automática basta con pulsar "Descargar".

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../../data/services/seerr/seerr_api_models.dart';
import '../../../data/viewmodels/seerr_discover_view_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../../preference/preference_constants.dart';
import '../../../util/platform_detection.dart';
import '../../../util/seerr_genre_art.dart';
import '../../navigation/destinations.dart';
import '../../util/home_row_title_localizer.dart';
import '../../widgets/bounded_network_image.dart';
import '../../widgets/cine/cine_widgets.dart';
import '../../widgets/navigation_layout.dart';

class CineSeerrScreen extends StatefulWidget {
  const CineSeerrScreen({super.key});

  @override
  State<CineSeerrScreen> createState() => _CineSeerrScreenState();
}

class _CineSeerrScreenState extends State<CineSeerrScreen> {
  final ScrollController _scroll = ScrollController();
  final ValueNotifier<double> _scrollOffset = ValueNotifier(0);
  final FocusNode _heroPrimary = FocusNode(debugLabel: 'cine_seerr_hero');
  VoidCallback? _previousFocusContent;
  SeerrDiscoverViewModel? _vm;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients) _scrollOffset.value = _scroll.offset;
    });
    _previousFocusContent =
        NavigationLayout.focusContentFromNavbarNotifier.value;
    NavigationLayout.focusContentFromNavbarNotifier.value = _focusContent;
    unawaited(_init());
  }

  Future<void> _init() async {
    final vm = await GetIt.instance.getAsync<SeerrDiscoverViewModel>();
    if (!mounted) return;
    vm.addListener(_onChanged);
    setState(() => _vm = vm);
    unawaited(vm.load());
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _vm?.removeListener(_onChanged);
    if (identical(
      NavigationLayout.focusContentFromNavbarNotifier.value,
      _focusContent,
    )) {
      NavigationLayout.focusContentFromNavbarNotifier.value =
          _previousFocusContent;
    }
    _scroll.dispose();
    _scrollOffset.dispose();
    _heroPrimary.dispose();
    super.dispose();
  }

  void _focusContent() {
    if (!mounted) return;
    if (_heroPrimary.context != null) _heroPrimary.requestFocus();
  }

  // -- datos ---------------------------------------------------------------

  static bool _hidden(SeerrDiscoverRow row) =>
      row.type == SeerrRowType.shortcuts ||
      row.type == SeerrRowType.recentRequests;

  SeerrDiscoverItem? _pickHero(List<SeerrDiscoverRow> rows) {
    SeerrDiscoverItem? fallback;
    for (final row in rows) {
      if (!row.isMediaRow || _hidden(row)) continue;
      for (final item in row.items) {
        if (item.mediaType == 'person') continue;
        if ((item.backdropPath ?? '').isNotEmpty) {
          if (row.type == SeerrRowType.trending) return item;
          fallback ??= item;
        }
      }
    }
    return fallback;
  }

  String _title(SeerrDiscoverItem i) =>
      i.title ?? i.name ?? i.originalTitle ?? i.originalName ?? '';

  String _year(SeerrDiscoverItem i) {
    final d = i.releaseDate ?? i.firstAirDate;
    return d != null && d.length >= 4 ? d.substring(0, 4) : '';
  }

  void _open(SeerrDiscoverItem i) => context.push(
        Destinations.seerrMedia(
          i.id.toString(),
          mediaType: i.mediaType ?? 'movie',
          title: _title(i),
        ),
      );

  void _browse({
    required String filterType,
    required int id,
    required String name,
    required String mediaType,
  }) {
    final uri = Uri(
      path: Destinations.seerrBrowse,
      queryParameters: {
        'filterId': id.toString(),
        'filterName': name,
        'mediaType': mediaType,
        'filterType': filterType,
      },
    );
    context.push(uri.toString());
  }

  /// Porcentaje descargado, si Seerr lo sabe (Radarr/Sonarr conectados).
  String? _progress(SeerrDiscoverItem i) {
    final list = i.mediaInfo?.downloadStatus;
    if (list == null || list.isEmpty) return null;
    var size = 0;
    var left = 0;
    for (final d in list) {
      size += d.size ?? 0;
      left += d.sizeLeft ?? 0;
    }
    if (size <= 0) return null;
    final pct = ((size - left) * 100 / size).clamp(0, 99).round();
    return '$pct %';
  }

  CineTile _tile(SeerrDiscoverItem i) {
    final status = i.mediaInfo?.status;
    String? badge;
    var color = cineRed;
    if (status == 5) {
      badge = cineText(context, 'YA DESCARGADA', 'DOWNLOADED');
      color = const Color(0xFF1F9D55);
    } else if (status == 4) {
      badge = cineText(context, 'PARCIAL', 'PARTIAL');
      color = const Color(0xFF2C7BE5);
    } else if (status == 2 || status == 3) {
      final progress = _progress(i);
      badge = cineText(context, 'DESCARGANDO', 'DOWNLOADING') +
          (progress == null ? '' : ' $progress');
      color = const Color(0xFFD08A00);
    }
    return CineTile(
      id: '${i.mediaType}_${i.id}',
      title: _title(i),
      imageUrl: cineTmdbImage(i.posterPath, 342),
      badge: badge,
      badgeColor: color,
      onTap: () => _open(i),
    );
  }

  Widget _buildRow(
    BuildContext context,
    SeerrDiscoverRow row,
    int index,
    AppLocalizations l10n,
  ) {
    final title = row.slider?.title ?? localizeSeerrRowTitle(row.type!, l10n);

    if (row.isGenreRow) {
      final mediaType = row.type == SeerrRowType.movieGenres ? 'movie' : 'tv';
      return _CineCategoryRow(
        key: ValueKey('cine_seerr_${row.key}'),
        title: title,
        items: [
          for (final g in row.genres)
            _CategoryItem(
              label: g.name,
              imageUrl: seerrGenreBackdropUrl(g.id, g.backdrops),
              onTap: () => _browse(
                filterType: 'genre',
                id: g.id,
                name: g.name,
                mediaType: mediaType,
              ),
            ),
        ],
      );
    }
    if (row.isNetworkRow) {
      return _CineCategoryRow(
        key: ValueKey('cine_seerr_${row.key}'),
        title: title,
        logos: true,
        items: [
          for (final n in row.networks)
            _CategoryItem(
              label: n.name,
              imageUrl: n.logoPath == null
                  ? null
                  : cineTmdbImage(n.logoPath, 500),
              onTap: () => _browse(
                filterType: 'network',
                id: n.id,
                name: n.name,
                mediaType: 'tv',
              ),
            ),
        ],
      );
    }
    if (row.isStudioRow) {
      return _CineCategoryRow(
        key: ValueKey('cine_seerr_${row.key}'),
        title: title,
        logos: true,
        items: [
          for (final s in row.studios)
            _CategoryItem(
              label: s.name,
              imageUrl: s.logoPath == null
                  ? null
                  : cineTmdbImage(s.logoPath, 500),
              onTap: () => _browse(
                filterType: 'studio',
                id: s.id,
                name: s.name,
                mediaType: 'movie',
              ),
            ),
        ],
      );
    }
    final items =
        row.items.where((i) => i.mediaType != 'person').toList(growable: false);
    return CineRow(
      key: ValueKey('cine_seerr_${row.key}'),
      title: title,
      tiles: [for (final i in items) _tile(i)],
      onNearEnd: row.hasMore && !row.isLoading
          ? () {
              final vm = _vm;
              if (vm != null) unawaited(vm.loadMore(index));
            }
          : null,
    );
  }

  // -- construcción --------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final mobile = PlatformDetection.useMobileUi;
    final leftEdge = cineNavbarIsLeft ? cineFocusNavbar : null;
    final vm = _vm;
    final rows = vm?.rows ?? const <SeerrDiscoverRow>[];
    final hero = _pickHero(rows);
    final available = hero?.mediaInfo?.status == 5;
    final loading = vm == null || (vm.isLoading && rows.isEmpty);
    final error = vm?.error;

    final rowWidgets = <Widget>[
      for (var i = 0; i < rows.length; i++)
        if (!_hidden(rows[i]) &&
            (rows[i].items.isNotEmpty ||
                rows[i].genres.isNotEmpty ||
                rows[i].networks.isNotEmpty ||
                rows[i].studios.isNotEmpty))
          _buildRow(context, rows[i], i, l10n),
    ];

    final content = CustomScrollView(
      controller: _scroll,
      slivers: [
        if (!mobile)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                cineSidePadding(context),
                MediaQuery.paddingOf(context).top + 72,
                24,
                0,
              ),
              child: cinePageTitle(context, 'Seerr'),
            ),
          ),
        SliverToBoxAdapter(
          child: hero == null
              ? SizedBox(height: mobile ? 110 : 40)
              : CineHero(
                  mobileTopInset: 64,
                  data: CineHeroData(
                    title: _title(hero),
                    overview: hero.overview,
                    eyebrow: cineText(context, 'Tendencia nº 1', 'Trending #1'),
                    backdropUrl: cineTmdbImage(hero.backdropPath, 1280),
                    posterUrl: cineTmdbImage(hero.posterPath, 780),
                    metaLine: [
                      _year(hero),
                      if (hero.voteAverage != null && hero.voteAverage! > 0)
                        '★ ${hero.voteAverage!.toStringAsFixed(1)}',
                      hero.mediaType == 'tv'
                          ? cineText(context, 'Serie', 'Series')
                          : cineText(context, 'Película', 'Movie'),
                    ].where((s) => s.isNotEmpty).join('  •  '),
                  ),
                  buttons: (expand) {
                    final primary = CineButton(
                      focusNode: _heroPrimary,
                      autofocus: !mobile,
                      icon: available
                          ? Icons.play_arrow_rounded
                          : Icons.download_rounded,
                      label: available
                          ? cineText(context, 'Ver ahora', 'Watch now')
                          : cineText(context, 'Descargar', 'Download'),
                      primary: true,
                      expand: expand,
                      onUpEdge: cineFocusNavbar,
                      onLeftEdge: leftEdge,
                      onTap: () => _open(hero),
                    );
                    final info = CineButton(
                      icon: Icons.info_outline_rounded,
                      label: expand
                          ? cineText(context, 'Más info', 'More info')
                          : cineText(context, 'Más información', 'More info'),
                      primary: false,
                      expand: expand,
                      onUpEdge: cineFocusNavbar,
                      onTap: () => _open(hero),
                    );
                    return expand
                        ? [
                            Expanded(child: primary),
                            const SizedBox(width: 10),
                            Expanded(child: info),
                          ]
                        : [primary, const SizedBox(width: 12), info];
                  },
                ),
        ),
        if (loading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator(color: cineRed)),
            ),
          ),
        if (!loading && error != null && rows.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(48),
              child: Text(
                cineText(
                  context,
                  'No se ha podido conectar con Seerr.',
                  'Could not reach Seerr.',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(color: cineMuted, fontSize: 16),
              ),
            ),
          ),
        SliverList(delegate: SliverChildListDelegate(rowWidgets)),
        SliverToBoxAdapter(child: SizedBox(height: mobile ? 120 : 80)),
      ],
    );

    return Scaffold(
      backgroundColor: cineBg,
      body: NavigationLayout(
        activeRoute: Destinations.seerrDiscover,
        showBackButton: true,
        child: Stack(
          children: [
            Positioned.fill(child: content),
            if (mobile)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: CineMobileTopBar(
                  scrollOffset: _scrollOffset,
                  leading: Padding(
                    padding: const EdgeInsets.only(left: 56, top: 6),
                    child: cinePageTitle(context, 'Seerr'),
                  ),
                  chips: const [],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filas de categorías (géneros con imagen, estudios y cadenas con logotipo)
// ---------------------------------------------------------------------------

class _CategoryItem {
  final String label;
  final String? imageUrl;
  final VoidCallback onTap;

  const _CategoryItem({
    required this.label,
    required this.imageUrl,
    required this.onTap,
  });
}

class _CineCategoryRow extends StatelessWidget {
  final String title;
  final List<_CategoryItem> items;
  final bool logos;

  const _CineCategoryRow({
    super.key,
    required this.title,
    required this.items,
    this.logos = false,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final tv = cineIsTv;
    final w = cinePosterWidth(context) * 1.75;
    final h = w * (logos ? 0.5 : 9 / 16);
    final pad = cineSidePadding(context);
    final leftEdge = cineNavbarIsLeft ? cineFocusNavbar : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        cineSectionTitle(context, title),
        SizedBox(
          height: h + 24,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: EdgeInsets.symmetric(horizontal: pad, vertical: 8),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final url = item.imageUrl;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: CineFocusable(
                  onActivate: item.onTap,
                  onLeftEdge: index == 0 ? leftEdge : null,
                  builder: (context, focused) => AnimatedScale(
                    scale: tv && focused ? 1.08 : 1.0,
                    duration: const Duration(milliseconds: 140),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      width: w,
                      height: h,
                      decoration: BoxDecoration(
                        color: logos ? const Color(0xFF1C1C1C) : cineCardBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: tv && focused
                              ? Colors.white
                              : (logos
                                  ? const Color(0xFF2E2E2E)
                                  : Colors.transparent),
                          width: tv && focused ? 3 : 1,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: logos
                          ? Padding(
                              padding: EdgeInsets.all(h * 0.2),
                              child: url == null
                                  ? _label(item.label, tv)
                                  : BoundedNetworkImage(
                                      imageUrl: url,
                                      fit: BoxFit.contain,
                                      minWidth: 200,
                                      maxWidth: 500,
                                      errorBuilder: (_, _, _) =>
                                          _label(item.label, tv),
                                    ),
                            )
                          : Stack(
                              fit: StackFit.expand,
                              children: [
                                if (url != null)
                                  BoundedNetworkImage(
                                    imageUrl: url,
                                    fit: BoxFit.cover,
                                    minWidth: 320,
                                    maxWidth: 780,
                                    errorBuilder: (_, _, _) =>
                                        const SizedBox.shrink(),
                                  ),
                                const DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Color(0x40000000),
                                  ),
                                ),
                                _label(item.label, tv),
                              ],
                            ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _label(String text, bool tv) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            text,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: tv ? 22 : 16,
              fontWeight: FontWeight.w800,
              shadows: const [Shadow(blurRadius: 8, color: Colors.black)],
            ),
          ),
        ),
      );
}
