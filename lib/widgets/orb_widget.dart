import 'package:flutter/material.dart';

/// OrbWidget - Visual feedback component for VOX UI
/// Phase 1: Solid circle placeholder (matches web UI visual design)
/// Phase 2: Will integrate with LiveKit for real-time state and animations
class OrbWidget extends StatefulWidget {
  final double size;
  final Color? color;
  final VoidCallback? onTap;

  const OrbWidget({
    super.key,
    this.size = 200.0,
    this.color,
    this.onTap,
  });

  @override
  State<OrbWidget> createState() => _OrbWidgetState();
}

class _OrbWidgetState extends State<OrbWidget> {
  @override
  Widget build(BuildContext context) {
    // Using the primary color from the web UI design
    final orbColor = widget.color ?? const Color(0xFF4A4A4A); // Charcoal gray from web UI

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: orbColor,
          // Subtle shadow for depth (matching web UI visual design)
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8.0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        // TODO(phase-2): Add visual state effects here
        // - Pulsing ring for active states
        // - Particle effects for notifications
        // - Gradient overlays for different statuses
        // - Breathing animation for idle state
      ),
    );
  }
}

/// OrbController interface for future LiveKit integration
/// Currently no-op, but provides the API surface for Phase 2
class OrbController {
  void setState(OrbState state) {
    // TODO(phase-2): Implement state management
    // This will control visual feedback based on LiveKit connection status
  }

  void setAmplitude(double level) {
    // TODO(phase-2): Implement amplitude visualization
    // This will show audio levels and voice activity
  }

  void triggerNotification(String message) {
    // TODO(phase-2): Implement notification effects
    // This will show particle bursts and status messages
  }

  void dispose() {
    // TODO(phase-2): Cleanup resources
  }
}

/// Orb states for future implementation
enum OrbState {
  idle,
  listening,
  processing,
  speaking,
  error,
  disconnected,
}