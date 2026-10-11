// Moonfin Cine - adaptador del mando de Samsung (Tizen) para Flutter web.
// Registra las teclas multimedia y traduce los keyCodes propios de Tizen
// (Atrás = 10009, Play/Pausa = 10252, ...) a eventos de teclado estándar.
(function () {
  try {
    if (window.tizen && tizen.tvinputdevice) {
      ['MediaPlayPause', 'MediaPlay', 'MediaPause', 'MediaStop',
       'MediaFastForward', 'MediaRewind', 'MediaTrackNext',
       'MediaTrackPrevious', 'ColorF0Red', 'ColorF1Green',
       'ColorF2Yellow', 'ColorF3Blue', 'Info'
      ].forEach(function (k) { try { tizen.tvinputdevice.registerKey(k); } catch (e) {} });
    }
  } catch (e) {}

  var map = {
    10009: ['Escape', 'Escape', 27],
    10252: ['MediaPlayPause', 'MediaPlayPause', 179],
    415:   ['MediaPlay', 'MediaPlay', 250],
    19:    ['MediaPause', 'MediaPause', 19],
    413:   ['MediaStop', 'MediaStop', 178],
    417:   ['MediaFastForward', 'MediaFastForward', 228],
    412:   ['MediaRewind', 'MediaRewind', 227],
    10233: ['MediaTrackNext', 'MediaTrackNext', 176],
    10232: ['MediaTrackPrevious', 'MediaTrackPrevious', 177]
  };

  function forward(type, src) {
    var m = map[src.keyCode];
    if (!m || src.__mfn) return false;
    var ev = new KeyboardEvent(type, {
      key: m[0], code: m[1], keyCode: m[2], which: m[2],
      bubbles: true, cancelable: true, repeat: src.repeat
    });
    try {
      Object.defineProperty(ev, 'keyCode', { get: function () { return m[2]; } });
      Object.defineProperty(ev, 'which', { get: function () { return m[2]; } });
    } catch (e) {}
    ev.__mfn = true;
    (document.activeElement || document.body).dispatchEvent(ev);
    return true;
  }

  ['keydown', 'keyup'].forEach(function (type) {
    window.addEventListener(type, function (e) {
      if (e.__mfn || !map[e.keyCode]) return;
      e.preventDefault();
      e.stopImmediatePropagation();
      forward(type, e);
    }, true);
  });
})();
