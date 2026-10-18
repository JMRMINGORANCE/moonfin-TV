// TaquitoFlix - recuadro de diagnóstico para Samsung (solo en el paquete de
// diagnóstico). Muestra arriba a la izquierda lo que el navegador de la tele
// le dice a la app sobre el tamaño de pantalla, y los errores.
(function () {
  var t0 = Date.now();
  var first = null;
  var errs = [];
  window.addEventListener('flutter-first-frame', function () { first = Date.now() - t0; });
  window.addEventListener('error', function (e) {
    errs.push((e.message || (e.target && (e.target.src || e.target.href)) || 'error').toString().slice(0, 160));
  }, true);
  window.addEventListener('unhandledrejection', function (e) {
    var r = e.reason; errs.push(('Promesa: ' + (r && r.message ? r.message : r)).slice(0, 160));
  });
  function box() {
    var b = document.getElementById('taquito-diag');
    if (!b) {
      b = document.createElement('pre');
      b.id = 'taquito-diag';
      b.setAttribute('style', 'position:fixed;top:10px;left:10px;width:900px;margin:0;padding:14px;' +
        'background:rgba(0,0,0,0.85);color:#7CFC00;font:18px/1.35 monospace;white-space:pre-wrap;' +
        'z-index:2147483647;pointer-events:none;border:2px solid #7CFC00');
      (document.body || document.documentElement).appendChild(b);
    }
    return b;
  }
  function el(sel) { try { return document.querySelector(sel); } catch (e) { return null; } }
  function size(n) {
    if (!n) return '-';
    var r = n.getBoundingClientRect();
    return Math.round(r.width) + 'x' + Math.round(r.height) +
      (n.width !== undefined && n.tagName === 'CANVAS' ? ' (buffer ' + n.width + 'x' + n.height + ')' : '');
  }
  function tick() {
    var vv = window.visualViewport;
    var canvases = document.querySelectorAll('canvas');
    var cs = [];
    for (var i = 0; i < canvases.length && i < 3; i++) cs.push(size(canvases[i]));
    box().textContent =
      'DIAGNOSTICO TaquitoFlix  t=' + Math.round((Date.now() - t0) / 1000) + 's\n' +
      'primer frame: ' + (first === null ? 'NO' : first + ' ms') + '\n' +
      'innerWidth x innerHeight: ' + window.innerWidth + 'x' + window.innerHeight + '\n' +
      'outer: ' + window.outerWidth + 'x' + window.outerHeight + '  screen: ' + screen.width + 'x' + screen.height + '\n' +
      'devicePixelRatio: ' + window.devicePixelRatio + '\n' +
      'visualViewport: ' + (vv ? Math.round(vv.width) + 'x' + Math.round(vv.height) + ' scale ' + vv.scale : 'no existe') + '\n' +
      'html: ' + size(document.documentElement) + '  body: ' + size(document.body) + '\n' +
      'flutter-view: ' + size(el('flutter-view')) + '  glass-pane: ' + size(el('flt-glass-pane')) + '\n' +
      'canvas: ' + (cs.length ? cs.join(' | ') : 'ninguno') + '\n' +
      'ResizeObserver: ' + (typeof ResizeObserver) + '  WebGL2: ' + (function () {
        try { return !!document.createElement('canvas').getContext('webgl2'); } catch (e) { return 'error'; }
      })() + '\n' +
      'navegador: ' + navigator.userAgent.slice(0, 140) + '\n' +
      (errs.length ? 'errores:\n' + errs.slice(-6).join('\n') : 'errores: ninguno');
  }
  setInterval(tick, 1000);
  setTimeout(tick, 200);
})();
