import 'package:flutter/material.dart';
import '../widgets/orb_webview_widget.dart';
import '../controllers/livekit_orb_controller.dart';

class OrbTestScreen extends StatefulWidget {
  @override
  _OrbTestScreenState createState() => _OrbTestScreenState();
}

class _OrbTestScreenState extends State<OrbTestScreen> {
  late LiveKitOrbController _orbController;
  bool _isDarkMode = true;
  
  @override
  void initState() {
    super.initState();
    _orbController = LiveKitOrbController();
  }
  
  @override
  void dispose() {
    _orbController.dispose();
    super.dispose();
  }
  
  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
    _orbController.updateTheme(_isDarkMode ? 'dark' : 'light');
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: _isDarkMode ? Color(0xFF1A1A1A) : Color(0xFFF5F5F5),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Orb widget with test controls
            Expanded(
              child: OrbWebViewWidget(controller: _orbController),
            ),
            
            // Theme toggle button at bottom
            Padding(
              padding: EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: _toggleTheme,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  backgroundColor: _isDarkMode
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.1),
                  foregroundColor: _isDarkMode ? Colors.white : Colors.black,
                  elevation: 2,
                ),
                icon: Icon(
                  _isDarkMode ? Icons.light_mode : Icons.dark_mode,
                  size: 20,
                ),
                label: Text(
                  _isDarkMode ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}