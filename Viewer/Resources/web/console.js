// Viewer: forwards console output, errors and failed resource loads to the app.
(function () {
  const post = (level, args) => {
    try {
      const text = Array.from(args).map(a => {
        if (a instanceof Error) return a.stack || String(a);
        if (typeof a === 'object' && a !== null) {
          try { return JSON.stringify(a, null, 2); } catch (_) { return String(a); }
        }
        return String(a);
      }).join(' ');
      window.webkit.messageHandlers.viewerConsole.postMessage({ level, text });
    } catch (_) {}
  };
  for (const level of ['log', 'info', 'warn', 'error', 'debug']) {
    const original = console[level];
    console[level] = function () { post(level, arguments); return original.apply(console, arguments); };
  }
  window.addEventListener('error', e => {
    const t = e.target;
    if (t && t !== window && (t.src || t.href)) {
      post('error', ['Failed to load ' + (t.tagName || 'resource').toLowerCase() + ': ' + (t.src || t.href)]);
    } else {
      post('error', [(e.message || 'Error') + (e.filename ? ' (' + e.filename.split('/').pop() + ':' + e.lineno + ')' : '')]);
    }
  }, true);
  window.addEventListener('unhandledrejection', e => post('error', ['Unhandled promise rejection: ' + (e.reason && (e.reason.stack || e.reason))]));
})();
