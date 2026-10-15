part of '../settings_side_panel.dart';

// ---------------------------------------------------------------------------
// TaquitoFlix: ajustes rediseñados. Una sola pantalla con tu perfil arriba y
// secciones claras debajo, con el valor actual a la vista y selectores a
// pantalla completa que se manejan igual con el dedo que con el mando.
//
// Solo quedan los ajustes útiles con esta interfaz. Lo estético de Moonfin
// (temas, estilos de ficha, barras, media bar…) ya no existe porque la
// interfaz viene fijada; las opciones técnicas siguen en "Ajustes avanzados".
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

String _t(BuildContext context, String es, String en) =>
    cineText(context, es, en);

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

// ---------------------------------------------------------------------------
// Piezas visuales
// ---------------------------------------------------------------------------

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
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: tv ? 16 : 13,
          ),
          child: Row(
            children: [
              Container(
                width: tv ? 42 : 36,
                height: tv ? 42 : 36,
                decoration: BoxDecoration(
                  color: focused
                      ? Colors.black.withValues(alpha: 0.08)
                      : accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  icon,
                  color: focused ? Colors.black : accent,
                  size: tv ? 24 : 20,
                ),
              ),
              const SizedBox(width: 14),
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
                        maxLines: 1,
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

Widget _cineSection(BuildContext context, String title, List<Widget> tiles) {
  final tv = cineIsTv;
  return Padding(
    padding: EdgeInsets.fromLTRB(tv ? 32 : 16, tv ? 28 : 22, tv ? 32 : 16, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                      indent: 66,
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
    automaticallyImplyLeading: onClose == null,
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

// ---------------------------------------------------------------------------
// Pantalla principal
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
    final prefs = GetIt.instance<UserPreferences>();
    return ListenableBuilder(
      listenable: prefs,
      builder: (context, _) => _build(context, prefs),
    );
  }

  Widget _build(BuildContext context, UserPreferences prefs) {
    final l10n = AppLocalizations.of(context);
    final languages = supportedLanguageOptions;
    String langLabel(String code, {String? empty}) {
      if (code.isEmpty) return empty ?? l10n.none;
      if (code == 'auto') return l10n.autoServerDefault;
      return languages[code] ?? code;
    }

    // -- idioma --
    const appLangs = ['es', 'system', 'en'];
    final appLangLabels = [
      'Español',
      _t(context, 'Idioma del dispositivo', 'Device language'),
      'English',
    ];
    final appLang = prefs.get(UserPreferences.languageOverride);
    final audio = prefs.get(UserPreferences.defaultAudioLanguage);
    final fallback = prefs.get(UserPreferences.fallbackAudioLanguage);
    final subMode = prefs.get(UserPreferences.subtitleMode);
    final subLang = prefs.get(UserPreferences.defaultSubtitleLanguage);
    String subModeLabel(SubtitleMode v) => switch (v) {
          SubtitleMode.flagged => l10n.subtitleModeFlagged,
          SubtitleMode.always => l10n.subtitleModeAlways,
          SubtitleMode.foreign => l10n.subtitleModeForeign,
          SubtitleMode.forced => l10n.subtitleModeForced,
          SubtitleMode.none => _t(context, 'Nunca', 'Never'),
        };
    final audioCodes = ['auto', ...languages.keys];
    final langCodes = ['', ...languages.keys];

    // -- reproducción --
    const bitrates = ['auto', '120', '40', '20', '10', '5', '2'];
    final bitrateLabels = [
      l10n.auto,
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
          MaxVideoResolution.auto => l10n.auto,
          MaxVideoResolution.res480p => '480p',
          MaxVideoResolution.res720p => '720p',
          MaxVideoResolution.res1080p => '1080p',
          MaxVideoResolution.res2160p => '4K',
        };
    const segmentActions = ['askToSkip', 'skip', 'nothing'];
    final segmentLabels = [
      _t(context, 'Mostrar botón para saltar', 'Show a skip button'),
      _t(context, 'Saltar automáticamente', 'Skip automatically'),
      _t(context, 'No hacer nada', 'Do nothing'),
    ];
    String segLabel(String? a) {
      final i = segmentActions.indexOf(a ?? 'askToSkip');
      return segmentLabels[i < 0 ? 0 : i];
    }

    final segments = _cineSegments(prefs);

    // -- servidor --
    final session = GetIt.instance<SessionRepository>();
    final serverId = session.activeServerId;
    final server = serverId == null
        ? null
        : GetIt.instance<ServerRepository>().getServer(serverId);

    return Scaffold(
      backgroundColor: cineBg,
      appBar: _cineSettingsBar(context, l10n.settings, onClose: onClose),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 48),
        children: [
          _CineProfileHeader(onClose: onClose),
          _cineSection(context, _t(context, 'Idioma y subtítulos', 'Language and subtitles'), [
            _CineSettingTile(
              icon: Icons.translate,
              title: _t(context, 'Idioma de la aplicación', 'App language'),
              value: appLangLabels[
                  appLangs.contains(appLang) ? appLangs.indexOf(appLang) : 1],
              onTap: () => _cinePick<String>(
                context,
                values: appLangs,
                labels: appLangLabels,
                current: appLang,
                onPick: (v) => prefs.set(UserPreferences.languageOverride, v),
              ),
            ),
            _CineSettingTile(
              icon: Icons.record_voice_over,
              title: _t(context, 'Idioma del audio', 'Audio language'),
              value: langLabel(audio),
              onTap: () => _cinePick<String>(
                context,
                values: audioCodes,
                labels: [for (final c in audioCodes) langLabel(c)],
                current: audio,
                onPick: (v) =>
                    prefs.set(UserPreferences.defaultAudioLanguage, v),
              ),
            ),
            _CineSettingTile(
              icon: Icons.multitrack_audio,
              title: _t(context, 'Si no hay audio en ese idioma', 'If that audio is missing'),
              value: langLabel(
                fallback,
                empty: _t(context, 'El del título', "The title's own"),
              ),
              onTap: () => _cinePick<String>(
                context,
                values: langCodes,
                labels: [
                  for (final c in langCodes)
                    langLabel(c, empty: _t(context, 'El del título', "The title's own")),
                ],
                current: fallback,
                onPick: (v) =>
                    prefs.set(UserPreferences.fallbackAudioLanguage, v),
              ),
            ),
            _CineSettingTile(
              icon: Icons.subtitles,
              title: _t(context, 'Subtítulos', 'Subtitles'),
              value: subModeLabel(subMode),
              onTap: () => _cinePick<SubtitleMode>(
                context,
                values: SubtitleMode.values,
                labels: [for (final v in SubtitleMode.values) subModeLabel(v)],
                current: subMode,
                onPick: (v) => prefs.set(UserPreferences.subtitleMode, v),
              ),
            ),
            if (subMode != SubtitleMode.none)
              _CineSettingTile(
                icon: Icons.closed_caption,
                title: _t(context, 'Idioma de los subtítulos', 'Subtitle language'),
                value: langLabel(subLang),
                onTap: () => _cinePick<String>(
                  context,
                  values: langCodes,
                  labels: [for (final c in langCodes) langLabel(c)],
                  current: subLang,
                  onPick: (v) =>
                      prefs.set(UserPreferences.defaultSubtitleLanguage, v),
                ),
              ),
            _CineSettingTile(
              icon: Icons.format_size,
              title: _t(context, 'Aspecto de los subtítulos', 'Subtitle style'),
              value: _t(context, 'Tamaño, color y fondo', 'Size, colour and background'),
              onTap: () => context.pushSettingsScreen(
                const SubtitleCustomizationScreen(),
              ),
            ),
          ]),
          _cineSection(context, l10n.playback, [
            _CineSettingTile(
              icon: Icons.network_check,
              title: _t(context, 'Calidad máxima', 'Maximum quality'),
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
              icon: Icons.high_quality,
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
            _CineSettingTile(
              icon: Icons.replay_10_rounded,
              title: _t(context, 'Saltos al retroceder y avanzar', 'Skip back and forward'),
              value: '${prefs.get(UserPreferences.skipForwardLength) ~/ 1000} s',
              onTap: () => _cinePick<int>(
                context,
                values: const [5000, 10000, 15000, 30000],
                labels: const ['5 s', '10 s', '15 s', '30 s'],
                current: prefs.get(UserPreferences.skipForwardLength),
                onPick: (v) async {
                  await prefs.set(UserPreferences.skipBackLength, v);
                  await prefs.set(UserPreferences.skipForwardLength, v);
                },
              ),
            ),
            _CineSettingTile(
              icon: Icons.skip_next,
              title: _t(context, 'Siguiente episodio automático', 'Autoplay next episode'),
              switchValue: prefs.get(UserPreferences.autoplayNextEpisode),
              onTap: () => prefs.set(
                UserPreferences.autoplayNextEpisode,
                !prefs.get(UserPreferences.autoplayNextEpisode),
              ),
            ),
            _CineSettingTile(
              icon: Icons.fast_forward_rounded,
              title: _t(context, 'Intros', 'Intros'),
              value: segLabel(segments['intro']),
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
              value: segLabel(segments['outro']),
              onTap: () => _cinePick<String>(
                context,
                values: segmentActions,
                labels: segmentLabels,
                current: segments['outro'] ?? 'askToSkip',
                onPick: (v) => _cineSetSegment(prefs, 'outro', v),
              ),
            ),
          ]),
          _cineSection(context, _t(context, 'Tu TaquitoFlix', 'Your TaquitoFlix'), [
            _CineSettingTile(
              icon: Icons.view_agenda,
              title: _t(context, 'Filas de la portada', 'Home rows'),
              value: _t(context, 'Elige y ordena lo que ves al entrar', 'Choose and order what you see first'),
              onTap: () =>
                  context.pushSettingsScreen(const HomeRowTogglesScreen()),
            ),
            _CineSettingTile(
              icon: Icons.history_toggle_off_rounded,
              title: _t(context, 'Limpiar Seguir viendo', 'Tidy Continue Watching'),
              value: _t(
                context,
                'Oculta lo que llevas más de 3 meses sin ver',
                'Hides what you have not touched in 3 months',
              ),
              switchValue: prefs.get(cineHideStaleResume),
              onTap: () => prefs.set(
                cineHideStaleResume,
                !prefs.get(cineHideStaleResume),
              ),
            ),
            _CineSettingTile(
              icon: Icons.movie_filter,
              title: _t(context, 'Tráiler automático en la portada', 'Autoplay trailers on Home'),
              switchValue: prefs.get(UserPreferences.mediaBarTrailerPreview),
              onTap: () => prefs.set(
                UserPreferences.mediaBarTrailerPreview,
                !prefs.get(UserPreferences.mediaBarTrailerPreview),
              ),
            ),
            if (!PlatformDetection.isWeb)
              _CineSettingTile(
                icon: Icons.download_for_offline,
                title: l10n.storageAndDownloads,
                value: _t(context, 'Ver sin conexión y espacio ocupado', 'Offline viewing and storage'),
                onTap: () =>
                    context.pushSettingsScreen(const DownloadSettingsScreen()),
              ),
            _CineSettingTile(
              icon: Icons.hub,
              title: 'Seerr',
              value: _t(context, 'Cuenta de Seerr y otras integraciones', 'Seerr account and integrations'),
              onTap: () => context.pushSettingsScreen(const _ServicesScreen()),
            ),
            _CineSettingTile(
              icon: Icons.lock,
              title: _t(context, 'PIN y control parental', 'PIN and parental controls'),
              value: _t(context, 'Bloqueo del perfil e inicio de sesión', 'Profile lock and sign-in'),
              onTap: () => context.pushSettingsScreen(const _AccountScreen()),
            ),
          ]),
          _cineSection(context, _t(context, 'Servidor', 'Server'), [
            if (showAdmin)
              _CineSettingTile(
                icon: Icons.admin_panel_settings,
                title: l10n.administration,
                value: _t(context, 'Usuarios, bibliotecas y servidor', 'Users, libraries and server'),
                onTap: openAdmin,
              ),
            _CineSettingTile(
              icon: Icons.dns_rounded,
              title: _t(context, 'Cambiar de servidor', 'Change server'),
              value: server == null
                  ? null
                  : '${server.name} · ${server.address}',
              onTap: () {
                final router = GoRouter.of(context);
                onClose();
                router.go(Destinations.serverSelect);
              },
            ),
          ]),
          _cineSection(context, _t(context, 'Ayuda', 'Help'), [
            _CineSettingTile(
              icon: Icons.info_outline,
              title: _t(context, 'Acerca de TaquitoFlix', 'About TaquitoFlix'),
              value: AppBeta.label(GetIt.instance<DeviceInfo>().appVersion),
              onTap: () => context.pushSettingsScreen(const _CineAboutScreen()),
            ),
            _CineSettingTile(
              icon: Icons.troubleshoot,
              title: _t(context, 'Diagnóstico', 'Diagnostics'),
              value: _t(context, 'Guardar registros si algo falla', 'Capture logs when something breaks'),
              onTap: () =>
                  context.pushSettingsScreen(const DiagnosticsSettingsScreen()),
            ),
            _CineSettingTile(
              icon: Icons.build,
              title: _t(context, 'Ajustes avanzados', 'Advanced settings'),
              value: _t(context, 'Opciones técnicas para casos concretos', 'Technical options for special cases'),
              onTap: () =>
                  context.pushSettingsScreen(const _CineAdvancedScreen()),
            ),
          ]),
        ],
      ),
    );
  }
}

/// Cabecera con el perfil activo y los accesos a cambiar de perfil o salir.
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
    final avatar = tv ? 84.0 : 68.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(tv ? 32 : 16, 8, tv ? 32 : 16, 0),
      child: Container(
        padding: EdgeInsets.all(tv ? 22 : 16),
        decoration: BoxDecoration(
          color: _kCineCard,
          borderRadius: BorderRadius.circular(12),
        ),
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
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: tv ? 26 : 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (serverName != null)
                        Text(
                          serverName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cineMuted,
                            fontSize: tv ? 16 : 13,
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
    );
  }
}

// ---------------------------------------------------------------------------
// Subpantallas
// ---------------------------------------------------------------------------

class _CineAdvancedScreen extends StatelessWidget {
  const _CineAdvancedScreen();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: cineBg,
      appBar: _cineSettingsBar(
        context,
        _t(context, 'Ajustes avanzados', 'Advanced settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 48),
        children: [
          _cineSection(context, _t(context, 'Opciones técnicas', 'Technical options'), [
            _CineSettingTile(
              autofocus: true,
              icon: Icons.tune,
              title: l10n.general,
              value: l10n.settingsGeneralSubtitle,
              onTap: () => context.pushSettingsScreen(const _GeneralScreen()),
            ),
            _CineSettingTile(
              icon: Icons.play_circle_outline,
              title: _t(context, 'Reproductor y decodificación', 'Player and decoding'),
              value: l10n.settingsPlaybackSubtitle,
              onTap: () =>
                  context.pushSettingsScreen(const _PlaybackCategoryScreen()),
            ),
          ]),
        ],
      ),
    );
  }
}

class _CineAboutScreen extends StatelessWidget {
  const _CineAboutScreen();

  @override
  Widget build(BuildContext context) {
    final appVersion = AppBeta.label(GetIt.instance<DeviceInfo>().appVersion);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: cineBg,
      appBar: _cineSettingsBar(
        context,
        _t(context, 'Acerca de TaquitoFlix', 'About TaquitoFlix'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 48),
        children: [
          const SizedBox(height: 24),
          Center(
            child: Image.asset('assets/images/logo_and_text.png', height: 72),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              l10n.versionValue(appVersion),
              style: const TextStyle(color: cineMuted, fontSize: 15),
            ),
          ),
          if (AppDistribution.supportsInAppUpdates)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: const ColoredBox(
                  color: _kCineCard,
                  child: _CheckForUpdatesTile(),
                ),
              ),
            ),
          _cineSection(context, _t(context, 'Información', 'Information'), [
            _CineSettingTile(
              autofocus: !AppDistribution.supportsInAppUpdates,
              icon: Icons.code,
              title: l10n.sourceCode,
              value: 'github.com/JMRMINGORANCE/moonfin-TV',
              onTap: () => showQrOrLaunch(
                context,
                url: 'https://github.com/JMRMINGORANCE/moonfin-TV',
                title: l10n.sourceCode,
              ),
            ),
            _CineSettingTile(
              icon: Icons.description,
              title: l10n.settingsLicenses,
              value: _t(
                context,
                'Software libre (GPL-2.0), basado en Moonfin y Jellyfin',
                'Free software (GPL-2.0), based on Moonfin and Jellyfin',
              ),
              onTap: () => showQrOrLaunch(
                context,
                url:
                    'https://github.com/Moonfin-Client/Moonfin-Core/blob/main/LICENSE',
                title: l10n.settingsLicenses,
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
