/// Runtime-tunable UI values for AI orb/tray layout.
///
/// This file is intentionally simple so it can be rewritten by tools/ui_tuner.py
/// and hot-reloaded during live UI tuning sessions.
class UiTuningValues {
  // Orb frame/layout
  static double orbSize = 500.0;
  static double orbAlignY = -0.55;
  static double orbScale = 1.0; // Scale via orbSize, not Transform — avoids HtmlElementView overlap

  // Tray layout
  static double trayMessageSpacing = 28.0;

  // Orb HTML/CSS spacing & text
  static double orbContainerGap = 15.0;
  static double micMarginTop = 15.0;
  static double statusMarginTop = 20.0;
  static double statusFontSize = 14.0;
  static double micButtonSize = 85.0;

  // Tray overlay treatment
  static double trayTopInset = 50.0;
  static double trayOverlayOpacityDark = 0.88;
  static double trayOverlayOpacityLight = 0.88;
}
