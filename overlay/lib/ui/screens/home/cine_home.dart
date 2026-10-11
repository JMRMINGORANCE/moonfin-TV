part of 'home_screen.dart';

// ---------------------------------------------------------------------------
// Moonfin Cine: portada al estilo de las plataformas de streaming. Cabecera
// destacada con Reproducir / Más información, filas de carátulas, "Seguir
// viendo" con barra de progreso roja y "Top 10" con números gigantes.
// Los componentes visuales viven en ui/widgets/cine/cine_widgets.dart.
// ---------------------------------------------------------------------------

const bool kCineHomeLayout = kCineUi;
const Color _cineBg = cineBg;

class _CineHome extends StatefulWidget {
  final HomeViewModel viewModel;
  final UserPreferences prefs;

  const _CineHome({required this.viewModel, required this.prefs});

  @override
  State<_CineHome> createState() => _CineHomeState();
}

class _CineHomeState extends State<_CineHome> {
  final ScrollController _scroll = ScrollController();
  final FocusNode _heroPlayFocus = FocusNode(debugLabel: 'cine_hero_play');
  final ValueNotifier<double> _scrollOffset = ValueNotifier(0);
  VoidCallback? _previousFocusContent;
  bool _initialFocusDone = false;

  @override
  void initState() {
    super.initState();
    widget.viewModel.addListener(_onDataChanged);
    widget.viewModel.mediaBarViewModel.addListener(_onDataChanged);
    _scroll.addListener(_onScroll);
    _previousFocusContent =
        NavigationLayout.focusContentFromNavbarNotifier.value;
    NavigationLayout.focusContentFromNavbarNotifier.value = _focusContent;
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_onDataChanged);
    widget.viewModel.mediaBarViewModel.removeListener(_onDataChanged);
    if (identical(
      NavigationLayout.focusContentFromNavbarNotifier.value,
      _focusContent,
    )) {
      NavigationLayout.focusContentFromNavbarNotifier.value =
          _previousFocusContent;
    }
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _heroPlayFocus.dispose();
    _scrollOffset.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.hasClients) _scrollOffset.value = _scroll.offset;
  }

  void _onDataChanged() {
    if (!mounted) return;
    setState(() {});
    if (!_initialFocusDone && PlatformDetection.useLeanbackUi) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _initialFocusDone) return;
        if (_heroPlayFocus.context != null) {
          _initialFocusDone = true;
          _heroPlayFocus.requestFocus();
        }
      });
    }
  }

  void _focusContent() {
    if (!mounted) return;
    if (_scroll.hasClients && _scroll.offset > 0) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
    _heroPlayFocus.requestFocus();
  }

  // -- datos ---------------------------------------------------------------

  static bool _isLandscapeRow(HomeRow row) =>
      row.rowType == HomeRowType.resume ||
      row.rowType == HomeRowType.nextUp ||
      row.rowType == HomeRowType.libraryTiles ||
      row.rowType == HomeRowType.libraryTilesSmall ||
      row.rowType == HomeRowType.liveTvOnNow ||
      row.rowType == HomeRowType.liveTv ||
      row.rowType == HomeRowType.activeRecordings;

  ({String itemId, String serverId, CineHeroData data})? _resolveHero(
    List<HomeRow> rows,
  ) {
    final slides = widget.viewModel.mediaBarViewModel.items;
    if (slides.isNotEmpty) {
      final s = slides.first;
      return (
        itemId: s.itemId,
        serverId: s.serverId,
        data: CineHeroData(
          title: s.title,
          overview: s.overview,
          backdropUrl: s.backdropUrl,
          posterUrl: s.posterUrl,
          logoUrl: s.logoUrl,
          metaLine: _meta(s.year, s.officialRating, s.genres),
        ),
      );
    }
    for (final row in rows) {
      if (row.rowType != HomeRowType.latestMedia &&
          row.rowType != HomeRowType.recentlyReleased) {
        continue;
      }
      for (final item in row.items) {
        if (item.serverId == 'seerr') continue;
        if (item.backdropImageTags.isEmpty) continue;
        final api = widget.viewModel.imageApiForServer(item.serverId);
        return (
          itemId: item.id,
          serverId: item.serverId,
          data: CineHeroData(
            title: item.name,
            overview: item.overview,
            backdropUrl: api.getBackdropImageUrl(
              item.id,
              maxWidth: 1920,
              tag: item.backdropImageTags.first,
            ),
            posterUrl: item.primaryImageTag == null
                ? null
                : api.getPrimaryImageUrl(
                    item.id,
                    maxHeight: 900,
                    tag: item.primaryImageTag,
                  ),
            logoUrl: item.logoImageTag == null
                ? null
                : api.getLogoImageUrl(
                    item.id,
                    maxWidth: 800,
                    tag: item.logoImageTag,
                  ),
            metaLine: _meta(
              item.productionYear,
              item.officialRating,
              item.genres,
            ),
          ),
        );
      }
    }
    return null;
  }

  static String _meta(int? year, String? rating, List<String> genres) {
    final parts = <String>[
      if (year != null) '$year',
      if (rating != null && rating.isNotEmpty) rating,
      ...genres.take(3),
    ];
    return parts.join('  •  ');
  }

  List<AggregatedItem> _top10(List<HomeRow> rows) {
    final seen = <String>{};
    final pool = <AggregatedItem>[];
    for (final row in rows) {
      if (row.rowType != HomeRowType.latestMedia &&
          row.rowType != HomeRowType.recentlyReleased &&
          row.rowType != HomeRowType.favorites) {
        continue;
      }
      for (final item in row.items) {
        if (item.serverId == 'seerr') continue;
        if (item.type != 'Movie' && item.type != 'Series') continue;
        if (item.primaryImageTag == null) continue;
        if (seen.add(item.id)) pool.add(item);
      }
    }
    pool.sort(
      (a, b) => (b.communityRating ?? 0).compareTo(a.communityRating ?? 0),
    );
    return pool.take(10).toList();
  }

  void _openItem(BuildContext context, HomeRow? row, AggregatedItem item) {
    final type = row?.rowType;
    if (type == HomeRowType.libraryTiles ||
        type == HomeRowType.libraryTilesSmall) {
      _ContentRowsState._navigateToLibrary(context, item);
    } else if (type == HomeRowType.genres && row?.id == 'genres') {
      context.push(Destinations.genre(item.name, genreId: item.id));
    } else if (type == HomeRowType.studios && row?.id == 'studios') {
      context.push(Destinations.studio(item.name));
    } else if (item.serverId == 'seerr') {
      _ContentRowsState._navigateToSeerrItem(context, item);
    } else {
      context.push(
        Destinations.itemOrPhoto(
          item.id,
          serverId: item.serverId,
          type: item.type,
          channelId: item.channelId,
        ),
      );
    }
  }

  String? _imageFor(AggregatedItem item, bool landscape, double height) {
    if (item.serverId == 'seerr') {
      return landscape
          ? _ContentRowsState._seerrTmdbImageUrl(
              item.rawData['BackdropPath'] as String?,
              780,
            )
          : _ContentRowsState._seerrTmdbImageUrl(
              item.rawData['PosterPath'] as String?,
              342,
            );
    }
    final api = widget.viewModel.imageApiForServer(item.serverId);
    final scale = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 2.0);
    if (landscape) {
      return _ContentRowsState._resolveLandscapeImageUrl(
        item,
        api,
        height,
        scale,
      );
    }
    return _ContentRowsState._resolveImageUrl(item, api, height, true, scale);
  }

  CineTile _tile(HomeRow? row, AggregatedItem item, bool landscape) {
    final posterW = cinePosterWidth(context);
    final h = landscape ? posterW * 1.75 * 9 / 16 : posterW * 1.5;
    String? subtitle;
    if (landscape && item.type == 'Episode') {
      final s = item.parentIndexNumber;
      final e = item.indexNumber;
      subtitle = (s != null && e != null) ? 'T$s:E$e  ${item.name}' : item.name;
    }
    final isProgressRow = row?.rowType == HomeRowType.resume ||
        row?.rowType == HomeRowType.nextUp;
    return CineTile(
      id: item.id,
      title: item.type == 'Episode' && landscape
          ? (item.seriesName ?? item.name)
          : item.name,
      subtitle: subtitle,
      imageUrl: _imageFor(item, landscape, h),
      progress: isProgressRow ? (item.playedPercentage ?? 0) / 100.0 : 0,
      onTap: () => _openItem(context, row, item),
      onLongPress: item.serverId == 'seerr'
          ? null
          : () => showContextMenu(context, item),
    );
  }

  // -- construcción --------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final allRows = widget.viewModel.rows;
    final hero = _resolveHero(allRows);
    final mobile = PlatformDetection.useMobileUi;
    final top10 = _top10(allRows);

    final rowWidgets = <Widget>[];
    var inserted = false;
    for (var i = 0; i < allRows.length; i++) {
      final row = allRows[i];
      if (row.rowType == HomeRowType.mediaBar || row.items.isEmpty) continue;
      final landscape = _isLandscapeRow(row);
      rowWidgets.add(
        CineRow(
          key: ValueKey('cine_row_${row.id}'),
          title: localizeHomeRowTitle(
            row: row,
            l10n: l10n,
            mergeContinueWatchingAndNextUp:
                widget.prefs.effectiveMergeContinueWatchingNextUp,
          ),
          tiles: [for (final it in row.items) _tile(row, it, landscape)],
          landscape: landscape,
          playOverlay: row.rowType == HomeRowType.resume ||
              row.rowType == HomeRowType.nextUp,
          onNearEnd: () => widget.viewModel.loadMoreForRow(i),
        ),
      );
      if (!inserted && top10.length >= 5) {
        inserted = true;
        rowWidgets.add(
          CineTop10Row(
            key: const ValueKey('cine_top10'),
            title: cineText(
              context,
              'Top 10 en tu biblioteca',
              'Top 10 in your library',
            ),
            tiles: [for (final it in top10) _tile(null, it, false)],
          ),
        );
      }
    }

    final loading = widget.viewModel.isLoading && allRows.isEmpty;
    final upEdge = cineFocusNavbar;
    final leftEdge = cineNavbarIsLeft ? cineFocusNavbar : null;

    return ColoredBox(
      color: cineBg,
      child: Stack(
        children: [
          CustomScrollView(
            controller: _scroll,
            slivers: [
              SliverToBoxAdapter(
                child: hero == null
                    ? SizedBox(height: mobile ? 140 : 200)
                    : CineHero(
                        data: hero.data,
                        buttons: (expand) => [
                          if (expand)
                            Expanded(
                              child: CineButton(
                                focusNode: _heroPlayFocus,
                                icon: Icons.play_arrow_rounded,
                                label: l10n.play,
                                primary: true,
                                expand: true,
                                onTap: () => _play(hero.itemId, hero.serverId),
                              ),
                            )
                          else
                            CineButton(
                              focusNode: _heroPlayFocus,
                              icon: Icons.play_arrow_rounded,
                              label: l10n.play,
                              primary: true,
                              onUpEdge: upEdge,
                              onLeftEdge: leftEdge,
                              onTap: () => _play(hero.itemId, hero.serverId),
                            ),
                          SizedBox(width: expand ? 10 : 12),
                          if (expand)
                            Expanded(
                              child: CineButton(
                                icon: Icons.info_outline_rounded,
                                label: cineText(context, 'Más info', 'More info'),
                                primary: false,
                                expand: true,
                                onTap: () => _info(hero.itemId, hero.serverId),
                              ),
                            )
                          else
                            CineButton(
                              icon: Icons.info_outline_rounded,
                              label: cineText(
                                context,
                                'Más información',
                                'More info',
                              ),
                              primary: false,
                              onUpEdge: upEdge,
                              onTap: () => _info(hero.itemId, hero.serverId),
                            ),
                        ],
                      ),
              ),
              if (loading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(
                      child: CircularProgressIndicator(color: cineRed),
                    ),
                  ),
                ),
              SliverList(delegate: SliverChildListDelegate(rowWidgets)),
              SliverToBoxAdapter(child: SizedBox(height: mobile ? 120 : 80)),
            ],
          ),
          if (mobile)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: CineMobileTopBar(
                scrollOffset: _scrollOffset,
                chips: _mobileChips(context, allRows),
              ),
            ),
        ],
      ),
    );
  }

  void _play(String itemId, String serverId) => context.push(
        Destinations.item(itemId, serverId: serverId, autoPlay: true),
      );

  void _info(String itemId, String serverId) =>
      context.push(Destinations.item(itemId, serverId: serverId));

  List<Widget> _mobileChips(BuildContext context, List<HomeRow> rows) {
    final libraries = <AggregatedItem>[];
    for (final row in rows) {
      if (row.rowType == HomeRowType.libraryTiles ||
          row.rowType == HomeRowType.libraryTilesSmall) {
        libraries.addAll(row.items);
        break;
      }
    }
    AggregatedItem? byType(String collectionType) => libraries.firstWhereOrNull(
          (l) => l.rawData['CollectionType'] == collectionType,
        );
    final shows = byType('tvshows');
    final movies = byType('movies');
    final seerr = GetIt.instance<PluginSyncService>().seerrAvailable;
    final l10n = AppLocalizations.of(context);
    return [
      if (shows != null)
        CineChip(
          label: l10n.series,
          onTap: () => _ContentRowsState._navigateToLibrary(context, shows),
        ),
      if (movies != null)
        CineChip(
          label: l10n.movies,
          onTap: () => _ContentRowsState._navigateToLibrary(context, movies),
        ),
      if (seerr)
        CineChip(
          label: l10n.seerr,
          onTap: () => context.push(Destinations.seerrDiscover),
        ),
    ];
  }
}
