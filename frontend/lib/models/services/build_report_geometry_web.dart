// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Viewport geometry for the startup client report — lets us see from the
/// backend log whether the page is scrolled / pinch-zoomed on a device.
Map<String, dynamic> readClientGeometry() {
  try {
    final w = html.window;
    final vv = w.visualViewport;
    return <String, dynamic>{
      'innerW': w.innerWidth,
      'innerH': w.innerHeight,
      'dpr': w.devicePixelRatio,
      'scrollX': w.scrollX,
      'scrollY': w.scrollY,
      'vvScale': vv?.scale,
      'vvOX': vv?.offsetLeft,
      'vvOY': vv?.offsetTop,
    };
  } catch (_) {
    return const <String, dynamic>{};
  }
}
