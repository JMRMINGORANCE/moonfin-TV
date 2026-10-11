// Moonfin Cine: ficha de detalle al estilo de las plataformas de streaming.
//
// Fondo grande con degradado, logo del título, línea de datos (valoración,
// año, edad, duración, calidad), botones de acción de Moonfin (reproducir,
// reanudar, mi lista, visto…), sinopsis, reparto, episodios por temporada con
// selector a pantalla completa y "Más títulos similares".

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../data/models/aggregated_item.dart';
import '../../../../data/viewmodels/item_detail_view_model.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../preference/user_preferences.dart';
import '../../../../util/season_queue_context.dart';
import '../../../navigation/destinations.dart';
import '../../../widgets/bounded_network_image.dart';
import '../../../widgets/cine/cine_widgets.dart';
import '../../../widgets/focus/context_menu_sheet.dart';
import '../detail_layout_metrics.dart';
import '../item_detail_screen.dart';

class CineDetailContent extends StatefulWidget {
  static const _types = {
    'Movie',
    'Series',
    'Season',
    'Episode',
    'Video',
    'MusicVideo',
  };

  /// Los títulos que dibuja esta ficha. El resto (música, personas,
  /// colecciones, solicitudes de Seerr) sigue con las fichas de Moonfin.
  static bool supports(ItemDetailViewModel vm) =>
      kCineUi && !vm.isSeerrOnly && _types.contains(vm.item?.type);

  final ItemDetailViewModel viewModel;
  final UserPreferences prefs;
  final String? selectedMediaSourceId;
  final ValueChanged<String?> onSelectedMediaSourceChanged;
  final FocusNode? initialFocusNode;
  final bool autoPlay;
  final bool actionsExpanded;
  final ValueChanged<bool> onActionsExpandedChanged;

  const CineDetailContent({
    super.key,
    required this.viewModel,
    required this.prefs,
    this.selectedMediaSourceId,
    required this.onSelectedMediaSourceChanged,
    this.initialFocusNode,
    this.autoPlay = false,
    required this.actionsExpanded,
    required this.onActionsExpandedChanged,
  });

  @override
  State<CineDetailContent> createState() => _CineDetailContentState();
}

class _CineDetailContentState extends State<CineDetailContent> {
  final ScrollController _scroll = ScrollController();
  final FocusNode _episodesEntry = FocusNode(debugLabel: 'cine_episodes');
  final FocusNode _similarEntry = FocusNode(debugLabel: 'cine_similar');
  int? _selectedSeason;
  bool _loadStarted = false;

  ItemDetailViewModel get _vm => widget.viewModel;
  AggregatedItem? get _item => _vm.item;
  bool get _isSeries => _item?.type == 'Series';
  bool get _isSeason => _item?.type == 'Season';
  bool get _isEpisode => _item?.type == 'Episode';
  bool get _hasEpisodes => _isSeries || _isSeason || _isEpisode;

  @override
  void initState() {
    super.initState();
    _beginEpisodesLoad();
  }

  @override
  void didUpdateWidget(covariant CineDetailContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    _beginEpisodesLoad();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _episodesEntry.dispose();
    _similarEntry.dispose();
    super.dispose();
  }

  void _beginEpisodesLoad() {
    if (_loadStarted || !(_isSeries || _isEpisode)) return;
    _loadStarted = true;
    final vm = _vm;
    if (vm.seriesEpisodes.isNotEmpty) return;
    unawaited(
      vm.loadAllSeriesEpisodes().whenComplete(() {
        if (mounted) setState(() {});
      }),
    );
  }

  // -- imágenes ------------------------------------------------------------

  String? _backdropUrl(AggregatedItem item) {
    final api = _vm.imageApi;
    if (item.backdropImageTags.isNotEmpty) {
      return api.getBackdropImageUrl(
        item.id,
        maxWidth: 1920,
        tag: item.backdropImageTags.first,
      );
    }
    final parentId = item.parentBackdropItemId;
    if (parentId != null && item.parentBackdropImageTags.isNotEmpty) {
      return api.getBackdropImageUrl(
        parentId,
        maxWidth: 1920,
        tag: item.parentBackdropImageTags.first,
      );
    }
    if (item.primaryImageTag != null) {
      return api.getPrimaryImageUrl(
        item.id,
        maxWidth: 1280,
        tag: item.primaryImageTag,
      );
    }
    return null;
  }

  String? _logoUrl(AggregatedItem item) {
    if (item.logoImageTag != null) {
      return _vm.imageApi.getLogoImageUrl(
        item.id,
        maxWidth: 800,
        tag: item.logoImageTag,
      );
    }
    final seriesId = item.seriesId;
    if (item.seriesLogoImageTag != null && seriesId != null) {
      return _vm.imageApi.getLogoImageUrl(
        seriesId,
        maxWidth: 800,
        tag: item.seriesLogoImageTag,
      );
    }
    return null;
  }

  // -- episodios -----------------------------------------------------------

  List<AggregatedItem> get _allEpisodes =>
      _isSeason ? _vm.episodes : _vm.seriesEpisodes;

  List<int> _seasonNumbers(List<AggregatedItem> episodes) => episodes
      .map((e) => e.parentIndexNumber)
      .whereType<int>()
      .toSet()
      .toList()
    ..sort();

  String _seasonLabel(AppLocalizations l10n, int n) =>
      n == 0 ? l10n.specials : l10n.seasonNumber(n);

  void _playEpisode(AggregatedItem episode) {
    context.push(
      Destinations.item(
        episode.id,
        serverId: episode.serverId,
        autoPlay: true,
        seasonContext: seasonContextParam(
          contextSeasonId: _isSeason ? _item?.id : null,
          episodeSeasonId: episode.seasonId,
        ),
      ),
    );
  }

  void _focusPlay() => widget.initialFocusNode?.requestFocus();

  // -- construcción --------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final item = _item;
    if (item == null) return const SizedBox.shrink();
    final landscape = detailUsesLandscapeLayout(context);
    final size = MediaQuery.sizeOf(context);
    final pad = cineSidePadding(context);
    final backdrop = _backdropUrl(item);

    final episodesSliver = _hasEpisodes ? _buildEpisodes(context) : null;
    final similar = _vm.similar.take(18).toList();

    final header = _buildHeader(context, item, landscape, size);

    final slivers = <Widget>[
      if (landscape)
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(pad, size.height * 0.2, pad, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: size.width * 0.52),
                child: header,
              ),
            ),
          ),
        )
      else ...[
        SliverToBoxAdapter(child: _mobileBackdrop(backdrop)),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: pad),
            child: header,
          ),
        ),
      ],
      if (episodesSliver != null) episodesSliver,
      if (similar.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: cineSectionTitle(
            context,
            cineText(context, 'Más títulos similares', 'More like this'),
            topPadding: 32,
          ),
        ),
        SliverToBoxAdapter(
          child: CineGrid(
            firstFocusNode: _similarEntry,
            onUpEdge: _focusPlay,
            tiles: [for (final s in similar) _similarTile(s)],
          ),
        ),
      ],
      const SliverToBoxAdapter(child: SizedBox(height: 96)),
    ];

    return ColoredBox(
      color: cineBg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (landscape && backdrop != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: size.height * 0.92,
              child: _landscapeBackdrop(backdrop),
            ),
          CustomScrollView(controller: _scroll, slivers: slivers),
        ],
      ),
    );
  }

  Widget _landscapeBackdrop(String url) {
    return Stack(
      fit: StackFit.expand,
      children: [
        BoundedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          alignment: Alignment.topRight,
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
              stops: [0.0, 0.5, 0.85],
              colors: [Color(0xF2000000), Color(0x99000000), Color(0x00000000)],
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.5, 1.0],
              colors: [Color(0x00000000), cineBg],
            ),
          ),
        ),
      ],
    );
  }

  Widget _mobileBackdrop(String? url) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsets.only(top: topInset + 48),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (url != null)
              BoundedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                minWidth: 480,
                maxWidth: 1280,
                priority: ImageFetchPriority.high,
                errorBuilder: (_, _, _) => const ColoredBox(color: cineCardBg),
              )
            else
              const ColoredBox(color: cineCardBg),
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
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AggregatedItem item,
    bool landscape,
    Size size,
  ) {
    final l10n = AppLocalizations.of(context);
    final tv = cineIsTv;
    final heroData = CineHeroData(
      title: _isEpisode || _isSeason
          ? (item.seriesName ?? item.name)
          : item.name,
      logoUrl: _logoUrl(item),
    );
    final bodyStyle = TextStyle(
      color: Colors.white,
      fontSize: tv ? 18 : 14,
      height: 1.4,
    );

    final actors = _vm.actors
        .map((p) => p['Name'] as String?)
        .whereType<String>()
        .take(4)
        .toList();
    final directors = _vm.directors
        .map((p) => p['Name'] as String?)
        .whereType<String>()
        .take(2)
        .toList();

    String? episodeLine;
    if (_isEpisode) {
      final s = item.parentIndexNumber;
      final e = item.indexNumber;
      episodeLine = (s != null && e != null)
          ? 'T$s:E$e  ${item.name}'
          : item.name;
    } else if (_isSeason) {
      episodeLine = item.name;
    }

    final overview = item.overview;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        cineTitleOrLogo(
          heroData,
          landscape ? size.width * 0.3 : size.width * 0.7,
          landscape ? (tv ? 54 : 46) : 30,
          TextAlign.start,
        ),
        if (episodeLine != null) ...[
          const SizedBox(height: 10),
          Text(
            episodeLine,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: tv ? 24 : 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 12),
        _metaRow(context, item),
        const SizedBox(height: 16),
        DetailActionButtons(
          key: const ValueKey('cine-actions'),
          viewModel: _vm,
          itemId: item.id,
          selectedMediaSourceId: widget.selectedMediaSourceId,
          onSelectedMediaSourceChanged: widget.onSelectedMediaSourceChanged,
          tvPlayFocusNode: widget.initialFocusNode,
          downTarget: _hasEpisodes ? _episodesEntry : _similarEntry,
          autoPlay: widget.autoPlay,
          modernStyle: true,
          fullWidthPrimary: !landscape,
          overflowAsMenu: true,
          maxVisibleButtonsOverride: landscape ? 5 : 4,
          actionsExpanded: widget.actionsExpanded,
          onActionsExpandedChanged: widget.onActionsExpandedChanged,
        ),
        if (overview != null && overview.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            overview,
            maxLines: landscape ? 4 : 8,
            overflow: TextOverflow.ellipsis,
            style: bodyStyle,
          ),
        ],
        if (actors.isNotEmpty) ...[
          const SizedBox(height: 10),
          _labelled(
            cineText(context, 'Reparto: ', 'Cast: '),
            actors.join(', '),
            tv,
          ),
        ],
        if (directors.isNotEmpty) ...[
          const SizedBox(height: 4),
          _labelled(
            cineText(context, 'Dirección: ', 'Director: '),
            directors.join(', '),
            tv,
          ),
        ],
        if (item.genres.isNotEmpty) ...[
          const SizedBox(height: 4),
          _labelled('${l10n.genres}: ', item.genres.take(4).join(', '), tv),
        ],
      ],
    );
  }

  Widget _labelled(String label, String value, bool tv) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: label,
            style: const TextStyle(color: Color(0xFF777777)),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(color: Color(0xFFDDDDDD)),
          ),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: tv ? 16 : 13),
    );
  }

  Widget _metaRow(BuildContext context, AggregatedItem item) {
    final tv = cineIsTv;
    final fs = tv ? 18.0 : 14.0;
    final rating = item.communityRating;
    final seasons = _vm.seasons.length;
    final runtime = _isSeries
        ? (seasons > 0
            ? (seasons == 1
                ? cineText(context, '1 temporada', '1 season')
                : cineText(
                    context,
                    '$seasons temporadas',
                    '$seasons seasons',
                  ))
            : '')
        : cineRuntime(context, item.runTimeTicks);
    final res = item.videoResolution;

    Widget boxed(String text) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF9A9A9A)),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            text,
            style: TextStyle(color: const Color(0xFFDDDDDD), fontSize: fs - 3),
          ),
        );

    return Wrap(
      spacing: 12,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (rating != null && rating > 0)
          Text(
            '★ ${rating.toStringAsFixed(1)}',
            style: TextStyle(
              color: cineGreen,
              fontSize: fs,
              fontWeight: FontWeight.w700,
            ),
          ),
        if (item.productionYear != null)
          Text(
            '${item.productionYear}',
            style: TextStyle(color: const Color(0xFFDDDDDD), fontSize: fs),
          ),
        if (item.officialRating != null && item.officialRating!.isNotEmpty)
          boxed(item.officialRating!),
        if (runtime.isNotEmpty)
          Text(
            runtime,
            style: TextStyle(color: const Color(0xFFDDDDDD), fontSize: fs),
          ),
        if (res != null && res.isNotEmpty) boxed(res),
      ],
    );
  }

  Widget? _buildEpisodes(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final all = _allEpisodes;
    if (all.isEmpty) return null;

    final seasons = _seasonNumbers(all);
    final arrivedIn = _isEpisode ? _item?.parentIndexNumber : null;
    final fallback = arrivedIn != null && seasons.contains(arrivedIn)
        ? arrivedIn
        : (seasons.isEmpty ? null : seasons.first);
    final selected = _selectedSeason != null && seasons.contains(_selectedSeason)
        ? _selectedSeason!
        : fallback;
    final episodes = selected == null
        ? all
        : all.where((e) => e.parentIndexNumber == selected).toList();
    final showPicker = seasons.length > 1 && !_isSeason;
    final pad = cineSidePadding(context);

    return SliverList(
      delegate: SliverChildListDelegate([
        Padding(
          padding: EdgeInsets.fromLTRB(pad, 32, pad, 12),
          child: Row(
            children: [
              Text(
                l10n.episodes,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: cineIsTv ? 26 : 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (showPicker && selected != null)
                CineChip(
                  focusNode: _episodesEntry,
                  label: _seasonLabel(l10n, selected),
                  trailingIcon: Icons.keyboard_arrow_down_rounded,
                  onUpEdge: _focusPlay,
                  onTap: () async {
                    final picked = await showCinePicker(
                      context,
                      options: [for (final n in seasons) _seasonLabel(l10n, n)],
                      selected: seasons.indexOf(selected),
                    );
                    if (picked != null && mounted) {
                      setState(() => _selectedSeason = seasons[picked]);
                      _episodesEntry.requestFocus();
                    }
                  },
                ),
            ],
          ),
        ),
        for (var i = 0; i < episodes.length; i++)
          _CineEpisodeTile(
            episode: episodes[i],
            focusNode: !showPicker && i == 0 ? _episodesEntry : null,
            imageUrl: episodes[i].primaryImageTag == null
                ? null
                : _vm.imageApi.getPrimaryImageUrl(
                    episodes[i].id,
                    maxWidth: 560,
                    tag: episodes[i].primaryImageTag,
                  ),
            isCurrent: _isEpisode && episodes[i].id == _item?.id,
            onUpEdge: i == 0 ? _focusPlay : null,
            onTap: () => _playEpisode(episodes[i]),
            onLongPress: () => showContextMenu(
              context,
              episodes[i],
              onChanged: () => setState(() {}),
            ),
          ),
      ]),
    );
  }

  CineTile _similarTile(AggregatedItem s) {
    final isSeerr = s.serverId == 'seerr';
    final String? url;
    if (isSeerr) {
      url = cineTmdbImage(s.rawData['PosterPath'] as String?, 342);
    } else if (s.primaryImageTag != null) {
      url = _vm.imageApi.getPrimaryImageUrl(
        s.id,
        maxHeight: 480,
        tag: s.primaryImageTag,
      );
    } else {
      url = null;
    }
    return CineTile(
      id: s.id,
      title: s.name,
      imageUrl: url,
      onTap: () {
        if (isSeerr) {
          final mediaType =
              s.type == 'Series' || s.type == 'tv' ? 'tv' : 'movie';
          context.push(
            Destinations.seerrMedia(
              s.tmdbId ?? s.id,
              mediaType: mediaType,
              title: s.name,
            ),
          );
        } else {
          context.push(Destinations.item(s.id, serverId: s.serverId));
        }
      },
    );
  }
}

class _CineEpisodeTile extends StatelessWidget {
  final AggregatedItem episode;
  final String? imageUrl;
  final FocusNode? focusNode;
  final bool isCurrent;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onUpEdge;

  const _CineEpisodeTile({
    required this.episode,
    required this.imageUrl,
    required this.onTap,
    required this.onLongPress,
    this.focusNode,
    this.isCurrent = false,
    this.onUpEdge,
  });

  @override
  Widget build(BuildContext context) {
    final tv = cineIsTv;
    final pad = cineSidePadding(context);
    final thumbW = tv ? 300.0 : 132.0;
    final progress = (episode.playedPercentage ?? 0) / 100.0;
    final number = episode.indexNumber;
    final title = number != null ? '$number. ${episode.name}' : episode.name;
    final runtime = cineRuntime(context, episode.runTimeTicks);
    final overview = episode.overview ?? '';

    return CineFocusable(
      focusNode: focusNode,
      onActivate: onTap,
      onLongPress: onLongPress,
      onUpEdge: onUpEdge,
      onLeftEdge: cineNavbarIsLeft ? cineFocusNavbar : null,
      builder: (context, focused) {
        final thumb = ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            width: thumbW,
            height: thumbW * 9 / 16,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (imageUrl != null)
                  BoundedNetworkImage(
                    imageUrl: imageUrl!,
                    fit: BoxFit.cover,
                    minWidth: 160,
                    maxWidth: 640,
                    errorBuilder: (_, _, _) =>
                        const ColoredBox(color: cineCardBg),
                  )
                else
                  const ColoredBox(color: cineCardBg),
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
                      padding: EdgeInsets.all(5),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
                if (progress > 0)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 4,
                      color: const Color(0x99555555),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: progress.clamp(0.02, 1.0),
                        child: const ColoredBox(color: cineRed),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );

        final titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: tv ? 20 : 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (runtime.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                runtime,
                style: TextStyle(color: cineMuted, fontSize: tv ? 16 : 13),
              ),
            ],
            if (tv && overview.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                overview,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFCCCCCC),
                  fontSize: 16,
                  height: 1.35,
                ),
              ),
            ],
          ],
        );

        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: EdgeInsets.symmetric(horizontal: pad - 8, vertical: 4),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: focused || isCurrent
                ? const Color(0xFF2A2A2A)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: tv && focused ? Colors.white : Colors.transparent,
              width: 2,
            ),
          ),
          child: tv
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    thumb,
                    const SizedBox(width: 20),
                    Expanded(child: titleBlock),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        thumb,
                        const SizedBox(width: 12),
                        Expanded(child: titleBlock),
                      ],
                    ),
                    if (overview.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        overview,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: cineMuted,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
        );
      },
    );
  }
}
