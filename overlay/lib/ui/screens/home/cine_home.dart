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

  /// Cabecera viva (TV): el título que tiene el foco en las filas.
  CineHeroData? _focusPreview;
  Timer? _previewTimer;

  /// Colecciones del servidor (sagas), con sus títulos en orden de estreno.
  List<({String id, String name, List<AggregatedItem> items})> _collections =
      const [];
  bool _collectionsRequested = false;

  /// Aviso de llegada: lo que se descargó mientras la app estaba cerrada.
  AggregatedItem? _arrival;
  int _arrivalCount = 0;
  Timer? _arrivalTimer;

  @override
  void initState() {
    super.initState();
    widget.viewModel.addListener(_onDataChanged);
    widget.viewModel.mediaBarViewModel.addListener(_onDataChanged);
    widget.prefs.addListener(_onPrefsChanged);
    _scroll.addListener(_onScroll);
    _previousFocusContent =
        NavigationLayout.focusContentFromNavbarNotifier.value;
    NavigationLayout.focusContentFromNavbarNotifier.value = _focusContent;
    unawaited(_loadLatest());
    unawaited(_loadDownloaded());
    unawaited(_loadCollections());
  }

  /// Hasta 4 colecciones al azar con al menos 3 títulos, cada una con sus
  /// películas en orden de estreno.
  Future<void> _loadCollections() async {
    if (_collectionsRequested) return;
    _collectionsRequested = true;
    try {
      final client = GetIt.instance<MediaServerClient>();
      final sets = await client.itemsApi.getItems(
        includeItemTypes: const ['BoxSet'],
        recursive: true,
        sortBy: 'Random',
        limit: 10,
        fields: '',
      );
      final raw = sets['Items'];
      if (raw is! List || !mounted) return;
      final serverId = widget.viewModel.rows
              .expand((r) => r.items)
              .firstWhereOrNull((i) => i.serverId != 'seerr')
              ?.serverId ??
          client.baseUrl;
      final found = <({String id, String name, List<AggregatedItem> items})>[];
      for (final s in raw) {
        if (found.length >= 4) break;
        if (s is! Map || s['Id'] == null) continue;
        final children = await client.itemsApi.getItems(
          parentId: s['Id'].toString(),
          sortBy: 'PremiereDate,ProductionYear,SortName',
          sortOrder: 'Ascending',
          limit: 30,
          fields: 'Overview,Genres,CommunityRating,OfficialRating,'
              'ProductionYear,UserData,PrimaryImageAspectRatio',
          enableImageTypes: 'Primary,Backdrop,Logo,Thumb',
          imageTypeLimit: 1,
        );
        final list = children['Items'];
        if (list is! List) continue;
        final items = [
          for (final m in list)
            if (m is Map<String, dynamic> &&
                m['Id'] != null &&
                (m['ImageTags'] is Map &&
                    (m['ImageTags'] as Map).containsKey('Primary')))
              AggregatedItem(
                id: m['Id'].toString(),
                serverId: serverId,
                rawData: m,
              ),
        ];
        if (items.length >= 3) {
          found.add((
            id: s['Id'].toString(),
            name: (s['Name'] ?? '').toString(),
            items: items,
          ));
        }
      }
      if (mounted) setState(() => _collections = found);
    } catch (_) {
      _collectionsRequested = false;
    }
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
      unawaited(_checkArrivals(items));
    } catch (_) {
      _downloadedRequested = false;
    }
  }

  Future<void> _checkArrivals(List<AggregatedItem> items) async {
    final fresh = await cineNewArrivals(items);
    if (!mounted || fresh.isEmpty) return;
    setState(() {
      _arrival = fresh.first;
      _arrivalCount = fresh.length;
    });
    _arrivalTimer?.cancel();
    _arrivalTimer = Timer(const Duration(seconds: 12), () {
      if (mounted) setState(() => _arrival = null);
    });
  }

  // -- cabecera viva (TV) ---------------------------------------------------

  void _onTileFocused(CineTile tile) {
    final preview = tile.preview;
    if (preview == null) return;
    _previewTimer?.cancel();
    // Pequeña espera para no cambiar la imagen en cada paso del mando.
    _previewTimer = Timer(const Duration(milliseconds: 220), () {
      if (mounted) setState(() => _focusPreview = preview);
    });
  }

  CineHeroData? _previewFor(AggregatedItem item) {
    if (item.serverId == 'seerr') return null;
    final api = widget.viewModel.imageApiForServer(item.serverId);
    String? backdrop;
    if (item.backdropImageTags.isNotEmpty) {
      backdrop = api.getBackdropImageUrl(
        item.id,
        maxWidth: 1600,
        tag: item.backdropImageTags.first,
      );
    } else if (item.parentBackdropItemId != null &&
        item.parentBackdropImageTags.isNotEmpty) {
      backdrop = api.getBackdropImageUrl(
        item.parentBackdropItemId!,
        maxWidth: 1600,
        tag: item.parentBackdropImageTags.first,
      );
    }
    String? logo;
    if (item.logoImageTag != null) {
      logo = api.getLogoImageUrl(item.id, maxWidth: 700, tag: item.logoImageTag);
    } else if (item.seriesLogoImageTag != null && item.seriesId != null) {
      logo = api.getLogoImageUrl(
        item.seriesId!,
        maxWidth: 700,
        tag: item.seriesLogoImageTag,
      );
    }
    final rating = item.communityRating;
    final meta = [
      if (rating != null && rating > 0) '★ ${rating.toStringAsFixed(1)}',
      if (item.productionYear != null) '${item.productionYear}',
      if (item.officialRating != null && item.officialRating!.isNotEmpty)
        item.officialRating!,
      ...item.genres.take(2),
    ].join('  •  ');
    final isEpisode = item.type == 'Episode';
    return CineHeroData(
      title: isEpisode ? (item.seriesName ?? item.name) : item.name,
      overview: item.overview,
      backdropUrl: backdrop,
      logoUrl: logo,
      metaLine: meta,
      eyebrow: isEpisode &&
              item.parentIndexNumber != null &&
              item.indexNumber != null
          ? 'T${item.parentIndexNumber}:E${item.indexNumber}  ${item.name}'
          : null,
    );
  }

  // -- menú rápido de "Seguir viendo" ---------------------------------------

  void _quickMenu(HomeRow row, AggregatedItem item) {
    final isResume = row.rowType == HomeRowType.resume;
    final messenger = ScaffoldMessenger.of(context);
    Future<void> run(Future<void> Function() action, String done) async {
      try {
        await action();
        await widget.viewModel.refreshResumeAndNextUp();
        if (mounted) {
          messenger.showSnackBar(SnackBar(content: Text(done)));
        }
      } catch (_) {
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                cineText(context, 'No se ha podido hacer.', 'That didn\'t work.'),
              ),
            ),
          );
        }
      }
    }

    final title = item.type == 'Episode'
        ? (item.seriesName ?? item.name)
        : item.name;
    final subtitle = item.type == 'Episode' &&
            item.parentIndexNumber != null &&
            item.indexNumber != null
        ? 'T${item.parentIndexNumber}:E${item.indexNumber}  ${item.name}'
        : null;
    unawaited(
      showCineQuickMenu(
        context,
        title: title,
        subtitle: subtitle,
        actions: [
          CineMenuAction(
            icon: Icons.play_arrow_rounded,
            label: cineText(context, 'Reproducir', 'Play'),
            onTap: () => _play(item.id, item.serverId),
          ),
          CineMenuAction(
            icon: Icons.info_outline_rounded,
            label: cineText(context, 'Ver ficha', 'Details'),
            onTap: () => _openItem(context, row, item),
          ),
          if (isResume)
            CineMenuAction(
              icon: Icons.remove_circle_outline_rounded,
              label: cineText(
                context,
                'Quitar de Seguir viendo',
                'Remove from Continue Watching',
              ),
              onTap: () => unawaited(
                run(
                  () => cineSetPlayed(item.id, played: false),
                  cineText(
                    context,
                    'Quitado de Seguir viendo.',
                    'Removed from Continue Watching.',
                  ),
                ),
              ),
            ),
          CineMenuAction(
            icon: Icons.check_circle_outline_rounded,
            label: cineText(context, 'Marcar como visto', 'Mark as watched'),
            onTap: () => unawaited(
              run(
                () => cineSetPlayed(item.id, played: true),
                cineText(context, 'Marcado como visto.', 'Marked as watched.'),
              ),
            ),
          ),
          CineMenuAction(
            icon: Icons.more_horiz_rounded,
            label: cineText(context, 'Más opciones', 'More options'),
            onTap: () => showContextMenu(context, item),
          ),
        ],
      ),
    );
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
    widget.prefs.removeListener(_onPrefsChanged);
    if (identical(
      NavigationLayout.focusContentFromNavbarNotifier.value,
      _focusContent,
    )) {
      NavigationLayout.focusContentFromNavbarNotifier.value =
          _previousFocusContent;
    }
    _previewTimer?.cancel();
    _arrivalTimer?.cancel();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _heroPlayFocus.dispose();
    _scrollOffset.dispose();
    super.dispose();
  }

  /// Al tocar las filas en Ajustes, la portada se redibuja al momento.
  void _onPrefsChanged() {
    if (mounted) setState(() {});
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

  /// Biblioteca: imagen apaisada y su nombre, sin vista previa ni menú.
  CineTile _libraryTile(HomeRow row, AggregatedItem item) {
    final base = _tile(row, item, true);
    return CineTile(
      id: base.id,
      title: base.title,
      imageUrl: base.imageUrl,
      onTap: base.onTap,
    );
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
      preview: base.preview,
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
          : isProgressRow && row != null
              ? () => _quickMenu(row, item)
              : () => showContextMenu(context, item),
      preview: cineIsTv ? _previewFor(item) : null,
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

    final tv = cineIsTv;
    final tileFocused = tv ? _onTileFocused : null;
    // En la tele la fila enfocada baja para dejar sitio a la cabecera viva:
    // la carátula queda justo debajo, con el título de la fila a la vista.
    final focusAlign = tv ? 0.82 : 0.5;
    final focusTop = tv
        ? MediaQuery.sizeOf(context).height * _kPreviewHeight + 58
        : null;
    final hideStale = widget.prefs.get(cineHideStaleResume);
    final rowWidgets = <Widget>[];

    // Orden de la portada: tus bibliotecas, "Recién descargado para ti",
    // "Lo último añadido" y después todo lo demás (Seguir viendo, Top 10…).
    final libraryRow = allRows.firstWhereOrNull(
      (r) =>
          (r.rowType == HomeRowType.libraryTiles ||
              r.rowType == HomeRowType.libraryTilesSmall) &&
          r.items.isNotEmpty,
    );
    if (libraryRow != null) {
      rowWidgets.add(
        CineRow(
          key: const ValueKey('cine_libraries'),
          title: cineText(context, 'Mis bibliotecas', 'My libraries'),
          tiles: [
            for (final it in libraryRow.items) _libraryTile(libraryRow, it),
          ],
          landscape: true,
          onTileFocused: tileFocused,
          focusAlignment: focusAlign,
          focusTop: focusTop,
        ),
      );
    }
    if (_downloaded.isNotEmpty && widget.prefs.get(cineShowDownloadedRow)) {
      rowWidgets.add(
        CineRow(
          key: const ValueKey('cine_downloaded'),
          title: cineText(
            context,
            'Recién descargado para ti',
            'Just downloaded for you',
          ),
          tiles: [for (final it in _downloaded) _latestTile(it)],
          onTileFocused: tileFocused,
          focusAlignment: focusAlign,
          focusTop: focusTop,
        ),
      );
    }
    if (_latest.isNotEmpty && widget.prefs.get(cineShowLatestRow)) {
      rowWidgets.add(
        CineRow(
          key: const ValueKey('cine_latest'),
          title: cineText(context, 'Lo último añadido', 'Recently added'),
          tiles: [for (final it in _latest) _latestTile(it)],
          onTileFocused: tileFocused,
          focusAlignment: focusAlign,
          focusTop: focusTop,
        ),
      );
    }
    var inserted = false;
    void insertFeatured() {
      if (inserted) return;
      inserted = true;
      if (top10.length >= 5 && widget.prefs.get(cineShowTop10Row)) {
        rowWidgets.add(
          CineTop10Row(
            key: const ValueKey('cine_top10'),
            title: cineText(
              context,
              'Top 10 en tu biblioteca',
              'Top 10 in your library',
            ),
            tiles: [for (final it in top10) _tile(null, it, false)],
            onTileFocused: tileFocused,
            focusAlignment: focusAlign,
            focusTop: focusTop,
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
      final rowItems = row.rowType == HomeRowType.resume && hideStale
          ? row.items.where((it) => !cineIsStaleResume(it)).toList()
          : row.items;
      if (rowItems.isEmpty) continue;
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
          tiles: [for (final it in rowItems) _tile(row, it, landscape)],
          landscape: landscape,
          playOverlay: row.rowType == HomeRowType.resume ||
              row.rowType == HomeRowType.nextUp,
          onNearEnd: () => widget.viewModel.loadMoreForRow(i),
          onTileFocused: tileFocused,
          focusAlignment: focusAlign,
          focusTop: focusTop,
        ),
      );
    }
    insertFeatured();

    // Sagas al final, como en Netflix.
    for (final c in widget.prefs.get(cineShowCollectionsRow)
        ? _collections
        : const <({String id, String name, List<AggregatedItem> items})>[]) {
      rowWidgets.add(
        CineRow(
          key: ValueKey('cine_collection_${c.id}'),
          title: c.name,
          tiles: [for (final it in c.items) _tile(null, it, false)],
          onTileFocused: tileFocused,
          focusAlignment: focusAlign,
          focusTop: focusTop,
        ),
      );
    }

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
          if (tv)
            ValueListenableBuilder<double>(
              valueListenable: _scrollOffset,
              builder: (context, offset, _) {
                final h = MediaQuery.sizeOf(context).height;
                final show = _focusPreview != null && offset > h * 0.45;
                return Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: h * _kPreviewHeight,
                  child: IgnorePointer(
                    ignoring: !show,
                    child: AnimatedOpacity(
                      opacity: show ? 1 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: _focusPreview == null
                          ? const SizedBox.shrink()
                          : _CinePreviewPanel(data: _focusPreview!),
                    ),
                  ),
                );
              },
            ),
          if (_arrival != null)
            Positioned(
              left: mobile ? 12 : null,
              right: mobile ? 12 : 40,
              bottom: mobile ? 96 : 40,
              child: _CineArrivalCard(
                item: _arrival!,
                count: _arrivalCount,
                imageUrl: _imageFor(_arrival!, false, 180),
                onPlay: mobile
                    ? () {
                        final item = _arrival!;
                        setState(() => _arrival = null);
                        _play(item.id, item.serverId);
                      }
                    : null,
                onClose: () => setState(() => _arrival = null),
              ),
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

/// Alto de la cabecera viva de la tele, en proporción a la pantalla.
const double _kPreviewHeight = 0.46;

/// Cabecera viva de la tele: aparece al bajar a las filas y enseña el título
/// que tiene el foco, con su imagen, datos y sinopsis.
class _CinePreviewPanel extends StatelessWidget {
  final CineHeroData data;

  const _CinePreviewPanel({required this.data});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final pad = cineSidePadding(context);
    final url = data.backdropUrl;
    return ColoredBox(
      color: cineBg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (url != null)
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              width: size.width * 0.66,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: BoundedNetworkImage(
                  key: ValueKey(url),
                  imageUrl: url,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  minWidth: 960,
                  maxWidth: 1600,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: [0.3, 0.6, 1.0],
                colors: [cineBg, Color(0x99000000), Color(0x00000000)],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.65, 1.0],
                colors: [Color(0x00000000), cineBg],
              ),
            ),
          ),
          Positioned(
            left: pad,
            top: MediaQuery.paddingOf(context).top + 36,
            width: size.width * 0.42,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                cineTitleOrLogo(data, size.width * 0.3, 40, TextAlign.start),
                if (data.eyebrow != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    data.eyebrow!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (data.metaLine.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    data.metaLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 17),
                  ),
                ],
                if ((data.overview ?? '').isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    data.overview!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFDDDDDD),
                      fontSize: 17,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Aviso de llegada: "Ya puedes ver…" cuando algo pedido en Seerr se descargó
/// mientras la app estaba cerrada.
class _CineArrivalCard extends StatelessWidget {
  final AggregatedItem item;
  final int count;
  final String? imageUrl;
  final VoidCallback? onPlay;
  final VoidCallback onClose;

  const _CineArrivalCard({
    required this.item,
    required this.count,
    required this.imageUrl,
    required this.onPlay,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final tv = cineIsTv;
    final others = count - 1;
    final title = cineText(
      context,
      'Ya puedes ver «${item.name}»',
      'You can now watch “${item.name}”',
    );
    final detail = others > 0
        ? cineText(
            context,
            'Y $others más en «Recién descargado para ti».',
            'And $others more in “Just downloaded for you”.',
          )
        : cineText(
            context,
            'Está en «Recién descargado para ti».',
            'It\'s in “Just downloaded for you”.',
          );
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(maxWidth: tv ? 520 : 600),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xF21C1C1C),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cineRed, width: 1.5),
          boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 20)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: tv ? 64 : 52,
                height: tv ? 96 : 78,
                child: imageUrl == null
                    ? const ColoredBox(color: cineCardBg)
                    : BoundedNetworkImage(
                        imageUrl: imageUrl!,
                        fit: BoxFit.cover,
                        minWidth: 80,
                        maxWidth: 200,
                        errorBuilder: (_, _, _) =>
                            const ColoredBox(color: cineCardBg),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: GestureDetector(
                onTap: onPlay,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: tv ? 20 : 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      onPlay != null
                          ? cineText(context, 'Toca para verla ya. ', 'Tap to watch now. ') + detail
                          : detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: cineMuted, fontSize: tv ? 16 : 13),
                    ),
                  ],
                ),
              ),
            ),
            if (!tv)
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded, color: cineMuted),
              ),
          ],
        ),
      ),
    );
  }
}
