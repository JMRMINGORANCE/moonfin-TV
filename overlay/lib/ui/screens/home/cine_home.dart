part of 'home_screen.dart';

// ---------------------------------------------------------------------------
// TaquitoFlix: portada al estilo de las plataformas de streaming. Cabecera
// destacada con Reproducir / Más información, "Seguir viendo" con barra de
// progreso roja, "Lo último añadido" de todas las bibliotecas, "Top 10" con
// números gigantes y el resto de filas.
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
  List<AggregatedItem> _latest = const [];
  bool _latestRequested = false;
  List<AggregatedItem> _downloaded = const [];
  bool _downloadedRequested = false;

  /// La portada solo dice "no encuentro tu biblioteca" después de haber
  /// intentado cargarla, no en el instante antes de empezar.
  bool _sawLoading = false;

  @override
  void initState() {
    super.initState();
    widget.viewModel.addListener(_onDataChanged);
    widget.viewModel.mediaBarViewModel.addListener(_onDataChanged);
    _scroll.addListener(_onScroll);
    _previousFocusContent =
        NavigationLayout.focusContentFromNavbarNotifier.value;
    NavigationLayout.focusContentFromNavbarNotifier.value = _focusContent;
    unawaited(_loadLatest());
    unawaited(_loadDownloaded());
  }

  /// Lo que se ha descargado con Seerr y ya se puede ver, lo más reciente
  /// primero. Se abre directamente la ficha del servidor.
  Future<void> _loadDownloaded() async {
    if (_downloadedRequested) return;
    if (!GetIt.instance<PluginSyncService>().seerrAvailable) return;
    _downloadedRequested = true;
    try {
      final repo = await GetIt.instance.getAsync<SeerrRepository>();
      await repo.ensureInitialized();
      final page = await repo.getRequests(
        filter: 'available',
        sort: 'modified',
        limit: 30,
      );
      // Seerr da el identificador de TMDB; se cruza con lo último añadido al
      // servidor, que lleva los mismos identificadores.
      final tmdbIds = <String>[];
      for (final r in page.results) {
        final id = r.media?.tmdbId?.toString();
        if (id != null && !tmdbIds.contains(id)) tmdbIds.add(id);
      }
      if (tmdbIds.isEmpty || !mounted) return;
      final client = GetIt.instance<MediaServerClient>();
      final response = await client.itemsApi.getItems(
        includeItemTypes: const ['Movie', 'Series'],
        recursive: true,
        sortBy: 'DateCreated',
        sortOrder: 'Descending',
        limit: 200,
        fields: 'ProviderIds,PrimaryImageAspectRatio,ProductionYear,UserData,'
            'DateCreated',
        enableImageTypes: 'Primary,Backdrop,Thumb',
        imageTypeLimit: 1,
      );
      final raw = response['Items'];
      if (raw is! List || !mounted) return;
      final serverId = widget.viewModel.rows
              .expand((r) => r.items)
              .firstWhereOrNull((i) => i.serverId != 'seerr')
              ?.serverId ??
          client.baseUrl;
      final byTmdb = <String, AggregatedItem>{};
      for (final m in raw) {
        if (m is! Map<String, dynamic> || m['Id'] == null) continue;
        final providers = m['ProviderIds'];
        final tmdb = providers is Map ? providers['Tmdb']?.toString() : null;
        if (tmdb == null || tmdb.isEmpty) continue;
        byTmdb.putIfAbsent(
          tmdb,
          () => AggregatedItem(
            id: m['Id'].toString(),
            serverId: serverId,
            rawData: m,
          ),
        );
      }
      final items = [
        for (final id in tmdbIds)
          if (byTmdb[id] != null) byTmdb[id]!,
      ];
      if (mounted) setState(() => _downloaded = items);
    } catch (_) {
      _downloadedRequested = false;
    }
  }

  /// Lo último añadido en todas las bibliotecas (los episodios nuevos se
  /// agrupan en su serie), con lo más reciente primero.
  Future<void> _loadLatest() async {
    if (_latestRequested) return;
    _latestRequested = true;
    try {
      final client = GetIt.instance<MediaServerClient>();
      final response = await client.itemsApi.getLatestItems(
        limit: 40,
        fields: 'Overview,Genres,CommunityRating,OfficialRating,'
            'ProductionYear,UserData,DateCreated,PrimaryImageAspectRatio',
        enableImageTypes: 'Primary,Backdrop,Logo,Thumb',
        imageTypeLimit: 1,
      );
      final raw = response['Items'];
      if (raw is! List || !mounted) return;
      final serverId = widget.viewModel.rows
              .expand((r) => r.items)
              .firstWhereOrNull((i) => i.serverId != 'seerr')
              ?.serverId ??
          client.baseUrl;
      const kinds = {'Movie', 'Series', 'Episode', 'Video', 'MusicVideo'};
      final items = <AggregatedItem>[
        for (final m in raw)
          if (m is Map<String, dynamic> &&
              m['Id'] != null &&
              kinds.contains(m['Type']))
            AggregatedItem(id: m['Id'].toString(), serverId: serverId, rawData: m),
      ];
      int stamp(AggregatedItem i) =>
          DateTime.tryParse(i.rawData['DateCreated']?.toString() ?? '')
              ?.millisecondsSinceEpoch ??
          0;
      items.sort((a, b) => stamp(b).compareTo(stamp(a)));
      if (mounted) setState(() => _latest = items);
    } catch (_) {
      _latestRequested = false;
    }
  }

  bool _isRecent(AggregatedItem item) {
    final created = DateTime.tryParse(item.rawData['DateCreated']?.toString() ?? '');
    return created != null &&
        DateTime.now().difference(created) < const Duration(days: 14);
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
    if (_latest.isEmpty) unawaited(_loadLatest());
    if (_downloaded.isEmpty) unawaited(_loadDownloaded());
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

  ({String itemId, String serverId, CineHeroData data, String? trailer})?
      _resolveHero(
    List<HomeRow> rows,
  ) {
    final slides = widget.viewModel.mediaBarViewModel.items;
    if (slides.isNotEmpty) {
      final s = slides.first;
      return (
        itemId: s.itemId,
        serverId: s.serverId,
        trailer: cineTrailerVideoId(s.remoteTrailers),
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
        final trailers = (item.rawData['RemoteTrailers'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .toList() ??
            const <Map<String, dynamic>>[];
        return (
          itemId: item.id,
          serverId: item.serverId,
          trailer: cineTrailerVideoId(trailers),
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

  CineTile _latestTile(AggregatedItem item) {
    final base = _tile(null, item, false);
    if (!_isRecent(item)) return base;
    return CineTile(
      id: base.id,
      title: base.title,
      imageUrl: base.imageUrl,
      badge: item.type == 'Series'
          ? cineText(context, 'NUEVOS EPISODIOS', 'NEW EPISODES')
          : cineText(context, 'NUEVO', 'NEW'),
      onTap: base.onTap,
      onLongPress: base.onLongPress,
    );
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
    void insertFeatured() {
      if (inserted) return;
      inserted = true;
      if (_downloaded.isNotEmpty) {
        rowWidgets.add(
          CineRow(
            key: const ValueKey('cine_downloaded'),
            title: cineText(
              context,
              'Recién descargado para ti',
              'Just downloaded for you',
            ),
            tiles: [for (final it in _downloaded) _latestTile(it)],
          ),
        );
      }
      if (_latest.isNotEmpty) {
        rowWidgets.add(
          CineRow(
            key: const ValueKey('cine_latest'),
            title: cineText(context, 'Lo último añadido', 'Recently added'),
            tiles: [for (final it in _latest) _latestTile(it)],
          ),
        );
      }
      if (top10.length >= 5) {
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

    for (var i = 0; i < allRows.length; i++) {
      final row = allRows[i];
      if (row.rowType == HomeRowType.mediaBar ||
          row.rowType == HomeRowType.libraryTiles ||
          row.rowType == HomeRowType.libraryTilesSmall ||
          row.id == 'seerr_shortcuts' ||
          row.id == 'seerr_recent_requests' ||
          row.items.isEmpty) {
        continue;
      }
      final isProgress = row.rowType == HomeRowType.resume ||
          row.rowType == HomeRowType.nextUp;
      if (!isProgress) insertFeatured();
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
    }
    insertFeatured();

    if (widget.viewModel.isLoading) _sawLoading = true;
    final loading = widget.viewModel.isLoading && rowWidgets.isEmpty;
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
                        mobileTopInset: 100,
                        trailerVideoId: hero.trailer,
                        onOpen: () => _info(hero.itemId, hero.serverId),
                        buttons: (expand) => expand
                            ? [
                                Expanded(
                                  child: CineButton(
                                    focusNode: _heroPlayFocus,
                                    icon: Icons.play_arrow_rounded,
                                    label: l10n.play,
                                    primary: true,
                                    expand: true,
                                    onTap: () =>
                                        _play(hero.itemId, hero.serverId),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: CineFavoriteButton(
                                    itemId: hero.itemId,
                                    expand: true,
                                  ),
                                ),
                              ]
                            : [
                                CineButton(
                                  focusNode: _heroPlayFocus,
                                  icon: Icons.play_arrow_rounded,
                                  label: l10n.play,
                                  primary: true,
                                  onUpEdge: upEdge,
                                  onLeftEdge: leftEdge,
                                  onTap: () => _play(hero.itemId, hero.serverId),
                                ),
                                const SizedBox(width: 12),
                                CineButton(
                                  icon: Icons.info_outline_rounded,
                                  label: cineText(context, 'Más info', 'More info'),
                                  primary: false,
                                  onUpEdge: upEdge,
                                  onTap: () => _info(hero.itemId, hero.serverId),
                                ),
                                const SizedBox(width: 12),
                                CineFavoriteButton(
                                  itemId: hero.itemId,
                                  onUpEdge: upEdge,
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
              if (_sawLoading && !loading && rowWidgets.isEmpty && hero == null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: mobile ? 80 : 0),
                    child: CineEmptyState(
                      title: cineText(
                        context,
                        'Taquito no encuentra tu biblioteca',
                        'Taquito can\'t find your library',
                      ),
                      message: cineText(
                        context,
                        'Puede que el servidor no responda o que aún no haya nada. '
                            'Comprueba la conexión e inténtalo de nuevo.',
                        'The server may be unreachable or empty. '
                            'Check the connection and try again.',
                      ),
                      actionLabel: cineText(context, 'Reintentar', 'Try again'),
                      onAction: () => unawaited(
                        widget.viewModel.load(forceRefresh: true),
                      ),
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
                leading: Image.asset(
                  'assets/images/logo_and_text.png',
                  height: 34,
                  fit: BoxFit.contain,
                  alignment: Alignment.centerLeft,
                ),
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
