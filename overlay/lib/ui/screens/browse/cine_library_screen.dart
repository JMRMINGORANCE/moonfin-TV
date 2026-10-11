// Moonfin Cine: página de biblioteca (Películas / Series) al estilo de las
// plataformas de streaming: cabecera destacada, chips "Categorías" y
// "Ver todo", y filas de novedades, mejor valoradas, sin ver y por género.
// Las bibliotecas de otro tipo (música, libros, vídeos caseros…) siguen con
// la pantalla de Moonfin.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:server_core/server_core.dart' hide ImageType;

import '../../../data/models/aggregated_item.dart';
import '../../../data/services/media_server_client_factory.dart';
import '../../../l10n/app_localizations.dart';
import '../../../util/platform_detection.dart';
import '../../navigation/destinations.dart';
import '../../widgets/cine/cine_widgets.dart';
import '../../widgets/focus/context_menu_sheet.dart';
import '../../widgets/navigation_layout.dart';
import 'library_browse_screen.dart';

class CineLibraryScreen extends StatefulWidget {
  final String libraryId;
  final String? serverId;

  const CineLibraryScreen({super.key, required this.libraryId, this.serverId});

  @override
  State<CineLibraryScreen> createState() => _CineLibraryScreenState();
}

class _CineRowData {
  final String title;
  final List<AggregatedItem> items;
  const _CineRowData(this.title, this.items);
}

class _CineLibraryScreenState extends State<CineLibraryScreen> {
  static const _fields =
      'Overview,Genres,CommunityRating,OfficialRating,ProductionYear,'
      'RunTimeTicks,UserData,PrimaryImageAspectRatio';
  static const _imageTypes = 'Primary,Backdrop,Logo,Thumb';

  late final MediaServerClient _client;
  final ScrollController _scroll = ScrollController();
  final ValueNotifier<double> _scrollOffset = ValueNotifier(0);
  final FocusNode _heroPlay = FocusNode(debugLabel: 'cine_library_play');
  VoidCallback? _previousFocusContent;

  bool _loading = true;
  bool _unsupported = false;
  String _name = '';
  List<String> _types = const [];
  AggregatedItem? _hero;
  final List<_CineRowData> _rows = [];
  List<({String id, String name})> _genres = const [];

  @override
  void initState() {
    super.initState();
    _client = GetIt.instance<MediaServerClientFactory>()
        .clientForServerOrActive(widget.serverId);
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
    _heroPlay.dispose();
    super.dispose();
  }

  void _focusContent() {
    if (!mounted) return;
    if (_heroPlay.context != null) _heroPlay.requestFocus();
  }

  List<AggregatedItem> _parse(Map<String, dynamic> response) {
    final raw = response['Items'];
    if (raw is! List) return const [];
    return [
      for (final m in raw)
        if (m is Map<String, dynamic> && m['Id'] != null)
          AggregatedItem(
            id: m['Id'].toString(),
            serverId: _client.baseUrl,
            rawData: m,
          ),
    ];
  }

  Future<List<AggregatedItem>> _query({
    String? sortBy,
    String sortOrder = 'Descending',
    List<String>? filters,
    List<String>? genres,
    int limit = 24,
    String fields = _fields,
  }) async {
    try {
      final r = await _client.itemsApi.getItems(
        parentId: widget.libraryId,
        includeItemTypes: _types,
        recursive: true,
        sortBy: sortBy,
        sortOrder: sortOrder,
        filters: filters,
        genres: genres,
        limit: limit,
        fields: fields,
        enableImageTypes: _imageTypes,
        imageTypeLimit: 1,
      );
      return _parse(r);
    } catch (_) {
      return const [];
    }
  }

  Future<void> _load() async {
    try {
      final library = await _client.itemsApi.getItem(
        widget.libraryId,
        fields: '',
      );
      final type = (library['CollectionType'] as String? ?? '').toLowerCase();
      _name = library['Name'] as String? ?? '';
      if (type == 'movies') {
        _types = const ['Movie'];
      } else if (type == 'tvshows') {
        _types = const ['Series'];
      } else {
        if (mounted) setState(() => _unsupported = true);
        return;
      }
    } catch (_) {
      if (mounted) setState(() => _unsupported = true);
      return;
    }
    if (mounted) setState(() {});

    final results = await Future.wait([
      _query(sortBy: 'Random', limit: 12),
      _query(sortBy: 'DateCreated'),
      _query(sortBy: 'CommunityRating'),
      _query(sortBy: 'Random', filters: const ['IsUnplayed']),
      _query(sortBy: 'Random', filters: const ['IsFavorite']),
      _query(sortBy: 'Random', limit: 300, fields: 'Genres'),
    ]);
    if (!mounted) return;

    final heroPool = results[0];
    _hero = heroPool.firstWhere(
      (i) => i.backdropImageTags.isNotEmpty,
      orElse: () => heroPool.isNotEmpty
          ? heroPool.first
          : AggregatedItem(id: '', serverId: '', rawData: const {}),
    );
    if (_hero!.id.isEmpty) _hero = null;

    final counts = <String, int>{};
    for (final item in results[5]) {
      for (final g in item.genres) {
        counts[g] = (counts[g] ?? 0) + 1;
      }
    }
    final topGenres = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    _rows
      ..clear()
      ..add(
        _CineRowData(
          cineText(context, 'Añadidas recientemente', 'Recently added'),
          results[1],
        ),
      )
      ..add(
        _CineRowData(
          cineText(context, 'Las más valoradas', 'Top rated'),
          results[2],
        ),
      )
      ..add(
        _CineRowData(
          cineText(context, 'Aún no las has visto', 'Not watched yet'),
          results[3],
        ),
      )
      ..add(_CineRowData(cineText(context, 'Mi lista', 'My list'), results[4]));
    setState(() => _loading = false);

    // Filas por género, en segundo plano.
    for (final entry in topGenres.take(8)) {
      final items = await _query(sortBy: 'Random', genres: [entry.key]);
      if (!mounted) return;
      if (items.length >= 4) {
        setState(() => _rows.add(_CineRowData(entry.key, items)));
      }
    }

    try {
      final g = await _client.itemsApi.getGenres(
        parentId: widget.libraryId,
        includeItemTypes: _types,
        sortBy: 'SortName',
        sortOrder: 'Ascending',
        recursive: true,
      );
      final list = g['Items'];
      if (list is List && mounted) {
        setState(() {
          _genres = [
            for (final m in list)
              if (m is Map && m['Id'] != null && m['Name'] != null)
                (id: m['Id'].toString(), name: m['Name'].toString()),
          ];
        });
      }
    } catch (_) {}
  }

  // -- navegación ----------------------------------------------------------

  void _open(AggregatedItem item) =>
      context.push(Destinations.item(item.id, serverId: widget.serverId));

  void _play(AggregatedItem item) => context.push(
        Destinations.item(item.id, serverId: widget.serverId, autoPlay: true),
      );

  void _seeAll() => context.push(
        Destinations.library(
          widget.libraryId,
          includeItemTypes: _types,
          serverId: widget.serverId,
        ),
      );

  Future<void> _pickGenre() async {
    if (_genres.isEmpty) return;
    final picked = await showCinePicker(
      context,
      options: [for (final g in _genres) g.name],
      selected: -1,
    );
    if (picked == null || !mounted) return;
    final g = _genres[picked];
    context.push(
      Destinations.genre(g.name, genreId: g.id, parentId: widget.libraryId),
    );
  }

  // -- construcción --------------------------------------------------------

  CineTile _tile(AggregatedItem item) {
    final api = _client.imageApi;
    final tag = item.primaryImageTag;
    return CineTile(
      id: item.id,
      title: item.name,
      imageUrl: tag == null
          ? null
          : api.getPrimaryImageUrl(item.id, maxHeight: 480, tag: tag),
      badge: item.type == 'Series' && (item.unplayedItemCount ?? 0) > 0
          ? '${item.unplayedItemCount}'
          : null,
      onTap: () => _open(item),
      onLongPress: () => showContextMenu(context, item),
    );
  }

  CineHeroData _heroData(AggregatedItem item) {
    final api = _client.imageApi;
    final parts = <String>[
      if (item.productionYear != null) '${item.productionYear}',
      if (item.officialRating != null) item.officialRating!,
      ...item.genres.take(3),
    ];
    return CineHeroData(
      title: item.name,
      overview: item.overview,
      eyebrow: _name,
      backdropUrl: item.backdropImageTags.isEmpty
          ? null
          : api.getBackdropImageUrl(
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
          : api.getLogoImageUrl(item.id, maxWidth: 800, tag: item.logoImageTag),
      metaLine: parts.join('  •  '),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_unsupported) {
      return LibraryBrowseScreen(
        libraryId: widget.libraryId,
        serverId: widget.serverId,
      );
    }
    final l10n = AppLocalizations.of(context);
    final mobile = PlatformDetection.useMobileUi;
    final hero = _hero;
    final upEdge = cineFocusNavbar;
    final leftEdge = cineNavbarIsLeft ? cineFocusNavbar : null;

    final chips = <Widget>[
      CineChip(
        label: cineText(context, 'Categorías', 'Categories'),
        trailingIcon: Icons.keyboard_arrow_down_rounded,
        onUpEdge: upEdge,
        onLeftEdge: leftEdge,
        onTap: _pickGenre,
      ),
      CineChip(label: l10n.seeAll, onUpEdge: upEdge, onTap: _seeAll),
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
              child: Row(
                children: [
                  cinePageTitle(context, _name),
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
                  data: _heroData(hero),
                  mobileTopInset: 96,
                  buttons: (expand) => [
                    if (expand)
                      Expanded(
                        child: CineButton(
                          focusNode: _heroPlay,
                          icon: Icons.play_arrow_rounded,
                          label: l10n.play,
                          primary: true,
                          expand: true,
                          onTap: () => _play(hero),
                        ),
                      )
                    else
                      CineButton(
                        focusNode: _heroPlay,
                        autofocus: true,
                        icon: Icons.play_arrow_rounded,
                        label: l10n.play,
                        primary: true,
                        onLeftEdge: leftEdge,
                        onTap: () => _play(hero),
                      ),
                    SizedBox(width: expand ? 10 : 12),
                    if (expand)
                      Expanded(
                        child: CineButton(
                          icon: Icons.info_outline_rounded,
                          label: cineText(context, 'Más info', 'More info'),
                          primary: false,
                          expand: true,
                          onTap: () => _open(hero),
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
                        onTap: () => _open(hero),
                      ),
                  ],
                ),
        ),
        if (_loading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator(color: cineRed)),
            ),
          ),
        SliverList(
          delegate: SliverChildListDelegate([
            for (final row in _rows)
              if (row.items.isNotEmpty)
                CineRow(
                  key: ValueKey('cine_lib_${row.title}'),
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
                    child: cinePageTitle(context, _name),
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
