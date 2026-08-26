{{flutter_js}}
{{flutter_build_config}}

(function () {
  var loadTimedOut = false;
  var appStarted = false;

  function hideLoading() {
    var el = document.getElementById('tv-loading');
    if (el) el.style.display = 'none';
  }

  function showError(message) {
    hideLoading();
    var el = document.getElementById('tv-error');
    if (!el) return;
    el.style.display = 'flex';
    var msg = document.getElementById('tv-error-message');
    if (msg) msg.textContent = message;
  }

  function setLoadingHint(text) {
    var el = document.getElementById('tv-loading-hint');
    if (el) el.textContent = text;
  }

  // Stale service workers / caches often cause a blank screen after deploys.
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.getRegistrations().then(function (regs) {
      for (var i = 0; i < regs.length; i++) {
        regs[i].unregister();
      }
    });
  }
  if (window.caches && caches.keys) {
    caches.keys().then(function (keys) {
      return Promise.all(keys.map(function (k) { return caches.delete(k); }));
    }).catch(function () {});
  }

  var timeoutId = window.setTimeout(function () {
    if (appStarted) return;
    loadTimedOut = true;
    showError(
      'Atlas is taking longer than expected to load. Try a hard refresh (Ctrl+Shift+R / Cmd+Shift+R), ' +
        'another browser (Chrome or Edge), or a stronger network. CanvasKit assets are large on first visit.'
    );
  }, 90000);

  function startApp(engineInitializer) {
    setLoadingHint('Starting Atlas…');
    return engineInitializer.initializeEngine().then(function (appRunner) {
      appStarted = true;
      window.clearTimeout(timeoutId);
      hideLoading();
      return appRunner.runApp();
    });
  }

  setLoadingHint('Downloading app assets…');

  _flutter.loader
    .load({
      onEntrypointLoaded: function (engineInitializer) {
        if (loadTimedOut) return;
        setLoadingHint('Preparing graphics engine…');
        return startApp(engineInitializer).catch(function (error) {
          console.error('Atlas engine init failed', error);
          showError(
            'Unable to start Atlas in this browser. Update your browser, enable hardware ' +
              'acceleration, or try Chrome/Edge. Then hard-refresh the page.'
          );
        });
      },
    })
    .catch(function (error) {
      console.error('Atlas bootstrap failed', error);
      window.clearTimeout(timeoutId);
      showError(
        'Unable to start Atlas in this browser. Update your browser, enable hardware ' +
          'acceleration, or try Chrome/Edge. If the problem persists, hard-refresh the page ' +
          '(Ctrl+Shift+R / Cmd+Shift+R).'
      );
    });
})();
