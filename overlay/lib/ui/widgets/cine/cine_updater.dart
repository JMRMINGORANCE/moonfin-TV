// TaquitoFlix: actualizaciones dentro de la app en Android y Android TV.
//
// Busca la última Release del repositorio, descarga el APK que toca (móvil o
// tele) y se lo pasa al instalador del sistema. Android siempre pide permiso
// para instalar apps de fuera de la tienda; una vez dado, cada actualización
// se instala con un solo clic en "Instalar" (y sin preguntar en Android 12 o
// superior cuando la versión anterior la instaló la propia app).
//
// En Samsung (Tizen) una app no puede actualizarse a sí misma: allí solo se
// avisa de que hay versión nueva.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:path_provider/path_provider.dart';

import '../../../data/services/app_update_service.dart';
import '../../../preference/user_preferences.dart';
import '../../../util/app_distribution.dart';
import '../../navigation/app_router.dart';
import 'cine_widgets.dart';

const _channel = MethodChannel('taquitoflix/updater');

/// Instalar sola cada versión nueva al abrir la app (Ajustes → Acerca de).
final cineAutoInstallUpdates = Preference<bool>(
  key: 'taquitoflix_auto_install_updates',
  defaultValue: true,
);

/// Si esta copia puede descargar e instalar su propia actualización.
bool get cineCanSelfUpdate {
  if (kIsWeb || !Platform.isAndroid) return false;
  final channel = AppDistribution.channel;
  return channel == DistributionChannel.apk ||
      channel == DistributionChannel.androidTvApk;
}

bool _installing = false;

/// "Buscar actualizaciones" de Ajustes: si hay versión nueva, la instala.
Future<void> cineCheckAndInstall(BuildContext context) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  void say(String es, String en) => messenger?.showSnackBar(
        SnackBar(
          content: Text(cineText(context, es, en)),
          duration: const Duration(seconds: 4),
        ),
      );

  say('Buscando actualizaciones…', 'Checking for updates…');
  final result =
      await GetIt.instance<AppUpdateService>().checkForUpdateNowDetailed();
  if (!context.mounted) return;
  messenger?.hideCurrentSnackBar();
  final update = result.update;
  if (update == null) {
    switch (result.status) {
      case DesktopUpdateCheckStatus.upToDate:
        say('Ya tienes la última versión.', 'You have the latest version.');
      case DesktopUpdateCheckStatus.checkFailed:
        say(
          'No se pudo comprobar. Revisa la conexión e inténtalo de nuevo.',
          'Could not check. Check your connection and try again.',
        );
      default:
        say(
          'Esta versión no puede actualizarse sola.',
          'This version cannot update itself.',
        );
    }
    return;
  }
  if (!cineCanSelfUpdate) {
    say(
      'Hay una versión nueva (${update.version}).',
      'A new version is available (${update.version}).',
    );
    return;
  }
  await cineInstallUpdate(context, update);
}

/// Al abrir la app: si está activado, instala sola la versión nueva.
/// Devuelve true si se encarga de ella (y no hace falta mostrar el aviso).
bool cineMaybeAutoInstall(DesktopUpdateInfo update) {
  if (!kCineUi || !cineCanSelfUpdate) return false;
  if (!GetIt.instance<UserPreferences>().get(cineAutoInstallUpdates)) {
    return false;
  }
  final ctx = appRouter.routerDelegate.navigatorKey.currentContext;
  if (ctx == null || !ctx.mounted) return false;
  unawaited(cineInstallUpdate(ctx, update, automatic: true));
  return true;
}

/// Descarga el APK de [update] mostrando el progreso y abre el instalador.
Future<void> cineInstallUpdate(
  BuildContext context,
  DesktopUpdateInfo update, {
  bool automatic = false,
}) async {
  if (_installing || !cineCanSelfUpdate) return;
  if (!update.downloadUri.path.toLowerCase().endsWith('.apk')) return;
  _installing = true;
  final progress = ValueNotifier<double?>(null);
  final message = ValueNotifier<String>(
    cineText(
      context,
      automatic
          ? 'Hay una versión nueva (${update.version}). Descargándola…'
          : 'Descargando la versión ${update.version}…',
      automatic
          ? 'A new version (${update.version}) is available. Downloading…'
          : 'Downloading version ${update.version}…',
    ),
  );
  final failed = ValueNotifier<bool>(false);
  var cancelled = false;
  final navigator = Navigator.of(context, rootNavigator: true);

  final dialog = showGeneralDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    barrierLabel: 'cine_update',
    barrierColor: const Color(0xD9000000),
    pageBuilder: (dialogContext, _, _) => _CineUpdateDialog(
      version: update.version,
      progress: progress,
      message: message,
      failed: failed,
      onCancel: () {
        cancelled = true;
        Navigator.of(dialogContext).pop();
      },
    ),
  );
  var dialogOpen = true;
  unawaited(dialog.whenComplete(() => dialogOpen = false));

  void close() {
    if (dialogOpen && navigator.mounted) navigator.pop();
  }

  void fail(String es, String en) {
    if (!context.mounted) return;
    message.value = cineText(context, es, en);
    failed.value = true;
  }

  try {
    final file = await _download(update.downloadUri, progress, () => cancelled);
    if (cancelled) return;
    if (file == null) {
      fail(
        'No se pudo descargar la actualización. Inténtalo más tarde.',
        'The update could not be downloaded. Try again later.',
      );
      return;
    }
    final allowed = await _channel.invokeMethod<bool>('canInstall') ?? false;
    if (!allowed) {
      fail(
        'Para actualizarse, TaquitoFlix necesita permiso para instalar apps. '
            'Actívalo en la pantalla que se abre y vuelve a "Buscar actualizaciones".',
        'TaquitoFlix needs permission to install apps. Allow it on the next '
            'screen, then check for updates again.',
      );
      await _channel.invokeMethod<bool>('openInstallPermission');
      return;
    }
    if (context.mounted) {
      message.value = cineText(
        context,
        'Instalando… Si la tele lo pide, pulsa "Instalar".',
        'Installing… If asked, press "Install".',
      );
    }
    progress.value = null;
    final ok = await _channel.invokeMethod<bool>('install', {'path': file.path});
    if (ok != true) {
      fail(
        'El sistema no dejó instalar la actualización.',
        'The system did not allow the update to be installed.',
      );
      return;
    }
    // El instalador del sistema toma el relevo; al terminar, la app se
    // reinicia con la versión nueva.
    await Future<void>.delayed(const Duration(seconds: 2));
    close();
  } catch (e) {
    debugPrint('TaquitoFlix update failed: $e');
    fail(
      'Algo falló al actualizar. Inténtalo más tarde.',
      'Something went wrong while updating. Try again later.',
    );
  } finally {
    _installing = false;
  }
}

Future<File?> _download(
  Uri uri,
  ValueNotifier<double?> progress,
  bool Function() cancelled,
) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}${Platform.pathSeparator}taquitoflix_update.apk');
  if (await file.exists()) await file.delete();
  final client = HttpClient()
    ..userAgent = 'TaquitoFlixUpdater/1.0'
    ..connectionTimeout = const Duration(seconds: 20);
  try {
    final request = await client.getUrl(uri);
    request.followRedirects = true;
    request.maxRedirects = 8;
    final response = await request.close();
    if (response.statusCode != 200) {
      await response.drain<void>();
      return null;
    }
    final total = response.contentLength;
    var received = 0;
    final sink = file.openWrite();
    try {
      await for (final chunk in response) {
        if (cancelled()) break;
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) progress.value = received / total;
      }
    } finally {
      await sink.flush();
      await sink.close();
    }
    if (cancelled()) return null;
    if (total > 0 && received != total) return null;
    // Un APK es un zip: empieza por "PK".
    final head = await file.openRead(0, 2).first;
    if (head.length < 2 || head[0] != 0x50 || head[1] != 0x4B) return null;
    return file;
  } catch (e) {
    debugPrint('TaquitoFlix update download failed: $e');
    return null;
  } finally {
    client.close(force: true);
  }
}

class _CineUpdateDialog extends StatelessWidget {
  final String version;
  final ValueNotifier<double?> progress;
  final ValueNotifier<String> message;
  final ValueNotifier<bool> failed;
  final VoidCallback onCancel;

  const _CineUpdateDialog({
    required this.version,
    required this.progress,
    required this.message,
    required this.failed,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final tv = cineIsTv;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onCancel();
      },
      child: Material(
        type: MaterialType.transparency,
        child: Center(
          child: Container(
            width: tv ? 560 : 340,
            padding: EdgeInsets.all(tv ? 32 : 22),
            decoration: BoxDecoration(
              color: const Color(0xFF161616),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.system_update_rounded,
                      color: cineRed,
                      size: tv ? 34 : 26,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        cineText(
                          context,
                          'Actualizar TaquitoFlix',
                          'Update TaquitoFlix',
                        ),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: tv ? 26 : 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ValueListenableBuilder<String>(
                  valueListenable: message,
                  builder: (context, text, _) => Text(
                    text,
                    style: TextStyle(
                      color: const Color(0xFFDDDDDD),
                      fontSize: tv ? 18 : 15,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                ValueListenableBuilder<bool>(
                  valueListenable: failed,
                  builder: (context, isFailed, _) => isFailed
                      ? const SizedBox.shrink()
                      : ValueListenableBuilder<double?>(
                          valueListenable: progress,
                          builder: (context, value, _) => ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: value,
                              minHeight: 6,
                              backgroundColor: const Color(0xFF333333),
                              valueColor:
                                  const AlwaysStoppedAnimation<Color>(cineRed),
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 22),
                Align(
                  alignment: Alignment.centerRight,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: failed,
                    builder: (context, isFailed, _) => CineButton(
                      autofocus: true,
                      label: isFailed
                          ? cineText(context, 'Cerrar', 'Close')
                          : cineText(context, 'Cancelar', 'Cancel'),
                      primary: isFailed,
                      onTap: onCancel,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
