// TaquitoFlix: buscador al estilo de las plataformas de streaming. Busca a la
// vez en la biblioteca y en Seerr: lo que ya tienes sale primero y lo que no,
// debajo con su etiqueta, listo para descargar. Con búsqueda por voz en Android.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:server_core/server_core.dart' hide ImageType;

import '../../../data/models/aggregated_item.dart';
import '../../../data/repositories/seerr_repository.dart';
import '../../../data/services/plugin_sync_service.dart';
import '../../../data/services/seerr/seerr_api_models.dart';
import '../../../data/services/voice_search_controller.dart';
import '../../../util/platform_detection.dart';
import '../../navigation/destinations.dart';
import '../../widgets/cine/cine_empty_state.dart';
import '../../widgets/cine/cine_widgets.dart';
import '../../widgets/navigation_layout.dart';

class CineSearchScreen extends StatefulWidget {
  final String? initialQuery;

  const CineSearchScreen({super.key, this.initialQuery});

  @override
  State<CineSearchScreen> createState() => _CineSearchScreenState();
}

class _CineSearchScreenState extends State<CineSearchScreen> {
  final _controller = TextEditingController();
  final _fieldFocus = FocusNode(debugLabel: 'cine_search_field');
  final _voice = VoiceSearchController();
  Timer? _debounce;
  int _token = 0;

  String _query = '';
  bool _searching = false;
  List<AggregatedItem> _library = const [];
  List<SeerrDiscoverItem> _seerr = const [];

  MediaServerClient get _client => GetIt.instance<MediaServerClient>();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    _voice.addListener(_onVoiceChanged);
    final initial = widget.initialQuery?.trim() ?? '';
    if (initial.isNotEmpty) {
      _controller.text = initial;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fieldFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _fieldFocus.dispose();
    _voice.removeListener(_onVoiceChanged);
    unawaited(_voice.cancelListening());
    super.dispose();
  }

  void _onVoiceChanged() {
    if (mounted) setState(() {});
  }

  void _onChanged() {
    final q = _controller.text.trim();
    if (q == _query) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(q));
  }

  Future<void> _search(String q) async {
    final token = ++_token;
    setState(() {
      _query = q;
      _searching = q.isNotEmpty;
      if (q.isEmpty) {
        _library = const [];
        _seerr = const [];
      }
    });
    if (q.isEmpty) return;

    final results = await Future.wait([
      _searchLibrary(q),
      _searchSeerr(q),
    ]);
    if (!mounted || token != _token) return;
    setState(() {
      _library = results[0] as List<AggregatedItem>;
      _seerr = results[1] as List<SeerrDiscoverItem>;
      _searching = false;
    });
  }

  Future<List<AggregatedItem>> _searchLibrary(String q) async {
    try {
      final client = _client;
      final r = await client.itemsApi.getItems(
        searchTerm: q,
        includeItemTypes: const ['Movie', 'Series'],
        recursive: true,
        limit: 48,
        fields: 'PrimaryImageAspectRatio,ProductionYear,UserData',
        enableImageTypes: 'Primary',
        imageTypeLimit: 1,
      );
      final raw = r['Items'];
      if (raw is! List) return const [];
      return [
        for (final m in raw)
          if (m is Map<String, dynamic> && m['Id'] != null)
            AggregatedItem(
              id: m['Id'].toString(),
              serverId: client.baseUrl,
              rawData: m,
            ),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<List<SeerrDiscoverItem>> _searchSeerr(String q) async {
    if (!GetIt.instance<PluginSyncService>().seerrAvailable) return const [];
    try {
      final repo = await GetIt.instance.getAsync<SeerrRepository>();
      await repo.ensureInitialized();
      final page = await repo.search(q);
      return page.results
          .where((i) => i.mediaType == 'movie' || i.mediaType == 'tv')
          // Lo que ya está descargado aparece arriba, en la biblioteca.
          .where((i) => i.mediaInfo?.status != 5)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> _toggleVoice() async {
    if (_voice.isListening) {
      await _voice.stopListening();
      return;
    }
    final locale = Localizations.localeOf(context);
    final code = locale.countryCode == null || locale.countryCode!.isEmpty
        ? (locale.languageCode == 'es' ? 'es_ES' : locale.languageCode)
        : '${locale.languageCode}_${locale.countryCode}';
    final result = await _voice.startListening(
      localeCode: code,
      onText: (text, {required isFinal}) {
        _controller.text = text;
        _controller.selection = TextSelection.collapsed(offset: text.length);
        if (isFinal) _search(text.trim());
      },
    );
    if (!mounted) return;
    if (result != VoiceSearchStartResult.listeningStarted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            cineText(
              context,
              'La búsqueda por voz no está disponible en este dispositivo.',
              'Voice search is not available on this device.',
            ),
          ),
        ),
      );
    }
  }

  CineTile _libraryTile(AggregatedItem item) {
    final tag = item.primaryImageTag;
    return CineTile(
      id: item.id,
      title: item.name,
      imageUrl: tag == null
          ? null
          : _client.imageApi.getPrimaryImageUrl(
              item.id,
              maxHeight: 480,
              tag: tag,
            ),
      onTap: () => context.push(Destinations.item(item.id)),
    );
  }

  CineTile _seerrTile(SeerrDiscoverItem i) {
    final status = i.mediaInfo?.status;
    final downloading = status == 2 || status == 3;
    final title = i.title ?? i.name ?? i.originalTitle ?? i.originalName ?? '';
    return CineTile(
      id: '${i.mediaType}_${i.id}',
      title: title,
      imageUrl: cineTmdbImage(i.posterPath, 342),
      badge: downloading
          ? cineText(context, 'DESCARGANDO', 'DOWNLOADING')
          : cineText(context, 'DESCARGAR', 'DOWNLOAD'),
      badgeColor: downloading ? const Color(0xFFD08A00) : cineRed,
      onTap: () => context.push(
        Destinations.seerrMedia(
          i.id.toString(),
          mediaType: i.mediaType ?? 'movie',
          title: title,
        ),
      ),
    );
  }

  KeyEventResult _fieldKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    // En TV, bajar desde el campo de texto lleva a los resultados.
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      return node.focusInDirection(TraversalDirection.down)
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      cineFocusNavbar();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _searchField(BuildContext context) {
    final tv = cineIsTv;
    final showMic = !PlatformDetection.isWeb;
    return Focus(
      onKeyEvent: _fieldKey,
      skipTraversal: true,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2B2B2B),
          borderRadius: BorderRadius.circular(6),
        ),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: tv ? 6 : 2),
        child: Row(
          children: [
            Icon(Icons.search_rounded, color: cineMuted, size: tv ? 30 : 24),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _fieldFocus,
                textInputAction: TextInputAction.search,
                onSubmitted: (v) => _search(v.trim()),
                cursorColor: cineRed,
                style: TextStyle(color: Colors.white, fontSize: tv ? 22 : 17),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: cineText(
                    context,
                    'Busca películas y series',
                    'Search movies and series',
                  ),
                  hintStyle: TextStyle(color: cineMuted, fontSize: tv ? 22 : 17),
                ),
              ),
            ),
            if (_controller.text.isNotEmpty)
              IconButton(
                onPressed: () {
                  _controller.clear();
                  _search('');
                  _fieldFocus.requestFocus();
                },
                icon: const Icon(Icons.close_rounded, color: cineMuted),
              ),
            if (showMic)
              IconButton(
                onPressed: () => unawaited(_toggleVoice()),
                icon: Icon(
                  _voice.isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                  color: _voice.isListening ? cineRed : cineMuted,
                  size: tv ? 30 : 24,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mobile = PlatformDetection.useMobileUi;
    final pad = cineSidePadding(context);
    final topInset = MediaQuery.paddingOf(context).top;
    final empty = _query.isNotEmpty &&
        !_searching &&
        _library.isEmpty &&
        _seerr.isEmpty;

    final slivers = <Widget>[
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            mobile ? 56 : pad,
            topInset + (mobile ? 8 : 72),
            pad,
            8,
          ),
          child: _searchField(context),
        ),
      ),
      if (_searching)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator(color: cineRed)),
          ),
        ),
      if (_query.isEmpty)
        SliverToBoxAdapter(
          child: CineEmptyState(
            title: cineText(
              context,
              '¿Qué te apetece ver?',
              'What do you feel like watching?',
            ),
            message: cineText(
              context,
              'Busca en tu biblioteca y en Seerr a la vez.',
              'Search your library and Seerr at once.',
            ),
          ),
        ),
      if (empty)
        SliverToBoxAdapter(
          child: CineEmptyState(
            title: cineText(
              context,
              'Taquito no ha encontrado nada',
              'Taquito found nothing',
            ),
            message: cineText(
              context,
              'Prueba con otro título o con el nombre de un actor.',
              'Try another title or an actor name.',
            ),
          ),
        ),
      if (_library.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: cineSectionTitle(
            context,
            cineText(context, 'En TaquitoFlix', 'On TaquitoFlix'),
          ),
        ),
        SliverToBoxAdapter(
          child: CineGrid(tiles: [for (final i in _library) _libraryTile(i)]),
        ),
      ],
      if (_seerr.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: cineSectionTitle(
            context,
            cineText(context, 'Para descargar', 'Available to download'),
            topPadding: 32,
          ),
        ),
        SliverToBoxAdapter(
          child: CineGrid(tiles: [for (final i in _seerr) _seerrTile(i)]),
        ),
      ],
      SliverToBoxAdapter(child: SizedBox(height: mobile ? 120 : 80)),
    ];

    return Scaffold(
      backgroundColor: cineBg,
      body: NavigationLayout(
        activeRoute: Destinations.search,
        showBackButton: true,
        child: CustomScrollView(slivers: slivers),
      ),
    );
  }
}
