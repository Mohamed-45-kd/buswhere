{{flutter_js}}
{{flutter_build_config}}

// Use the CanvasKit bundled with the app (works offline, no CDN round trip),
// and our own sw.js instead of Flutter's deprecated service worker.
_flutter.loader.load({
  config: { canvasKitBaseUrl: 'canvaskit/' },
  onEntrypointLoaded: async function (engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
    const s = document.getElementById('splash');
    if (s) {
      s.style.opacity = '0';
      setTimeout(function () { s.remove(); }, 250);
    }
  },
});
