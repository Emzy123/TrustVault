{{flutter_js}}
{{flutter_build_config}}

(function () {
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

  // Stale service workers often cause a blank screen after deploys on one device only.
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.getRegistrations().then(function (regs) {
      for (var i = 0; i < regs.length; i++) {
        regs[i].unregister();
      }
    });
  }

  window.setTimeout(function () {
    if (document.getElementById('tv-loading')?.style.display !== 'none') {
      showError(
        'TrustVault is taking longer than expected to load. Try a hard refresh (Ctrl+Shift+R), ' +
          'another browser (Chrome or Edge), or disable ad blockers for this site.'
      );
    }
  }, 45000);

  // Prefer local CanvasKit assets (built with --no-web-resources-cdn) so devices
  // that block Google CDNs can still start. Fall back to HTML renderer if CanvasKit fails.
  _flutter.loader
    .load({
      onEntrypointLoaded: function (engineInitializer) {
        return engineInitializer.initializeEngine().then(function (appRunner) {
          hideLoading();
          return appRunner.runApp();
        });
      },
    })
    .catch(function (error) {
      console.error('TrustVault bootstrap failed', error);
      showError(
        'Unable to start TrustVault in this browser. Update your browser, enable hardware ' +
          'acceleration, or try Chrome/Edge. If the problem persists, hard-refresh the page ' +
          '(Ctrl+Shift+R / Cmd+Shift+R).'
      );
    });
})();
