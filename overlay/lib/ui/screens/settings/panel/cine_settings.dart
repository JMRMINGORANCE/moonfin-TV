part of '../settings_side_panel.dart';

// ---------------------------------------------------------------------------
// TaquitoFlix: Ajustes, rediseñados de cero.
//
// Portada de ajustes con tu perfil sobre un fondo de Taquito y nueve
// categorías propias, cada una con un resumen de lo que tiene puesto:
//
//   Ver ............ Idioma y subtítulos · Reproducción · Portada
//   Tu cuenta ...... Perfil y seguridad · Seerr · Descargas · Protector
//   Sistema ........ Servidor · Acerca de y ayuda
//
// Todo se maneja igual con el dedo que con el mando. Lo que solo tenía
// sentido con la interfaz de Moonfin (temas, estilos, barras, modo infantil,
// logros, plugin, buscador de ajustes…) ya no está. Los pocos procesos muy
// técnicos (inicio de sesión en Seerr, clasificaciones por edad, decodificación
// avanzada, registro completo) siguen detrás de un botón dentro de su página.
// ---------------------------------------------------------------------------

/// Se mantiene por compatibilidad con el parche; la pantalla real es
/// [_CineSettingsHome].
List<_PanelEntry> _cineSettingsEntries(
  BuildContext context,
  AppLocalizations l10n, {
  required bool showAdmin,
  required FocusNode? firstFocus,
  required VoidCallback openAdmin,
}) =>
    const <_PanelEntry>[];

const _kCineCard = Color(0xFF161616);
const _kCineWall = 'assets/images/taquito_wall_1.jpg';

String _t(BuildContext context, String es, String en) =>
    cineText(context, es, en);

UserPreferences get _cinePrefs => GetIt.instance<UserPreferences>();

Future<void> _cinePick<T>(
  BuildContext context, {
  required List<T> values,
  required List<String> labels,
  required T current,
  required ValueChanged<T> onPick,
}) async {
  final picked = await showCinePicker(
    context,
    options: labels,
    selected: values.indexOf(current),
  );
  if (picked != null && picked >= 0 && picked < values.length) {
    onPick(values[picked]);
  }
}

/// Etiqueta del valor actual; "Personalizado" si se cambió desde otra app.
String _cineLabelOf<T>(
  BuildContext context,
  List<T> values,
  List<String> labels,
  T current,
) {
  final i = values.indexOf(current);
  return i < 0 ? _t(context, 'Personalizado', 'Custom') : labels[i];
}

Map<String, String> _cineSegments(UserPreferences prefs) {
  final map = <String, String>{};
  for (final part in prefs.get(UserPreferences.mediaSegmentActions).split(',')) {
    final kv = part.split(':');
    if (kv.length == 2) map[kv[0].trim()] = kv[1].trim();
  }
  return map;
}

Future<void> _cineSetSegment(
  UserPreferences prefs,
  String segment,
  String action,
) {
  final map = _cineSegments(prefs)..[segment] = action;
  return prefs.set(
    UserPreferences.mediaSegmentActions,
    map.entries.map((e) => '${e.key}:${e.value}').join(','),
  );
}

bool _cineSectionOn(UserPreferences prefs, HomeSectionType type) =>
    prefs.homeSectionsConfig.any((c) => c.type == type && c.enabled);

Future<void> _cineSetSections(
  UserPreferences prefs,
  List<HomeSectionType> types,
  bool enabled,
) async {
  final configs = List<HomeSectionConfig>.from(prefs.homeSectionsConfig);
  for (final type in types) {
    final i = configs.indexWhere((c) => c.type == type);
    if (i >= 0) {
      configs[i] = configs[i].copyWith(enabled: enabled);
    } else {
      configs.add(
        HomeSectionConfig(type: type, enabled: enabled, order: configs.length),
      );
    }
  }
  await prefs.setHomeSectionsConfig(configs);
}

void _cineOpen(BuildContext context, Widget page) =>
    context.pushSettingsScreen(page);

// ---------------------------------------------------------------------------
// Piezas visuales comunes
// ---------------------------------------------------------------------------

/// Fila de ajuste: icono, título, valor actual y flecha o interruptor.
class _CineSettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback onTap;
  final bool? switchValue;
  final bool autofocus;
  final bool danger;

  const _CineSettingTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.value,
    this.switchValue,
    this.autofocus = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final tv = cineIsTv;
    final accent = danger ? const Color(0xFFFF5A5F) : cineRed;
    return CineFocusable(
      autofocus: autofocus,
      onActivate: onTap,
      scrollAlignment: 0.4,
      builder: (context, focused) {
        final fg = focused ? Colors.black : Colors.white;
        final sub = focused ? Colors.black54 : cineMuted;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          color: focused ? Colors.white : Colors.transparent,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: tv ? 16 : 13),
          child: Row(
            children: [
              Icon(icon, color: focused ? Colors.black : accent, size: tv ? 26 : 22),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: danger && !focused ? accent : fg,
                        fontSize: tv ? 19 : 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (value != null && value!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        value!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: sub, fontSize: tv ? 16 : 13),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (switchValue != null)
                ExcludeFocus(
                  child: IgnorePointer(
                    child: Switch(
                      value: switchValue!,
                      onChanged: (_) {},
                      activeTrackColor: cineRed,
                      inactiveTrackColor: const Color(0xFF3A3A3A),
                    ),
                  ),
                )
              else
                Icon(Icons.chevron_right_rounded, color: sub),
            ],
          ),
        );
      },
    );
  }
}

/// Categoría de la portada de ajustes: icono en círculo rojo, título grande y
/// un resumen de lo que hay dentro.
class _CineCategoryTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String summary;
  final VoidCallback onTap;
  final bool autofocus;

  const _CineCategoryTile({
    required this.icon,
    required this.title,
    required this.summary,
    required this.onTap,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final tv = cineIsTv;
    return CineFocusable(
      autofocus: autofocus,
      onActivate: onTap,
      scrollAlignment: 0.4,
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        color: focused ? Colors.white : Colors.transparent,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: tv ? 18 : 14),
        child: Row(
          children: [
            Container(
              width: tv ? 50 : 42,
              height: tv ? 50 : 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: focused ? Colors.black : cineRed,
              ),
              child: Icon(icon, color: Colors.white, size: tv ? 26 : 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: focused ? Colors.black : Colors.white,
                      fontSize: tv ? 21 : 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: focused ? Colors.black54 : cineMuted,
                      fontSize: tv ? 16 : 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: focused ? Colors.black54 : cineMuted,
            ),
          ],
        ),
      ),
    );
  }
}

Widget _cineSection(BuildContext context, String title, List<Widget> tiles) {
  final tv = cineIsTv;
  if (tiles.isEmpty) return const SizedBox.shrink();
  return Padding(
    padding: EdgeInsets.fromLTRB(tv ? 28 : 16, tv ? 26 : 22, tv ? 28 : 16, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                color: cineMuted,
                fontSize: tv ? 15 : 12,
                letterSpacing: 1.6,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: ColoredBox(
            color: _kCineCard,
            child: Column(
              children: [
                for (var i = 0; i < tiles.length; i++) ...[
                  if (i > 0)
                    const Divider(
                      height: 1,
                      thickness: 1,
                      indent: 16,
                      color: Color(0xFF262626),
                    ),
                  tiles[i],
                ],
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

/// Texto explicativo bajo el título de una página.
Widget _cineIntro(BuildContext context, String text) {
  final tv = cineIsTv;
  return Padding(
    padding: EdgeInsets.fromLTRB(tv ? 32 : 20, 4, tv ? 32 : 20, 0),
    child: Text(
      text,
      style: TextStyle(color: cineMuted, fontSize: tv ? 17 : 14, height: 1.35),
    ),
  );
}

PreferredSizeWidget _cineSettingsBar(
  BuildContext context,
  String title, {
  VoidCallback? onClose,
}) {
  final tv = cineIsTv;
  return AppBar(
    backgroundColor: cineBg,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    // En la tele se vuelve con el botón Atrás del mando: la flecha de la barra
    // recibía el foco sin verse y parecía que el cursor desaparecía.
    automaticallyImplyLeading: onClose == null && !PlatformDetection.isTV,
    leading: onClose != null && !PlatformDetection.isTV
        ? IconButton(onPressed: onClose, icon: const Icon(Icons.close))
        : null,
    title: Text(
      title,
      style: TextStyle(
        color: Colors.white,
        fontSize: tv ? 30 : 22,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

/// Página de ajustes: barra con título y contenido que se redibuja solo al
/// cambiar cualquier preferencia.
class _CinePage extends StatelessWidget {
  final String title;
  final List<Widget> Function(BuildContext context, UserPreferences prefs)
      builder;

  const _CinePage({required this.title, required this.builder});

  @override
  Widget build(BuildContext context) {
    final prefs = _cinePrefs;
    return Scaffold(
      backgroundColor: cineBg,
      appBar: _cineSettingsBar(context, title),
      body: ListenableBuilder(
        listenable: prefs,
        builder: (context, _) => ListView(
          // Todas las filas montadas: el mando nunca se queda sin destino.
          cacheExtent: 4000,
          padding: const EdgeInsets.only(bottom: 56),
          children: builder(context, prefs),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Portada de ajustes
// ---------------------------------------------------------------------------

class _CineSettingsHome extends StatelessWidget {
  final bool showAdmin;
  final VoidCallback onClose;
  final VoidCallback openAdmin;

  const _CineSettingsHome({
    required this.showAdmin,
    required this.onClose,
    required this.openAdmin,
  });

  @override
  Widget build(BuildContext context) {
    final prefs = _cinePrefs;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: cineBg,
      appBar: _cineSettingsBar(context, l10n.settings, onClose: onClose),
      body: ListenableBuilder(
        listenable: prefs,
        builder: (context, _) => ListView(
          // Todas las filas montadas: el mando nunca se queda sin destino.
          cacheExtent: 4000,
          padding: const EdgeInsets.only(bottom: 48),
          children: [
            _CineProfileHeader(onClose: onClose),
            _cineSection(context, _t(context, 'Ver', 'Watching'), [
              _CineCategoryTile(
                icon: Icons.translate_rounded,
                title: _t(context, 'Idioma y subtítulos', 'Language and subtitles'),
                summary: _languageSummary(context, prefs),
                onTap: () => _cineOpen(context, const _CineLanguagePage()),
              ),
              _CineCategoryTile(
                icon: Icons.play_arrow_rounded,
                title: _t(context, 'Reproducción', 'Playback'),
                summary: _playbackSummary(context, prefs),
                onTap: () => _cineOpen(context, const _CinePlaybackPage()),
              ),
              _CineCategoryTile(
                icon: Icons.view_carousel_rounded,
                title: _t(context, 'Portada', 'Home'),
                summary: _homeSummary(context, prefs),
                onTap: () => _cineOpen(context, const _CineHomePage()),
              ),
            ]),
            _cineSection(context, _t(context, 'Tu cuenta', 'Your account'), [
              _CineCategoryTile(
                icon: Icons.shield_rounded,
                title: _t(context, 'Perfil y seguridad', 'Profile and security'),
                summary: _profileSummary(context),
                onTap: () => _cineOpen(context, const _CineProfilePage()),
              ),
              _CineCategoryTile(
                icon: Icons.download_rounded,
                title: 'Seerr',
                summary: GetIt.instance<PluginSyncService>().seerrAvailable
                    ? _t(context, 'Conectado: descarga desde la app', 'Connected: download from the app')
                    : _t(context, 'Sin conectar', 'Not connected'),
                onTap: () => _cineOpen(context, const _CineSeerrPage()),
              ),
              if (!PlatformDetection.isWeb)
                _CineCategoryTile(
                  icon: Icons.download_for_offline_rounded,
                  title: _t(context, 'Descargas en el dispositivo', 'Device downloads'),
                  summary: _downloadsSummary(context, prefs),
                  onTap: () => _cineOpen(context, const _CineDownloadsPage()),
                ),
              if (PlatformDetection.isTV)
                _CineCategoryTile(
                  icon: Icons.pets_rounded,
                  title: _t(context, 'Protector de pantalla', 'Screensaver'),
                  summary: prefs.get(UserPreferences.screensaverEnabled)
                      ? _t(
                          context,
                          'Taquito sale tras ${prefs.get(UserPreferences.screensaverTimeout).minutes} min',
                          'Taquito appears after ${prefs.get(UserPreferences.screensaverTimeout).minutes} min',
                        )
                      : _t(context, 'Desactivado', 'Off'),
                  onTap: () => _cineOpen(context, const _CineScreensaverPage()),
                ),
            ]),
            _cineSection(context, _t(context, 'Sistema', 'System'), [
              _CineCategoryTile(
                icon: Icons.dns_rounded,
                title: _t(context, 'Servidor', 'Server'),
                summary: _serverSummary(context),
                onTap: () => _cineOpen(
                  context,
                  _CineServerPage(
                    showAdmin: showAdmin,
                    onClose: onClose,
                    openAdmin: openAdmin,
                  ),
                ),
              ),
              _CineCategoryTile(
                icon: Icons.info_rounded,
                title: _t(context, 'Acerca de y ayuda', 'About and help'),
                summary: 'TaquitoFlix ${AppBeta.label(GetIt.instance<DeviceInfo>().appVersion)}',
                onTap: () => _cineOpen(context, const _CineAboutPage()),
              ),
            ]),
            const _CineFooter(),
          ],
        ),
      ),
    );
  }

  static String _languageSummary(BuildContext context, UserPreferences prefs) {
    final audio = prefs.get(UserPreferences.defaultAudioLanguage);
    final audioLabel = audio == 'auto'
        ? _t(context, 'el del servidor', 'server default')
        : (supportedLanguageOptions[audio] ?? audio);
    final subs = prefs.get(UserPreferences.subtitleMode) == SubtitleMode.none
        ? _t(context, 'sin subtítulos', 'no subtitles')
        : _t(context, 'con subtítulos', 'with subtitles');
    return _t(context, 'Audio: $audioLabel · $subs', 'Audio: $audioLabel · $subs');
  }

  static String _playbackSummary(BuildContext context, UserPreferences prefs) {
    final bitrate = prefs.get(UserPreferences.maxBitrate);
    final q = bitrate == 'auto'
        ? _t(context, 'calidad automática', 'automatic quality')
        : _t(context, 'hasta $bitrate Mbps', 'up to $bitrate Mbps');
    final skip = prefs.get(UserPreferences.skipForwardLength) ~/ 1000;
    return _t(context, '${q[0].toUpperCase()}${q.substring(1)} · saltos de $skip s',
        '${q[0].toUpperCase()}${q.substring(1)} · $skip s skips');
  }

  static String _homeSummary(BuildContext context, UserPreferences prefs) {
    final trailer = prefs.get(UserPreferences.mediaBarTrailerPreview);
    return trailer
        ? _t(context, 'Filas a tu gusto · tráiler automático', 'Your rows · autoplay trailer')
        : _t(context, 'Filas a tu gusto · sin tráiler', 'Your rows · no trailer');
  }

  static String _profileSummary(BuildContext context) {
    final session = GetIt.instance<SessionRepository>();
    final pin = PinCodeUtil(
      GetIt.instance<PreferenceStore>(),
      session.activeUserId ?? '',
    ).isPinEnabled;
    return pin
        ? _t(context, 'PIN activado · control parental', 'PIN on · parental controls')
        : _t(context, 'Sin PIN · control parental', 'No PIN · parental controls');
  }

  static String _downloadsSummary(BuildContext context, UserPreferences prefs) {
    final wifi = prefs.get(UserPreferences.downloadWifiOnly);
    return wifi
        ? _t(context, 'Solo con wifi', 'Wi-Fi only')
        : _t(context, 'Con wifi y datos', 'Wi-Fi and mobile data');
  }

  static String _serverSummary(BuildContext context) {
    final id = GetIt.instance<SessionRepository>().activeServerId;
    final server = id == null ? null : GetIt.instance<ServerRepository>().getServer(id);
    return server?.name ?? _t(context, 'Sin servidor', 'No server');
  }
}

/// Cabecera con tu perfil sobre un fondo de Taquito.
class _CineProfileHeader extends StatelessWidget {
  final VoidCallback onClose;

  const _CineProfileHeader({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final tv = cineIsTv;
    final session = GetIt.instance<SessionRepository>();
    final serverId = session.activeServerId;
    final userId = session.activeUserId;
    var name = _t(context, 'Tu perfil', 'Your profile');
    String? serverName;
    if (serverId != null) {
      serverName = GetIt.instance<ServerRepository>().getServer(serverId)?.name;
      for (final u
          in GetIt.instance<ServerUserRepository>().getStoredServerUsers(serverId)) {
        if (u.id == userId) name = u.name;
      }
    }
    final avatar = tv ? 92.0 : 72.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(tv ? 28 : 16, 8, tv ? 28 : 16, 0),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: _kCineCard,
          borderRadius: BorderRadius.circular(12),
          image: DecorationImage(
            image: const AssetImage(_kCineWall),
            fit: BoxFit.cover,
            alignment: const Alignment(0.6, -0.2),
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.45),
              BlendMode.darken,
            ),
            onError: (_, _) {},
          ),
        ),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xE6000000), Color(0x66000000)],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(tv ? 22 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: avatar,
                      height: avatar,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: cineRed,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SvgPicture.asset('assets/icons/moonfin_logo.svg'),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _t(context, '¡Hola, $name!', 'Hi, $name!'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: tv ? 28 : 21,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (serverName != null)
                            Text(
                              _t(context, 'Viendo en $serverName', 'Watching on $serverName'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: const Color(0xFFDDDDDD),
                                fontSize: tv ? 17 : 13,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    CineButton(
                      autofocus: tv,
                      icon: Icons.switch_account_rounded,
                      label: _t(context, 'Cambiar de perfil', 'Switch profile'),
                      primary: true,
                      onTap: () {
                        final router = GoRouter.of(context);
                        onClose();
                        if (serverId != null && serverId.isNotEmpty) {
                          router.go('${Destinations.server}?serverId=$serverId');
                        } else {
                          router.go(Destinations.serverSelect);
                        }
                      },
                    ),
                    CineButton(
                      icon: Icons.logout_rounded,
                      label: _t(context, 'Cerrar sesión', 'Sign out'),
                      primary: false,
                      onTap: () async {
                        final router = GoRouter.of(context);
                        await session.destroyCurrentSession();
                        onClose();
                        router.go(Destinations.serverSelect);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CineFooter extends StatelessWidget {
  const _CineFooter();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: SvgPicture.asset('assets/icons/moonfin_logo.svg'),
          ),
          const SizedBox(height: 8),
          Text(
            _t(context, 'Taquito vigila tus ajustes', 'Taquito guards your settings'),
            style: const TextStyle(color: Color(0xFF6E6E6E), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Idioma y subtítulos
// ---------------------------------------------------------------------------

class _CineLanguagePage extends StatelessWidget {
  const _CineLanguagePage();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _CinePage(
      title: _t(context, 'Idioma y subtítulos', 'Language and subtitles'),
      builder: (context, prefs) {
        final languages = supportedLanguageOptions;
        String langLabel(String code, {String? empty}) {
          if (code.isEmpty) return empty ?? l10n.none;
          if (code == 'auto') return _t(context, 'El que diga el servidor', 'Server default');
          return languages[code] ?? code;
        }

        const appLangs = ['es', 'system', 'en'];
        final appLangLabels = [
          'Español',
          _t(context, 'El del dispositivo', 'Device language'),
          'English',
        ];
        final appLang = prefs.get(UserPreferences.languageOverride);
        final audio = prefs.get(UserPreferences.defaultAudioLanguage);
        final fallback = prefs.get(UserPreferences.fallbackAudioLanguage);
        final subMode = prefs.get(UserPreferences.subtitleMode);
        final subLang = prefs.get(UserPreferences.defaultSubtitleLanguage);
        String subModeLabel(SubtitleMode v) => switch (v) {
              SubtitleMode.none => _t(context, 'Nunca', 'Never'),
              SubtitleMode.always => _t(context, 'Siempre', 'Always'),
              SubtitleMode.foreign => _t(context, 'Cuando el audio no está en tu idioma', 'When audio is in another language'),
              SubtitleMode.forced => _t(context, 'Solo los forzados (carteles, otros idiomas)', 'Forced only'),
              SubtitleMode.flagged => _t(context, 'Los que marque el archivo', 'As flagged by the file'),
            };
        final audioCodes = ['auto', ...languages.keys];
        final langCodes = ['', ...languages.keys];
        final noFallback = _t(context, 'El original del título', "The title's original");

        return [
          _cineSection(context, _t(context, 'App', 'App'), [
            _CineSettingTile(
              autofocus: true,
              icon: Icons.translate_rounded,
              title: _t(context, 'Idioma de la aplicación', 'App language'),
              value: _cineLabelOf(context, appLangs, appLangLabels, appLang),
              onTap: () => _cinePick<String>(
                context,
                values: appLangs,
                labels: appLangLabels,
                current: appLang,
                onPick: (v) => prefs.set(UserPreferences.languageOverride, v),
              ),
            ),
          ]),
          _cineSection(context, _t(context, 'Audio', 'Audio'), [
            _CineSettingTile(
              icon: Icons.record_voice_over_rounded,
              title: _t(context, 'Idioma preferido', 'Preferred language'),
              value: langLabel(audio),
              onTap: () => _cinePick<String>(
                context,
                values: audioCodes,
                labels: [for (final c in audioCodes) langLabel(c)],
                current: audio,
                onPick: (v) => prefs.set(UserPreferences.defaultAudioLanguage, v),
              ),
            ),
            _CineSettingTile(
              icon: Icons.multitrack_audio_rounded,
              title: _t(context, 'Si no está en ese idioma', 'If not available'),
              value: langLabel(fallback, empty: noFallback),
              onTap: () => _cinePick<String>(
                context,
                values: langCodes,
                labels: [for (final c in langCodes) langLabel(c, empty: noFallback)],
                current: fallback,
                onPick: (v) => prefs.set(UserPreferences.fallbackAudioLanguage, v),
              ),
            ),
          ]),
          _cineSection(context, _t(context, 'Subtítulos', 'Subtitles'), [
            _CineSettingTile(
              icon: Icons.subtitles_rounded,
              title: _t(context, 'Mostrar subtítulos', 'Show subtitles'),
              value: subModeLabel(subMode),
              onTap: () => _cinePick<SubtitleMode>(
                context,
                values: const [
                  SubtitleMode.none,
                  SubtitleMode.always,
                  SubtitleMode.foreign,
                  SubtitleMode.forced,
                  SubtitleMode.flagged,
                ],
                labels: [
                  for (final v in const [
                    SubtitleMode.none,
                    SubtitleMode.always,
                    SubtitleMode.foreign,
                    SubtitleMode.forced,
                    SubtitleMode.flagged,
                  ])
                    subModeLabel(v),
                ],
                current: subMode,
                onPick: (v) => prefs.set(UserPreferences.subtitleMode, v),
              ),
            ),
            if (subMode != SubtitleMode.none)
              _CineSettingTile(
                icon: Icons.closed_caption_rounded,
                title: _t(context, 'Idioma de los subtítulos', 'Subtitle language'),
                value: langLabel(subLang),
                onTap: () => _cinePick<String>(
                  context,
                  values: langCodes,
                  labels: [for (final c in langCodes) langLabel(c)],
                  current: subLang,
                  onPick: (v) => prefs.set(UserPreferences.defaultSubtitleLanguage, v),
                ),
              ),
            _CineSettingTile(
              icon: Icons.format_size_rounded,
              title: _t(context, 'Aspecto de los subtítulos', 'Subtitle style'),
              value: _t(context, 'Tamaño, color, fondo y posición', 'Size, colour, background and position'),
              onTap: () => _cineOpen(context, const _CineSubtitleStylePage()),
            ),
          ]),
        ];
      },
    );
  }
}

class _CineSubtitleStylePage extends StatelessWidget {
  const _CineSubtitleStylePage();

  static const _sizes = [16.0, 20.0, 26.0, 32.0];
  static const _colors = [0xFFFFFFFF, 0xFFFFEB3B, 0xFFBDBDBD, 0xFF00E5FF, 0xFF76FF03];
  static const _backgrounds = [0x00000000, 0x99000000, 0xFF000000];
  static const _strokes = [0xFF000000, 0x00000000];
  static const _positions = [0.04, 0.10, 0.18];

  @override
  Widget build(BuildContext context) {
    final sizeLabels = [
      _t(context, 'Pequeño', 'Small'),
      _t(context, 'Normal', 'Normal'),
      _t(context, 'Grande', 'Large'),
      _t(context, 'Muy grande', 'Extra large'),
    ];
    final colorLabels = [
      _t(context, 'Blanco', 'White'),
      _t(context, 'Amarillo', 'Yellow'),
      _t(context, 'Gris claro', 'Light grey'),
      _t(context, 'Cian', 'Cyan'),
      _t(context, 'Verde', 'Green'),
    ];
    final bgLabels = [
      _t(context, 'Sin fondo', 'None'),
      _t(context, 'Sombreado', 'Shaded'),
      _t(context, 'Negro', 'Black'),
    ];
    final strokeLabels = [
      _t(context, 'Contorno negro', 'Black outline'),
      _t(context, 'Sin contorno', 'No outline'),
    ];
    final posLabels = [
      _t(context, 'Abajo del todo', 'Bottom'),
      _t(context, 'Un poco más arriba', 'Slightly higher'),
      _t(context, 'Más arriba', 'Higher'),
    ];
    return _CinePage(
      title: _t(context, 'Aspecto de los subtítulos', 'Subtitle style'),
      builder: (context, prefs) {
        final size = prefs.get(UserPreferences.subtitlesTextSize);
        final color = prefs.get(UserPreferences.subtitlesTextColor);
        final bg = prefs.get(UserPreferences.subtitlesBackgroundColor);
        final stroke = prefs.get(UserPreferences.subtitleTextStrokeColor);
        final pos = prefs.get(UserPreferences.subtitlesOffsetPosition);
        return [
          _CineSubtitlePreview(
            size: size,
            color: Color(color),
            background: Color(bg),
            stroke: Color(stroke),
            offset: pos,
          ),
          _cineSection(context, '', [
            _CineSettingTile(
              autofocus: true,
              icon: Icons.format_size_rounded,
              title: _t(context, 'Tamaño', 'Size'),
              value: _cineLabelOf(context, _sizes, sizeLabels, size),
              onTap: () => _cinePick<double>(
                context,
                values: _sizes,
                labels: sizeLabels,
                current: size,
                onPick: (v) => prefs.set(UserPreferences.subtitlesTextSize, v),
              ),
            ),
            _CineSettingTile(
              icon: Icons.format_color_text_rounded,
              title: _t(context, 'Color del texto', 'Text colour'),
              value: _cineLabelOf(context, _colors, colorLabels, color),
              onTap: () => _cinePick<int>(
                context,
                values: _colors,
                labels: colorLabels,
                current: color,
                onPick: (v) => prefs.set(UserPreferences.subtitlesTextColor, v),
              ),
            ),
            _CineSettingTile(
              icon: Icons.format_color_fill_rounded,
              title: _t(context, 'Fondo', 'Background'),
              value: _cineLabelOf(context, _backgrounds, bgLabels, bg),
              onTap: () => _cinePick<int>(
                context,
                values: _backgrounds,
                labels: bgLabels,
                current: bg,
                onPick: (v) => prefs.set(UserPreferences.subtitlesBackgroundColor, v),
              ),
            ),
            _CineSettingTile(
              icon: Icons.border_style_rounded,
              title: _t(context, 'Contorno', 'Outline'),
              value: _cineLabelOf(context, _strokes, strokeLabels, stroke),
              onTap: () => _cinePick<int>(
                context,
                values: _strokes,
                labels: strokeLabels,
                current: stroke,
                onPick: (v) => prefs.set(UserPreferences.subtitleTextStrokeColor, v),
              ),
            ),
            _CineSettingTile(
              icon: Icons.vertical_align_bottom_rounded,
              title: _t(context, 'Posición', 'Position'),
              value: _cineLabelOf(context, _positions, posLabels, pos),
              onTap: () => _cinePick<double>(
                context,
                values: _positions,
                labels: posLabels,
                current: pos,
                onPick: (v) => prefs.set(UserPreferences.subtitlesOffsetPosition, v),
              ),
            ),
          ]),
        ];
      },
    );
  }
}

/// Vista previa en directo de los subtítulos sobre un fondo de Taquito.
class _CineSubtitlePreview extends StatelessWidget {
  final double size;
  final Color color;
  final Color background;
  final Color stroke;
  final double offset;

  const _CineSubtitlePreview({
    required this.size,
    required this.color,
    required this.background,
    required this.stroke,
    required this.offset,
  });

  @override
  Widget build(BuildContext context) {
    final tv = cineIsTv;
    final text = _t(
      context,
      '¡Guau! Así se verán tus subtítulos.',
      'Woof! This is how your subtitles look.',
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(tv ? 28 : 16, 8, tv ? 28 : 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: LayoutBuilder(
            builder: (context, box) {
              // El tamaño se escala al ancho de la vista previa.
              final scale = (box.maxWidth / 560).clamp(0.6, 1.6);
              final fontSize = size * scale;
              final style = TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                height: 1.2,
              );
              return Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    _kCineWall,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const ColoredBox(color: cineCardBg),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: box.maxHeight * offset + 8,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        color: background,
                        child: Stack(
                          children: [
                            if (stroke.a > 0)
                              Text(
                                text,
                                textAlign: TextAlign.center,
                                style: style.copyWith(
                                  foreground: Paint()
                                    ..style = PaintingStyle.stroke
                                    ..strokeWidth = (fontSize / 7).clamp(2.0, 5.0)
                                    ..color = stroke,
                                ),
                              ),
                            Text(
                              text,
                              textAlign: TextAlign.center,
                              style: style.copyWith(color: color),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reproducción
// ---------------------------------------------------------------------------

class _CinePlaybackPage extends StatelessWidget {
  const _CinePlaybackPage();

  @override
  Widget build(BuildContext context) {
    return _CinePage(
      title: _t(context, 'Reproducción', 'Playback'),
      builder: (context, prefs) {
        const bitrates = ['auto', '120', '40', '20', '10', '5', '2'];
        final bitrateLabels = [
          _t(context, 'Automática (la mejor que aguante la conexión)', 'Automatic'),
          _t(context, 'Máxima (120 Mbps)', 'Highest (120 Mbps)'),
          _t(context, 'Alta (40 Mbps)', 'High (40 Mbps)'),
          _t(context, 'Buena (20 Mbps)', 'Good (20 Mbps)'),
          _t(context, 'Media (10 Mbps)', 'Medium (10 Mbps)'),
          _t(context, 'Ahorro de datos (5 Mbps)', 'Data saver (5 Mbps)'),
          _t(context, 'Mínima (2 Mbps)', 'Lowest (2 Mbps)'),
        ];
        final bitrate = prefs.get(UserPreferences.maxBitrate);
        final resolution = prefs.get(UserPreferences.maxVideoResolution);
        String resLabel(MaxVideoResolution v) => switch (v) {
              MaxVideoResolution.auto => _t(context, 'Sin límite', 'No limit'),
              MaxVideoResolution.res480p => '480p',
              MaxVideoResolution.res720p => '720p (HD)',
              MaxVideoResolution.res1080p => '1080p (Full HD)',
              MaxVideoResolution.res2160p => '4K',
            };
        const segmentActions = ['askToSkip', 'skip', 'nothing'];
        final segmentLabels = [
          _t(context, 'Mostrar botón para saltar', 'Show a skip button'),
          _t(context, 'Saltar automáticamente', 'Skip automatically'),
          _t(context, 'No hacer nada', 'Do nothing'),
        ];
        final segments = _cineSegments(prefs);
        const skips = [5000, 10000, 15000, 30000];
        const skipLabels = ['5 s', '10 s', '15 s', '30 s'];
        return [
          _cineSection(context, _t(context, 'Calidad', 'Quality'), [
            _CineSettingTile(
              autofocus: true,
              icon: Icons.network_check_rounded,
              title: _t(context, 'Calidad de vídeo', 'Video quality'),
              value: bitrates.contains(bitrate)
                  ? bitrateLabels[bitrates.indexOf(bitrate)]
                  : '$bitrate Mbps',
              onTap: () => _cinePick<String>(
                context,
                values: bitrates,
                labels: bitrateLabels,
                current: bitrate,
                onPick: (v) => prefs.set(UserPreferences.maxBitrate, v),
              ),
            ),
            _CineSettingTile(
              icon: Icons.high_quality_rounded,
              title: _t(context, 'Resolución máxima', 'Maximum resolution'),
              value: resLabel(resolution),
              onTap: () => _cinePick<MaxVideoResolution>(
                context,
                values: MaxVideoResolution.values,
                labels: [for (final v in MaxVideoResolution.values) resLabel(v)],
                current: resolution,
                onPick: (v) => prefs.set(UserPreferences.maxVideoResolution, v),
              ),
            ),
          ]),
          _cineSection(context, _t(context, 'Mientras ves', 'While watching'), [
            _CineSettingTile(
              icon: Icons.replay_10_rounded,
              title: _t(context, 'Saltos al retroceder y avanzar', 'Skip back and forward'),
              value: _cineLabelOf(
                context,
                skips,
                skipLabels,
                prefs.get(UserPreferences.skipForwardLength),
              ),
              onTap: () => _cinePick<int>(
                context,
                values: skips,
                labels: skipLabels,
                current: prefs.get(UserPreferences.skipForwardLength),
                onPick: (v) async {
                  await prefs.set(UserPreferences.skipBackLength, v);
                  await prefs.set(UserPreferences.skipForwardLength, v);
                },
              ),
            ),
            _CineSettingTile(
              icon: Icons.fast_forward_rounded,
              title: _t(context, 'Intros', 'Intros'),
              value: _cineLabelOf(
                context,
                segmentActions,
                segmentLabels,
                segments['intro'] ?? 'askToSkip',
              ),
              onTap: () => _cinePick<String>(
                context,
                values: segmentActions,
                labels: segmentLabels,
                current: segments['intro'] ?? 'askToSkip',
                onPick: (v) => _cineSetSegment(prefs, 'intro', v),
              ),
            ),
            _CineSettingTile(
              icon: Icons.last_page_rounded,
              title: _t(context, 'Créditos finales', 'End credits'),
              value: _cineLabelOf(
                context,
                segmentActions,
                segmentLabels,
                segments['outro'] ?? 'askToSkip',
              ),
              onTap: () => _cinePick<String>(
                context,
                values: segmentActions,
                labels: segmentLabels,
                current: segments['outro'] ?? 'askToSkip',
                onPick: (v) => _cineSetSegment(prefs, 'outro', v),
              ),
            ),
          ]),
          _cineSection(context, _t(context, 'Series', 'Series'), [
            _CineSettingTile(
              icon: Icons.skip_next_rounded,
              title: _t(context, 'Siguiente episodio automático', 'Autoplay next episode'),
              value: _t(context, 'Empieza solo al acabar la cuenta atrás', 'Starts after the countdown'),
              switchValue: prefs.get(UserPreferences.autoplayNextEpisode),
              onTap: () => prefs.set(
                UserPreferences.autoplayNextEpisode,
                !prefs.get(UserPreferences.autoplayNextEpisode),
              ),
            ),
            _CineSettingTile(
              icon: Icons.queue_play_next_rounded,
              title: _t(context, '"Siguiente episodio" en los créditos', '"Next episode" at the credits'),
              value: _t(context, 'Si el servidor tiene marcados los créditos', 'If the server marks the credits'),
              switchValue: prefs.get(UserPreferences.replaceSkipOutroWithNextUp),
              onTap: () => prefs.set(
                UserPreferences.replaceSkipOutroWithNextUp,
                !prefs.get(UserPreferences.replaceSkipOutroWithNextUp),
              ),
            ),
          ]),
          _cineSection(context, _t(context, 'Si algo no se ve bien', 'If something looks wrong'), [
            _CineSettingTile(
              icon: Icons.memory_rounded,
              title: _t(context, 'Reproductor y decodificación', 'Player and decoding'),
              value: _t(context, 'Opciones técnicas para casos concretos', 'Technical options for special cases'),
              onTap: () => _cineOpen(context, const _PlaybackCategoryScreen()),
            ),
          ]),
        ];
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Portada
// ---------------------------------------------------------------------------

class _CineHomePage extends StatelessWidget {
  const _CineHomePage();

  @override
  Widget build(BuildContext context) {
    return _CinePage(
      title: _t(context, 'Portada', 'Home'),
      builder: (context, prefs) {
        _CineSettingTile own(
          IconData icon,
          String title,
          String value,
          Preference<bool> pref, {
          bool autofocus = false,
        }) =>
            _CineSettingTile(
              autofocus: autofocus,
              icon: icon,
              title: title,
              value: value,
              switchValue: prefs.get(pref),
              onTap: () => prefs.set(pref, !prefs.get(pref)),
            );

        _CineSettingTile section(
          IconData icon,
          String title,
          String value,
          List<HomeSectionType> types,
        ) {
          final on = _cineSectionOn(prefs, types.first);
          return _CineSettingTile(
            icon: icon,
            title: title,
            value: value,
            switchValue: on,
            onTap: () async {
              await _cineSetSections(prefs, types, !on);
              if (types.contains(HomeSectionType.sinceYouWatched1)) {
                await prefs.set(UserPreferences.sinceYouWatched1Enabled, !on);
                await prefs.set(UserPreferences.sinceYouWatched2Enabled, !on);
                await prefs.set(UserPreferences.sinceYouWatched3Enabled, !on);
              }
            },
          );
        }

        return [
          _cineIntro(
            context,
            _t(
              context,
              'Elige qué filas ves al entrar. Los cambios se aplican al momento.',
              'Choose which rows you see. Changes apply right away.',
            ),
          ),
          _cineSection(context, _t(context, 'Arriba del todo', 'At the top'), [
            _CineSettingTile(
              autofocus: true,
              icon: Icons.movie_filter_rounded,
              title: _t(context, 'Tráiler automático', 'Autoplay trailer'),
              value: _t(context, 'En silencio, en la cabecera de la portada', 'Muted, in the Home header'),
              switchValue: prefs.get(UserPreferences.mediaBarTrailerPreview),
              onTap: () => prefs.set(
                UserPreferences.mediaBarTrailerPreview,
                !prefs.get(UserPreferences.mediaBarTrailerPreview),
              ),
            ),
          ]),
          _cineSection(context, _t(context, 'Filas', 'Rows'), [
            section(
              Icons.play_circle_outline_rounded,
              _t(context, 'Seguir viendo', 'Continue watching'),
              _t(context, 'Lo que dejaste a medias', 'What you left halfway'),
              const [HomeSectionType.resume],
            ),
            section(
              Icons.skip_next_rounded,
              _t(context, 'Siguiente episodio', 'Next up'),
              _t(context, 'El próximo capítulo de tus series', 'The next episode of your series'),
              const [HomeSectionType.nextUp],
            ),
            own(
              Icons.download_done_rounded,
              _t(context, 'Recién descargado para ti', 'Just downloaded for you'),
              _t(context, 'Lo que pediste en Seerr y ya está', 'What you requested in Seerr'),
              cineShowDownloadedRow,
            ),
            own(
              Icons.fiber_new_rounded,
              _t(context, 'Lo último añadido', 'Recently added'),
              _t(context, 'Novedades de todas las bibliotecas', 'New in all libraries'),
              cineShowLatestRow,
            ),
            own(
              Icons.emoji_events_rounded,
              _t(context, 'Top 10', 'Top 10'),
              _t(context, 'Lo mejor valorado de tu biblioteca', 'Best rated in your library'),
              cineShowTop10Row,
            ),
            section(
              Icons.auto_awesome_rounded,
              _t(context, 'Porque viste…', 'Because you watched…'),
              _t(context, 'Recomendaciones a partir de lo que ves', 'Recommendations from what you watch'),
              const [
                HomeSectionType.sinceYouWatched1,
                HomeSectionType.sinceYouWatched2,
                HomeSectionType.sinceYouWatched3,
              ],
            ),
            section(
              Icons.video_library_rounded,
              _t(context, 'Novedades por biblioteca', 'Latest per library'),
              _t(context, 'Una fila por cada biblioteca', 'One row per library'),
              const [HomeSectionType.latestMedia],
            ),
            own(
              Icons.collections_bookmark_rounded,
              _t(context, 'Sagas', 'Collections'),
              _t(context, 'Colecciones del servidor en orden de estreno', 'Server collections in release order'),
              cineShowCollectionsRow,
            ),
          ]),
          _cineSection(context, _t(context, 'Seguir viendo', 'Continue watching'), [
            _CineSettingTile(
              icon: Icons.history_toggle_off_rounded,
              title: _t(context, 'Limpiar lo abandonado', 'Hide abandoned titles'),
              value: _t(context, 'Oculta lo que llevas más de 3 meses sin ver', 'Hides what you have not touched in 3 months'),
              switchValue: prefs.get(cineHideStaleResume),
              onTap: () => prefs.set(cineHideStaleResume, !prefs.get(cineHideStaleResume)),
            ),
          ]),
          _cineSection(context, _t(context, 'Más', 'More'), [
            _CineSettingTile(
              icon: Icons.tune_rounded,
              title: _t(context, 'Todas las filas y su orden', 'All rows and their order'),
              value: _t(context, 'Favoritos, géneros, TV en directo, música…', 'Favourites, genres, live TV, music…'),
              onTap: () => _cineOpen(context, const HomeRowTogglesScreen()),
            ),
          ]),
        ];
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Perfil y seguridad
// ---------------------------------------------------------------------------

class _CineProfilePage extends StatefulWidget {
  const _CineProfilePage();

  @override
  State<_CineProfilePage> createState() => _CineProfilePageState();
}

class _CineProfilePageState extends State<_CineProfilePage> {
  late final PinCodeUtil _pin = PinCodeUtil(
    GetIt.instance<PreferenceStore>(),
    GetIt.instance<SessionRepository>().activeUserId ?? '',
  );
  bool _busy = false;

  Future<bool> _verify() => PinEntryDialog.show(
        context,
        mode: PinEntryMode.verify,
        onVerify: _pin.verifyPin,
      );

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    _busy = true;
    try {
      await action();
    } finally {
      _busy = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _setPin() => _run(() async {
        await PinEntryDialog.show(
          context,
          mode: PinEntryMode.set,
          onPinSet: (pin) async => _pin.setPin(pin),
        );
      });

  Future<void> _changePin() => _run(() async {
        if (!await _verify() || !mounted) return;
        await PinEntryDialog.show(
          context,
          mode: PinEntryMode.set,
          onPinSet: (pin) async => _pin.setPin(pin),
        );
      });

  Future<void> _removePin() => _run(() async {
        if (!await _verify() || !mounted) return;
        await _pin.removePin();
      });

  @override
  Widget build(BuildContext context) {
    final pinOn = _pin.isPinEnabled;
    return _CinePage(
      title: _t(context, 'Perfil y seguridad', 'Profile and security'),
      builder: (context, prefs) {
        const behaviors = [UserSelectBehavior.lastUser, UserSelectBehavior.disabled];
        final behaviorLabels = [
          _t(context, 'Entrar con el último perfil', 'Use the last profile'),
          _t(context, 'Preguntar siempre "¿Quién está viendo?"', 'Always ask "Who is watching?"'),
        ];
        final behavior = prefs.get(UserPreferences.autoLoginUserBehavior);
        return [
          _cineSection(context, _t(context, 'PIN del perfil', 'Profile PIN'), [
            _CineSettingTile(
              autofocus: true,
              icon: Icons.pin_rounded,
              title: _t(context, 'Proteger este perfil con PIN', 'Protect this profile with a PIN'),
              value: _t(context, 'Se pide al entrar en el perfil', 'Asked when opening the profile'),
              switchValue: pinOn,
              onTap: () => pinOn ? _removePin() : _setPin(),
            ),
            if (pinOn)
              _CineSettingTile(
                icon: Icons.password_rounded,
                title: _t(context, 'Cambiar el PIN', 'Change PIN'),
                onTap: () => unawaited(_changePin()),
              ),
          ]),
          _cineSection(context, _t(context, 'Al abrir la app', 'When the app opens'), [
            _CineSettingTile(
              icon: Icons.people_alt_rounded,
              title: _t(context, 'Perfil al entrar', 'Profile on start'),
              value: _cineLabelOf(context, behaviors, behaviorLabels, behavior),
              onTap: () => _cinePick<UserSelectBehavior>(
                context,
                values: behaviors,
                labels: behaviorLabels,
                current: behavior,
                onPick: (v) => prefs.set(UserPreferences.autoLoginUserBehavior, v),
              ),
            ),
            _CineSettingTile(
              icon: Icons.key_rounded,
              title: _t(context, 'Pedir siempre la contraseña', 'Always ask for the password'),
              value: _t(context, 'Más seguro en una tele compartida', 'Safer on a shared TV'),
              switchValue: prefs.get(UserPreferences.alwaysAuthenticate),
              onTap: () => prefs.set(
                UserPreferences.alwaysAuthenticate,
                !prefs.get(UserPreferences.alwaysAuthenticate),
              ),
            ),
          ]),
          _cineSection(context, _t(context, 'Control parental', 'Parental controls'), [
            _CineSettingTile(
              icon: Icons.family_restroom_rounded,
              title: _t(context, 'Clasificaciones bloqueadas', 'Blocked ratings'),
              value: _t(context, 'Oculta lo que no es para todas las edades', 'Hide what is not for all ages'),
              onTap: () => _cineOpen(context, const ParentalSettingsScreen()),
            ),
          ]),
        ];
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Seerr
// ---------------------------------------------------------------------------

class _CineSeerrPage extends StatelessWidget {
  const _CineSeerrPage();

  @override
  Widget build(BuildContext context) {
    return _CinePage(
      title: 'Seerr',
      builder: (context, prefs) {
        final connected = GetIt.instance<PluginSyncService>().seerrAvailable;
        final tv = cineIsTv;
        return [
          Padding(
            padding: EdgeInsets.fromLTRB(tv ? 28 : 16, 8, tv ? 28 : 16, 0),
            child: Container(
              padding: EdgeInsets.all(tv ? 20 : 16),
              decoration: BoxDecoration(
                color: _kCineCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: connected ? const Color(0xFF1F9D55) : const Color(0xFF3A3A3A),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: tv ? 64 : 52,
                    height: tv ? 64 : 52,
                    child: SvgPicture.asset('assets/icons/moonfin_logo.svg'),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          connected
                              ? _t(context, 'Seerr está conectado', 'Seerr is connected')
                              : _t(context, 'Seerr no está conectado', 'Seerr is not connected'),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: tv ? 21 : 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          connected
                              ? _t(context, 'Taquito puede buscar y descargar lo que no tienes.', 'Taquito can find and download what you are missing.')
                              : _t(context, 'Conéctalo para descargar películas y series desde la app.', 'Connect it to download from the app.'),
                          style: TextStyle(color: cineMuted, fontSize: tv ? 16 : 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _cineSection(context, '', [
            _CineSettingTile(
              autofocus: true,
              icon: Icons.manage_accounts_rounded,
              title: _t(context, 'Cuenta y conexión', 'Account and connection'),
              value: _t(context, 'Iniciar sesión, servidor y perfiles de descarga', 'Sign in, server and download profiles'),
              onTap: () => _cineOpen(context, const SeerrConfigScreen()),
            ),
            _CineSettingTile(
              icon: Icons.label_rounded,
              title: _t(context, 'Etiquetas en las carátulas', 'Badges on posters'),
              value: _t(context, 'YA DESCARGADA, DESCARGANDO, PARCIAL…', 'DOWNLOADED, DOWNLOADING, PARTIAL…'),
              switchValue: prefs.get(UserPreferences.showSeerrAvailabilityBadges),
              onTap: () => prefs.set(
                UserPreferences.showSeerrAvailabilityBadges,
                !prefs.get(UserPreferences.showSeerrAvailabilityBadges),
              ),
            ),
          ]),
        ];
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Descargas en el dispositivo
// ---------------------------------------------------------------------------

class _CineDownloadsPage extends StatelessWidget {
  const _CineDownloadsPage();

  @override
  Widget build(BuildContext context) {
    return _CinePage(
      title: _t(context, 'Descargas en el dispositivo', 'Device downloads'),
      builder: (context, prefs) {
        final qualities = DownloadQuality.values.map((q) => q.name).toList();
        String qLabel(String name) => switch (name) {
              'original' => _t(context, 'Original (la mejor, ocupa más)', 'Original (best, largest)'),
              'high1080p' => _t(context, 'Alta (1080p)', 'High (1080p)'),
              'medium720p' => _t(context, 'Media (720p)', 'Medium (720p)'),
              'low480p' => _t(context, 'Baja (480p)', 'Low (480p)'),
              'mobile360p' => _t(context, 'Para el móvil (360p, ocupa poco)', 'Mobile (360p, small)'),
              _ => name,
            };
        const limits = [0, 5120, 10240, 25600, 51200];
        final limitLabels = [
          _t(context, 'Sin límite', 'No limit'),
          '5 GB',
          '10 GB',
          '25 GB',
          '50 GB',
        ];
        final quality = prefs.get(UserPreferences.defaultDownloadQuality);
        final limit = prefs.get(UserPreferences.downloadStorageLimitMb);
        return [
          _cineIntro(
            context,
            _t(
              context,
              'Para ver sin conexión: usa el botón de descarga de cada ficha.',
              'To watch offline, use the download button on each title.',
            ),
          ),
          _cineSection(context, '', [
            _CineSettingTile(
              autofocus: true,
              icon: Icons.high_quality_rounded,
              title: _t(context, 'Calidad de las descargas', 'Download quality'),
              value: qLabel(quality),
              onTap: () => _cinePick<String>(
                context,
                values: qualities,
                labels: [for (final q in qualities) qLabel(q)],
                current: quality,
                onPick: (v) => prefs.set(UserPreferences.defaultDownloadQuality, v),
              ),
            ),
            _CineSettingTile(
              icon: Icons.wifi_rounded,
              title: _t(context, 'Descargar solo con wifi', 'Download on Wi-Fi only'),
              value: _t(context, 'Para no gastar datos', 'Save mobile data'),
              switchValue: prefs.get(UserPreferences.downloadWifiOnly),
              onTap: () => prefs.set(
                UserPreferences.downloadWifiOnly,
                !prefs.get(UserPreferences.downloadWifiOnly),
              ),
            ),
            _CineSettingTile(
              icon: Icons.sd_storage_rounded,
              title: _t(context, 'Espacio máximo', 'Storage limit'),
              value: _cineLabelOf(context, limits, limitLabels, limit),
              onTap: () => _cinePick<int>(
                context,
                values: limits,
                labels: limitLabels,
                current: limit,
                onPick: (v) => prefs.set(UserPreferences.downloadStorageLimitMb, v),
              ),
            ),
            _CineSettingTile(
              icon: Icons.auto_mode_rounded,
              title: _t(context, 'Descargas inteligentes', 'Smart downloads'),
              value: _t(context, 'Mantiene listos los próximos episodios', 'Keeps the next episodes ready'),
              switchValue: prefs.get(UserPreferences.smartDownloadsEnabled),
              onTap: () => prefs.set(
                UserPreferences.smartDownloadsEnabled,
                !prefs.get(UserPreferences.smartDownloadsEnabled),
              ),
            ),
          ]),
          _cineSection(context, _t(context, 'Más', 'More'), [
            _CineSettingTile(
              icon: Icons.folder_open_rounded,
              title: _t(context, 'Espacio ocupado y más opciones', 'Storage used and more'),
              value: _t(context, 'Carpeta, borrado automático, series seguidas…', 'Folder, auto delete, followed series…'),
              onTap: () => _cineOpen(context, const DownloadSettingsScreen()),
            ),
          ]),
        ];
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Protector de pantalla (solo tele)
// ---------------------------------------------------------------------------

class _CineScreensaverPage extends StatelessWidget {
  const _CineScreensaverPage();

  @override
  Widget build(BuildContext context) {
    return _CinePage(
      title: _t(context, 'Protector de pantalla', 'Screensaver'),
      builder: (context, prefs) {
        final enabled = prefs.get(UserPreferences.screensaverEnabled);
        final timeout = prefs.get(UserPreferences.screensaverTimeout);
        final tv = cineIsTv;
        return [
          Padding(
            padding: EdgeInsets.fromLTRB(tv ? 28 : 16, 8, tv ? 28 : 16, 0),
            child: Row(
              children: [
                for (var i = 0; i < CineScreensaver.wallpapers.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.asset(
                          CineScreensaver.wallpapers[i],
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const ColoredBox(color: cineCardBg),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          _cineIntro(
            context,
            _t(
              context,
              'Si no tocas el mando un rato, Taquito toma la pantalla con estos fondos, la hora y el logo. Cualquier tecla lo quita.',
              'If the remote is idle, Taquito takes over with these backgrounds, the time and the logo. Any key dismisses it.',
            ),
          ),
          _cineSection(context, '', [
            _CineSettingTile(
              autofocus: true,
              icon: Icons.pets_rounded,
              title: _t(context, 'Activar protector', 'Enable screensaver'),
              switchValue: enabled,
              onTap: () => prefs.set(UserPreferences.screensaverEnabled, !enabled),
            ),
            if (enabled)
              _CineSettingTile(
                icon: Icons.timer_outlined,
                title: _t(context, 'Aparece a los…', 'Starts after…'),
                value: '${timeout.minutes} min',
                onTap: () => _cinePick<ScreensaverTimeout>(
                  context,
                  values: ScreensaverTimeout.values,
                  labels: [for (final v in ScreensaverTimeout.values) '${v.minutes} min'],
                  current: timeout,
                  onPick: (v) => prefs.set(UserPreferences.screensaverTimeout, v),
                ),
              ),
            _CineSettingTile(
              icon: Icons.slideshow_rounded,
              title: _t(context, 'Verlo ahora', 'Preview now'),
              value: _t(context, 'Pulsa cualquier tecla para volver', 'Press any key to come back'),
              onTap: () {
                GetIt.instance<ScreensaverController>().visible.value = true;
              },
            ),
          ]),
        ];
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Servidor
// ---------------------------------------------------------------------------

class _CineServerPage extends StatelessWidget {
  final bool showAdmin;
  final VoidCallback onClose;
  final VoidCallback openAdmin;

  const _CineServerPage({
    required this.showAdmin,
    required this.onClose,
    required this.openAdmin,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _CinePage(
      title: _t(context, 'Servidor', 'Server'),
      builder: (context, prefs) {
        final id = GetIt.instance<SessionRepository>().activeServerId;
        final server = id == null ? null : GetIt.instance<ServerRepository>().getServer(id);
        return [
          _cineSection(context, _t(context, 'Conectado a', 'Connected to'), [
            _CineSettingTile(
              autofocus: true,
              icon: Icons.dns_rounded,
              title: server?.name ?? _t(context, 'Sin servidor', 'No server'),
              value: server?.address,
              onTap: () {
                final router = GoRouter.of(context);
                onClose();
                router.go(Destinations.serverSelect);
              },
            ),
          ]),
          _cineSection(context, '', [
            _CineSettingTile(
              icon: Icons.swap_horiz_rounded,
              title: _t(context, 'Cambiar de servidor', 'Change server'),
              value: _t(context, 'Añadir otro o elegir uno guardado', 'Add one or pick a saved one'),
              onTap: () {
                final router = GoRouter.of(context);
                onClose();
                router.go(Destinations.serverSelect);
              },
            ),
            if (showAdmin)
              _CineSettingTile(
                icon: Icons.admin_panel_settings_rounded,
                title: l10n.administration,
                value: _t(context, 'Usuarios, bibliotecas y tareas del servidor', 'Users, libraries and server tasks'),
                onTap: openAdmin,
              ),
          ]),
          _cineSection(context, _t(context, 'Conexión', 'Connection'), [
            _CineSettingTile(
              icon: Icons.verified_user_rounded,
              title: _t(context, 'Aceptar certificados propios', 'Allow self-signed certificates'),
              value: _t(context, 'Solo si tu servidor usa uno hecho a mano', 'Only if your server uses a homemade one'),
              switchValue: prefs.get(UserPreferences.allowSelfSignedCerts),
              onTap: () => prefs.set(
                UserPreferences.allowSelfSignedCerts,
                !prefs.get(UserPreferences.allowSelfSignedCerts),
              ),
            ),
          ]),
        ];
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Acerca de y ayuda
// ---------------------------------------------------------------------------

class _CineAboutPage extends StatelessWidget {
  const _CineAboutPage();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final appVersion = AppBeta.label(GetIt.instance<DeviceInfo>().appVersion);
    return _CinePage(
      title: _t(context, 'Acerca de y ayuda', 'About and help'),
      builder: (context, prefs) {
        return [
          const SizedBox(height: 12),
          const Center(child: CineTaquitoLoader(size: 120)),
          const SizedBox(height: 14),
          Center(
            child: Image.asset(
              'assets/images/logo_and_text.png',
              height: 40,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              _t(context, 'Versión $appVersion', 'Version $appVersion'),
              style: const TextStyle(color: cineMuted, fontSize: 15),
            ),
          ),
          _cineSection(context, _t(context, 'Actualizaciones', 'Updates'), [
            if (AppDistribution.supportsInAppUpdates)
              _CineSettingTile(
                autofocus: true,
                icon: Icons.system_update_rounded,
                title: _t(context, 'Buscar actualizaciones', 'Check for updates'),
                value: _t(context, 'La app también avisa sola', 'The app also checks on its own'),
                onTap: () => unawaited(checkAndShowUpdateResult(context)),
              ),
            _CineSettingTile(
              autofocus: !AppDistribution.supportsInAppUpdates,
              icon: Icons.new_releases_rounded,
              title: _t(context, 'Novedades y descargas', "What's new and downloads"),
              value: 'github.com/JMRMINGORANCE/moonfin-TV/releases',
              onTap: () => showQrOrLaunch(
                context,
                url: 'https://github.com/JMRMINGORANCE/moonfin-TV/releases',
                title: _t(context, 'Novedades', "What's new"),
              ),
            ),
          ]),
          _cineSection(context, _t(context, 'Si algo falla', 'If something breaks'), [
            _CineSettingTile(
              icon: Icons.bug_report_rounded,
              title: _t(context, 'Enviar informes de errores', 'Send crash reports'),
              value: _t(context, 'Anónimos, ayudan a arreglar cierres', 'Anonymous, help fix crashes'),
              switchValue: prefs.get(UserPreferences.crashReportsEnabled),
              onTap: () => prefs.set(
                UserPreferences.crashReportsEnabled,
                !prefs.get(UserPreferences.crashReportsEnabled),
              ),
            ),
            _CineSettingTile(
              icon: Icons.receipt_long_rounded,
              title: _t(context, 'Guardar registro detallado', 'Keep a detailed log'),
              value: _t(context, 'Actívalo solo para investigar un problema', 'Turn on only to investigate a problem'),
              switchValue: prefs.get(UserPreferences.diagnosticLoggingEnabled),
              onTap: () => prefs.set(
                UserPreferences.diagnosticLoggingEnabled,
                !prefs.get(UserPreferences.diagnosticLoggingEnabled),
              ),
            ),
            _CineSettingTile(
              icon: Icons.troubleshoot_rounded,
              title: _t(context, 'Diagnóstico', 'Diagnostics'),
              value: _t(context, 'Ver y compartir el registro', 'View and share the log'),
              onTap: () => _cineOpen(context, const DiagnosticsSettingsScreen()),
            ),
          ]),
          _cineSection(context, _t(context, 'Información', 'Information'), [
            _CineSettingTile(
              icon: Icons.code_rounded,
              title: l10n.sourceCode,
              value: 'github.com/JMRMINGORANCE/moonfin-TV',
              onTap: () => showQrOrLaunch(
                context,
                url: 'https://github.com/JMRMINGORANCE/moonfin-TV',
                title: l10n.sourceCode,
              ),
            ),
            _CineSettingTile(
              icon: Icons.description_rounded,
              title: l10n.settingsLicenses,
              value: _t(
                context,
                'Software libre (GPL-2.0), basado en Moonfin y Jellyfin',
                'Free software (GPL-2.0), based on Moonfin and Jellyfin',
              ),
              onTap: () => showQrOrLaunch(
                context,
                url: 'https://github.com/Moonfin-Client/Moonfin-Core/blob/main/LICENSE',
                title: l10n.settingsLicenses,
              ),
            ),
          ]),
        ];
      },
    );
  }
}
