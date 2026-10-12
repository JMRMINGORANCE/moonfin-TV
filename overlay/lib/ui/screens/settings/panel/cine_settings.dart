part of '../settings_side_panel.dart';

// ---------------------------------------------------------------------------
// TaquitoFlix: menú de ajustes reducido. Solo lo que tiene sentido con esta
// interfaz (idioma, reproducción, portada, descargas, cuenta, Seerr). Todo lo
// estético de Moonfin (temas, estilos de ficha, barras de navegación, media
// bar…) desaparece porque la interfaz ya viene fijada. Las opciones técnicas
// raras siguen disponibles en "Ajustes avanzados".
// ---------------------------------------------------------------------------

List<_PanelEntry> _cineSettingsEntries(
  BuildContext context,
  AppLocalizations l10n, {
  required bool showAdmin,
  required FocusNode? firstFocus,
  required VoidCallback openAdmin,
}) {
  String t(String es, String en) => cineText(context, es, en);
  return [
    if (showAdmin)
      _PanelEntry(
        icon: Icons.admin_panel_settings,
        title: l10n.administration,
        subtitle: t(
          'Usuarios, bibliotecas y servidor',
          'Users, libraries and server',
        ),
        focusNode: firstFocus,
        onTap: openAdmin,
      ),
    _PanelEntry(
      icon: Icons.translate,
      title: t('Idioma y subtítulos', 'Language and subtitles'),
      subtitle: t(
        'Idioma de la app, del audio y de los subtítulos',
        'App, audio and subtitle language',
      ),
      focusNode: showAdmin ? null : firstFocus,
      onTap: () => context.pushSettingsScreen(const _CineLanguageScreen()),
    ),
    _PanelEntry(
      icon: Icons.play_circle,
      title: l10n.playback,
      subtitle: t(
        'Calidad y siguiente episodio',
        'Quality and next episode',
      ),
      onTap: () => context.pushSettingsScreen(const _CinePlaybackScreen()),
    ),
    _PanelEntry(
      icon: Icons.view_agenda,
      title: t('Portada', 'Home screen'),
      subtitle: t(
        'Qué filas aparecen en el inicio',
        'Which rows appear on Home',
      ),
      onTap: () => context.pushSettingsScreen(const HomeRowTogglesScreen()),
    ),
    if (!PlatformDetection.isWeb)
      _PanelEntry(
        icon: Icons.download_for_offline,
        title: l10n.storageAndDownloads,
        subtitle: t(
          'Ver sin conexión y espacio ocupado',
          'Offline viewing and storage',
        ),
        onTap: () => context.pushSettingsScreen(const DownloadSettingsScreen()),
      ),
    _PanelEntry(
      icon: Icons.lock,
      title: t('Cuenta y control parental', 'Account and parental controls'),
      subtitle: t(
        'PIN, modo niños e inicio de sesión',
        'PIN, kids mode and sign-in',
      ),
      onTap: () => context.pushSettingsScreen(const _AccountScreen()),
    ),
    _PanelEntry(
      icon: Icons.hub,
      title: t('Seerr y servicios', 'Seerr and services'),
      subtitle: t(
        'Cuenta de Seerr y otras integraciones',
        'Seerr account and other integrations',
      ),
      onTap: () => context.pushSettingsScreen(const _ServicesScreen()),
    ),
    _PanelEntry(
      icon: Icons.build,
      title: t('Ajustes avanzados', 'Advanced settings'),
      subtitle: t(
        'Opciones técnicas para casos concretos',
        'Technical options for special cases',
      ),
      onTap: () => context.pushSettingsScreen(const _CineAdvancedScreen()),
    ),
    _PanelEntry(
      icon: Icons.info_outline,
      title: t('Acerca de TaquitoFlix', 'About TaquitoFlix'),
      subtitle: AppBeta.label(GetIt.instance<DeviceInfo>().appVersion),
      onTap: () => context.pushSettingsScreen(const _CineAboutScreen()),
    ),
  ];
}

class _CineLanguageScreen extends StatelessWidget {
  const _CineLanguageScreen();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String t(String es, String en) => cineText(context, es, en);
    final languages = supportedLanguageOptions;
    return Scaffold(
      appBar: buildSettingsAppBar(
        context,
        Text(t('Idioma y subtítulos', 'Language and subtitles')),
      ),
      body: ListView(
        children: [
          _SectionHeader(t('Idioma', 'Language')),
          adaptiveListSection(
            children: [
              StringPickerPreferenceTile(
                preference: UserPreferences.languageOverride,
                title: t('Idioma de la aplicación', 'App language'),
                icon: Icons.translate,
                options: {
                  'es': 'Español',
                  'system': t('Idioma del dispositivo', 'Device language'),
                  'en': 'English',
                },
              ),
              StringPickerPreferenceTile(
                preference: UserPreferences.defaultAudioLanguage,
                title: t('Idioma del audio', 'Audio language'),
                description: t(
                  'Se elige esta pista cuando el título la tiene',
                  'This track is picked when the title has it',
                ),
                icon: Icons.record_voice_over,
                options: {'auto': l10n.autoServerDefault, ...languages},
              ),
              StringPickerPreferenceTile(
                preference: UserPreferences.fallbackAudioLanguage,
                title: t('Audio alternativo', 'Fallback audio'),
                description: t(
                  'Si no hay audio en el idioma principal',
                  'When the main language is missing',
                ),
                icon: Icons.multitrack_audio,
                options: {'': l10n.none, ...languages},
              ),
            ],
          ),
          _SectionHeader(t('Subtítulos', 'Subtitles')),
          adaptiveListSection(
            children: [
              EnumPreferenceTile<SubtitleMode>(
                preference: UserPreferences.subtitleMode,
                title: t('Cuándo mostrar subtítulos', 'When to show subtitles'),
                icon: Icons.subtitles,
                labelOf: (v) => switch (v) {
                  SubtitleMode.flagged => l10n.subtitleModeFlagged,
                  SubtitleMode.always => l10n.subtitleModeAlways,
                  SubtitleMode.foreign => l10n.subtitleModeForeign,
                  SubtitleMode.forced => l10n.subtitleModeForced,
                  SubtitleMode.none => l10n.none,
                },
              ),
              StringPickerPreferenceTile(
                preference: UserPreferences.defaultSubtitleLanguage,
                title: t('Idioma de los subtítulos', 'Subtitle language'),
                icon: Icons.closed_caption,
                options: {'': l10n.none, ...languages},
              ),
              _TvSettingsListTile(
                leading: const Icon(Icons.format_size),
                title: Text(t('Aspecto de los subtítulos', 'Subtitle style')),
                subtitle: Text(
                  t('Tamaño, color y fondo', 'Size, colour and background'),
                ),
                onTap: () => context.pushSettingsScreen(
                  const SubtitleCustomizationScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CinePlaybackScreen extends StatelessWidget {
  const _CinePlaybackScreen();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String t(String es, String en) => cineText(context, es, en);
    return Scaffold(
      appBar: buildSettingsAppBar(context, Text(l10n.playback)),
      body: ListView(
        children: [
          _SectionHeader(t('Calidad', 'Quality')),
          adaptiveListSection(
            children: [
              StringPickerPreferenceTile(
                preference: UserPreferences.maxBitrate,
                title: t('Calidad máxima', 'Maximum quality'),
                description: t(
                  'Bájala si el vídeo se corta fuera de casa',
                  'Lower it if video stutters away from home',
                ),
                icon: Icons.network_check,
                options: {
                  'auto': l10n.auto,
                  '120': t('Máxima (120 Mbps)', 'Highest (120 Mbps)'),
                  '40': t('Alta (40 Mbps)', 'High (40 Mbps)'),
                  '20': t('Buena (20 Mbps)', 'Good (20 Mbps)'),
                  '10': t('Media (10 Mbps)', 'Medium (10 Mbps)'),
                  '5': t('Ahorro de datos (5 Mbps)', 'Data saver (5 Mbps)'),
                  '2': t('Mínima (2 Mbps)', 'Lowest (2 Mbps)'),
                },
              ),
              EnumPreferenceTile<MaxVideoResolution>(
                preference: UserPreferences.maxVideoResolution,
                title: t('Resolución máxima', 'Maximum resolution'),
                icon: Icons.high_quality,
                labelOf: (v) => switch (v) {
                  MaxVideoResolution.auto => l10n.auto,
                  MaxVideoResolution.res480p => '480p',
                  MaxVideoResolution.res720p => '720p',
                  MaxVideoResolution.res1080p => '1080p',
                  MaxVideoResolution.res2160p => '4K',
                },
              ),
            ],
          ),
          _SectionHeader(t('Series', 'Series')),
          adaptiveListSection(
            children: [
              SwitchPreferenceTile(
                preference: UserPreferences.autoplayNextEpisode,
                title: t(
                  'Reproducir el siguiente episodio',
                  'Play the next episode',
                ),
                subtitle: t(
                  'Empieza solo al terminar el actual',
                  'Starts on its own when the current one ends',
                ),
                icon: Icons.skip_next,
              ),
            ],
          ),
          _SectionHeader(t('Más', 'More')),
          adaptiveListSection(
            children: [
              _TvSettingsListTile(
                leading: const Icon(Icons.tune),
                title: Text(
                  t('Todas las opciones de reproducción', 'All playback options'),
                ),
                subtitle: Text(
                  t(
                    'Saltar intros, reproductor, audio y decodificación',
                    'Skip intros, player, audio and decoding',
                  ),
                ),
                onTap: () => context.pushSettingsScreen(
                  const _PlaybackCategoryScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CineAdvancedScreen extends StatelessWidget {
  const _CineAdvancedScreen();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String t(String es, String en) => cineText(context, es, en);
    return Scaffold(
      appBar: buildSettingsAppBar(
        context,
        Text(t('Ajustes avanzados', 'Advanced settings')),
      ),
      body: ListView(
        children: [
          adaptiveListSection(
            children: [
              _TvSettingsListTile(
                autofocus: true,
                leading: const Icon(Icons.tune),
                title: Text(l10n.general),
                subtitle: Text(l10n.settingsGeneralSubtitle),
                onTap: () => context.pushSettingsScreen(const _GeneralScreen()),
              ),
              _TvSettingsListTile(
                leading: const Icon(Icons.play_circle_outline),
                title: Text(
                  t('Reproducción completa', 'Full playback settings'),
                ),
                subtitle: Text(l10n.settingsPlaybackSubtitle),
                onTap: () => context.pushSettingsScreen(
                  const _PlaybackCategoryScreen(),
                ),
              ),
              _TvSettingsListTile(
                leading: const Icon(Icons.troubleshoot),
                title: Text(t('Diagnóstico', 'Diagnostics')),
                subtitle: Text(
                  t(
                    'Guardar registros para encontrar errores',
                    'Capture logs to track down problems',
                  ),
                ),
                onTap: () => context.pushSettingsScreen(
                  const DiagnosticsSettingsScreen(),
                ),
              ),
            ],
          ),
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
    String t(String es, String en) => cineText(context, es, en);
    return Scaffold(
      appBar: buildSettingsAppBar(
        context,
        Text(t('Acerca de TaquitoFlix', 'About TaquitoFlix')),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 24),
          Center(
            child: Image.asset('assets/images/logo_and_text.png', height: 72),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              l10n.versionValue(appVersion),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 16),
          adaptiveListSection(
            children: [
              if (AppDistribution.supportsInAppUpdates)
                const _CheckForUpdatesTile(),
              _TvSettingsListTile(
                autofocus: !AppDistribution.supportsInAppUpdates,
                leading: const Icon(Icons.code),
                title: Text(l10n.sourceCode),
                subtitle: const Text('github.com/JMRMINGORANCE/moonfin-TV'),
                onTap: () => showQrOrLaunch(
                  context,
                  url: 'https://github.com/JMRMINGORANCE/moonfin-TV',
                  title: l10n.sourceCode,
                ),
              ),
              _TvSettingsListTile(
                leading: const Icon(Icons.description),
                title: Text(l10n.settingsLicenses),
                subtitle: Text(
                  t(
                    'Software libre (GPL-2.0), basado en Moonfin y Jellyfin',
                    'Free software (GPL-2.0), based on Moonfin and Jellyfin',
                  ),
                ),
                onTap: () => showQrOrLaunch(
                  context,
                  url:
                      'https://github.com/Moonfin-Client/Moonfin-Core/blob/main/LICENSE',
                  title: l10n.settingsLicenses,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
