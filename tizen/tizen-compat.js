// TaquitoFlix - compatibilidad del navegador de los televisores Samsung (Tizen).
//
// 1. La app se abre desde los archivos del propio paquete (file://) y el
//    navegador de la tele no deja usar fetch() con ellos. Flutter carga así
//    sus recursos (imágenes, fuentes, motor gráfico...), de modo que se
//    quedaba en la pantalla de carga. Aquí fetch() de archivos locales se
//    resuelve con XMLHttpRequest, que sí puede leerlos.
// 2. Si la app no llega a pintarse en 25 segundos, se muestra en pantalla qué
//    ha fallado, para poder corregirlo con una simple foto de la tele.
(function () {
  var errors = [];
  var panel = null;
  var started = false;

  function note(msg) {
    try {
      errors.push(String(msg).slice(0, 400));
      if (errors.length > 14) errors.shift();
      if (panel) render();
    } catch (e) {}
  }

  window.addEventListener('error', function (e) {
    var t = e && e.target;
    if (t && t !== window && (t.src || t.href)) {
      note('No se pudo cargar: ' + (t.src || t.href));
      return;
    }
    note((e && e.message ? e.message : 'Error') +
      (e && e.filename ? ' @ ' + e.filename.split('/').pop() + ':' + e.lineno : ''));
  }, true);

  window.addEventListener('unhandledrejection', function (e) {
    var r = e && e.reason;
    note('Promesa: ' + (r && (r.message || r.stack) ? (r.message || r.stack) : r));
  });

  var origError = console.error;
  console.error = function () {
    try {
      note('console.error: ' + Array.prototype.slice.call(arguments).join(' '));
    } catch (e) {}
    if (origError) return origError.apply(console, arguments);
  };

  // --- fetch() para archivos del paquete --------------------------------
  var types = {
    wasm: 'application/wasm', js: 'text/javascript', mjs: 'text/javascript',
    json: 'application/json', svg: 'image/svg+xml', png: 'image/png',
    jpg: 'image/jpeg', jpeg: 'image/jpeg', webp: 'image/webp', gif: 'image/gif',
    otf: 'font/otf', ttf: 'font/ttf', woff: 'font/woff', woff2: 'font/woff2',
    css: 'text/css', html: 'text/html', txt: 'text/plain'
  };

  if (location.protocol === 'file:' && window.fetch && window.Response) {
    var originalFetch = window.fetch.bind(window);
    window.fetch = function (input, init) {
      var url = typeof input === 'string' ? input : (input && input.url) || String(input);
      var abs;
      try { abs = new URL(url, document.baseURI).href; } catch (e) { abs = url; }
      if (abs.indexOf('file:') !== 0) return originalFetch(input, init);
      return new Promise(function (resolve, reject) {
        var xhr = new XMLHttpRequest();
        try {
          xhr.open('GET', abs, true);
          xhr.responseType = 'arraybuffer';
        } catch (e) {
          reject(e);
          return;
        }
        xhr.onload = function () {
          var body = xhr.response;
          var ok = body && body.byteLength > 0;
          var status = xhr.status && xhr.status !== 0 ? xhr.status : (ok ? 200 : 404);
          var ext = (abs.split('?')[0].split('#')[0].split('.').pop() || '').toLowerCase();
          resolve(new Response(ok ? body : null, {
            status: status,
            statusText: status === 200 ? 'OK' : 'Not Found',
            headers: { 'Content-Type': types[ext] || 'application/octet-stream' }
          }));
        };
        // Un archivo que no existe da error en file://; fetch() lo trata
        // como un 404 normal.
        xhr.onerror = function () {
          resolve(new Response(null, { status: 404, statusText: 'Not Found' }));
        };
        xhr.send();
      });
    };
    // El motor de Flutter usa instantiateStreaming si existe; con estas
    // respuestas fabricadas es más fiable compilar desde los bytes.
    if (window.WebAssembly && WebAssembly.instantiateStreaming) {
      var originalStreaming = WebAssembly.instantiateStreaming.bind(WebAssembly);
      WebAssembly.instantiateStreaming = function (source, imports) {
        return Promise.resolve(source).then(function (resp) {
          if (resp && resp.url && resp.url.indexOf('http') === 0) {
            return originalStreaming(resp, imports);
          }
          return resp.arrayBuffer().then(function (buf) {
            return WebAssembly.instantiate(buf, imports);
          });
        });
      };
    }
  }

  // --- aviso si la app no arranca --------------------------------------
  window.addEventListener('flutter-first-frame', function () {
    started = true;
    if (panel && panel.parentNode) panel.parentNode.removeChild(panel);
    panel = null;
  });

  function render() {
    if (!panel) return;
    panel.textContent =
      'TaquitoFlix no ha terminado de arrancar.\n' +
      'Haz una foto de esta pantalla y pásasela a quien te ayuda.\n\n' +
      'Protocolo: ' + location.protocol + '\n' +
      'Navegador: ' + navigator.userAgent + '\n\n' +
      (errors.length ? errors.join('\n') : 'Sin errores registrados (sigue cargando).');
  }

  setTimeout(function () {
    if (started) return;
    panel = document.createElement('pre');
    panel.setAttribute('style',
      'position:fixed;top:0;left:0;right:0;bottom:0;margin:0;padding:40px;' +
      'background:rgba(0,0,0,0.88);color:#fff;font:20px/1.4 sans-serif;' +
      'white-space:pre-wrap;word-break:break-all;z-index:2147483647;overflow:hidden');
    render();
    (document.body || document.documentElement).appendChild(panel);
  }, 25000);
})();
