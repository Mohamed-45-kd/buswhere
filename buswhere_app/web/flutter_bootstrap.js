{{flutter_js}}
{{flutter_build_config}}

// Use the CanvasKit bundled with the app (works offline, no CDN round trip),
// and our own sw.js instead of Flutter's deprecated service worker.
_flutter.loader.load({
  config: { canvasKitBaseUrl: 'canvaskit/' },
  onEntrypointLoaded: async function (engineInitializer) {
    // Run inside #app instead of taking over the page, so Flutter leaves our viewport tag alone.
    const appRunner = await engineInitializer.initializeEngine({ hostElement: document.getElementById('app') });
    await appRunner.runApp();
    // Keep the splash up until the first frame is drawn at the right size.
    await new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r)));
    const s = document.getElementById('splash');
    if (s) {
      s.style.opacity = '0';
      setTimeout(function () { s.remove(); }, 250);
    }
  },
});
