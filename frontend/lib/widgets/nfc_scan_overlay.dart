import 'package:flutter/material.dart';

/// Android half-screen NFC scanning overlay
/// Shows a branded scanning UI with cancel button
class NFCScanOverlay extends StatefulWidget {
  final VoidCallback onCancel;

  const NFCScanOverlay({
    super.key,
    required this.onCancel,
  });

  @override
  State<NFCScanOverlay> createState() => _NFCScanOverlayState();
}

class _NFCScanOverlayState extends State<NFCScanOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // Create pulsing animation for NFC icon
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 0.9,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Material(
      color: Colors.black54, // Semi-transparent dark background
      child: Stack(
        children: [
          // Tap to cancel (anywhere outside the main content)
          Positioned.fill(
            child: GestureDetector(
              onTap: widget.onCancel,
              child: Container(color: Colors.transparent),
            ),
          ),
          
          // Main scanning content (bottom half)
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.5,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated NFC Icon
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.nfc,
                            size: 80,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Title
                  Text(
                    'Ready to Scan',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Instructions
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: Text(
                      'Hold NFC chip near the back of your phone',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 48),
                  
                  // Cancel Button
                  ElevatedButton(
                    onPressed: widget.onCancel,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.surface,
                      foregroundColor: theme.colorScheme.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 48,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
