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
      // En el centro y pequeño: si la página se ve ampliada, el centro es lo
      // único que queda a la vista.
      b.setAttribute('style', 'position:fixed;top:50%;left:50%;width:300px;margin:0;padding:6px;' +
        'transform:translate(-50%,-50%);-webkit-transform:translate(-50%,-50%);' +
        'background:rgba(0,0,0,0.92);color:#7CFC00;font:9px/1.3 monospace;white-space:pre-wrap;' +
        'word-break:break-all;z-index:2147483647;pointer-events:none;border:1px solid #7CFC00');
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
      'DIAG v2  t=' + Math.round((Date.now() - t0) / 1000) + 's\n' +
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
