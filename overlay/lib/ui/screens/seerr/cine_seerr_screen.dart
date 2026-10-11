// Moonfin Cine: sección Seerr al estilo "Novedades" de las plataformas de
// streaming. Cabecera con la tendencia del momento y filas de tendencias,
// populares y próximos estrenos. Cada carátula indica si ya está disponible en
// tu servidor o si está solicitada. Al abrir un título se muestra la ficha de
// Seerr de Moonfin, desde donde se solicita.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repositories/seerr_repository.dart';
import '../../../data/services/seerr/seerr_api_models.dart';
import '../../../util/platform_detection.dart';
import '../../navigation/destinations.dart';
import '../../widgets/cine/cine_widgets.dart';
import '../../widgets/navigation_layout.dart';

class CineSeerrScreen extends StatefulWidget {
  const CineSeerrScreen({super.key});

  @override
  State<CineSeerrScreen> createState() => _CineSeerrScreenState();
}

class _SeerrRow {
  final String title;
  final List<SeerrDiscoverItem> items;
  const _SeerrRow(this.title, this.items);
}

class _CineSeerrScreenState extends State<CineSeerrScreen> {
  final ScrollController _scroll = ScrollController();
  final ValueNotifier<double> _scrollOffset = ValueNotifier(0);
  final FocusNode _heroPrimary = FocusNode(debugLabel: 'cine_seerr_hero');
  VoidCallback? _previousFocusContent;

  bool _loading = true;
  Object? _error;
  SeerrDiscoverItem? _hero;
  final List<_SeerrRow> _rows = [];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients) _scrollOffset.value = _scroll.offset;
    });
    _previousFocusContent =
        NavigationLayout.focusContentFromNavbarNotifier.value;
    NavigationLayout.focusContentFromNavbarNotifier.value = _focusContent;
    unawaited(_load());
  }

  @override
  void dispose() {
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

  Future<List<SeerrDiscoverItem>> _safe(
    Future<SeerrDiscoverPage> Function() f,
  ) async {
    try {
      final page = await f();
      return page.results
          .where((i) => i.mediaType != 'person')
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> _load() async {
    try {
      final repo = await GetIt.instance.getAsync<SeerrRepository>();
      await repo.ensureInitialized();
      final results = await Future.wait([
        _safe(() => repo.getTrending()),
        _safe(() => repo.getTrendingMovies()),
        _safe(() => repo.getTrendingTv()),
        _safe(() => repo.getUpcomingMovies()),
        _safe(() => repo.getUpcomingTv()),
        _safe(() => repo.getTopMovies()),
        _safe(() => repo.getTopTv()),
        _safe(() => repo.getWatchlist()),
      ]);
      if (!mounted) return;
      final trending = results[0];
      _hero = trending.firstWhere(
        (i) => (i.backdropPath ?? '').isNotEmpty,
        orElse: () => trending.isNotEmpty
            ? trending.first
            : const SeerrDiscoverItem(id: -1),
      );
      if (_hero!.id < 0) _hero = null;

      String t(String es, String en) => cineText(context, es, en);
      _rows
        ..clear()
        ..add(_SeerrRow(t('Tendencias ahora', 'Trending now'), trending))
        ..add(_SeerrRow(t('Películas del momento', 'Popular movies'), results[1]))
        ..add(_SeerrRow(t('Series del momento', 'Popular series'), results[2]))
        ..add(_SeerrRow(t('Próximos estrenos', 'Coming soon'), results[3]))
        ..add(_SeerrRow(t('Próximas series', 'Upcoming series'), results[4]))
        ..add(_SeerrRow(t('Películas más valoradas', 'Top rated movies'), results[5]))
        ..add(_SeerrRow(t('Series más valoradas', 'Top rated series'), results[6]))
        ..add(_SeerrRow(t('Mi lista de seguimiento', 'My watchlist'), results[7]));
      setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e;
        });
      }
    }
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

  CineTile _tile(SeerrDiscoverItem i) {
    final status = i.mediaInfo?.status;
    String? badge;
    var color = cineRed;
    if (status == 5) {
      badge = cineText(context, 'DISPONIBLE', 'AVAILABLE');
      color = const Color(0xFF1F9D55);
    } else if (status == 4) {
      badge = cineText(context, 'PARCIAL', 'PARTIAL');
      color = const Color(0xFF2C7BE5);
    } else if (status == 2 || status == 3) {
      badge = cineText(context, 'SOLICITADO', 'REQUESTED');
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

  @override
  Widget build(BuildContext context) {
    final mobile = PlatformDetection.useMobileUi;
    final hero = _hero;
    final upEdge = cineFocusNavbar;
    final leftEdge = cineNavbarIsLeft ? cineFocusNavbar : null;

    final chips = <Widget>[
      CineChip(
        label: cineText(context, 'Mis solicitudes', 'My requests'),
        onUpEdge: upEdge,
        onLeftEdge: leftEdge,
        onTap: () => context.push(Destinations.seerrRequests),
      ),
      CineChip(
        label: cineText(context, 'Explorar más', 'Explore more'),
        onUpEdge: upEdge,
        onTap: () => context.push('${Destinations.seerrDiscover}?classic=1'),
      ),
    ];

    final available = hero?.mediaInfo?.status == 5;

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
              child: Row(
                children: [
                  cinePageTitle(context, 'Seerr'),
                  const SizedBox(width: 24),
                  ...chips,
                ],
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: hero == null
              ? SizedBox(height: mobile ? 120 : 40)
              : CineHero(
                  mobileTopInset: 96,
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
                    final primaryLabel = available
                        ? cineText(context, 'Ver ahora', 'Watch now')
                        : cineText(context, 'Solicitar', 'Request');
                    final primaryIcon = available
                        ? Icons.play_arrow_rounded
                        : Icons.add_rounded;
                    final primary = CineButton(
                      focusNode: _heroPrimary,
                      autofocus: !mobile,
                      icon: primaryIcon,
                      label: primaryLabel,
                      primary: true,
                      expand: expand,
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
        if (_loading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator(color: cineRed)),
            ),
          ),
        if (_error != null)
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
        SliverList(
          delegate: SliverChildListDelegate([
            for (final row in _rows)
              if (row.items.isNotEmpty)
                CineRow(
                  key: ValueKey('cine_seerr_${row.title}'),
                  title: row.title,
                  tiles: [for (final i in row.items) _tile(i)],
                ),
          ]),
        ),
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
                  chips: chips,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
