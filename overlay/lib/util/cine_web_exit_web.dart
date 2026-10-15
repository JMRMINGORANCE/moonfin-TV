import 'dart:js_interop';

// Lo define tizen/tizen-keys.js dentro del paquete de Samsung.
@JS('taquitoExit')
external JSBoolean? _taquitoExit();

/// Cierra la app en un televisor Samsung. En un navegador normal la función
/// no existe y devuelve false.
bool cineWebExit() {
  try {
    return _taquitoExit()?.toDart ?? false;
  } catch (_) {
    return false;
  }
}
