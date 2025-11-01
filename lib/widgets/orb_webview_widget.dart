// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/livekit_orb_controller.dart';

class OrbWebViewWidget extends StatefulWidget {
  final LiveKitOrbController controller;

  const OrbWebViewWidget({super.key, required this.controller});

  @override
  State<OrbWebViewWidget> createState() => _OrbWebViewWidgetState();
}

class _OrbWebViewWidgetState extends State<OrbWebViewWidget> {
  late html.IFrameElement _iframeElement;
  late String _viewType;
  bool _isLoading = true;
  bool _isRegistered = false;
  late VoidCallback _stateUpdateCallback;
  
  // Widget's internal state cache - this is the source of truth for the iframe
  String _currentState = 'idle';
  double _currentLevel = 0.0;
  String _currentTheme = 'light';
  String _currentStatus = 'Ready to assist...';

  @override
  void initState() {
    super.initState();
    
    // Generate unique view type for this iframe
    _viewType = 'orb-iframe-${DateTime.now().millisecondsSinceEpoch}';
    
    // Set up state update listener - merge controller updates with our cache
    _stateUpdateCallback = () {
      final data = widget.controller.currentData;
      _updateOrbFromController(
        state: data.state,
        level: data.level,
        theme: data.theme,
        status: data.status,
      );
    };
    widget.controller.addListener(_stateUpdateCallback);
    
    // Create iframe element immediately (synchronously)
    _iframeElement = html.IFrameElement()
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%';
    
    // Register the view factory synchronously
    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _iframeElement,
    );
    
    _isRegistered = true;
    
    // Load content asynchronously
    _loadIFrameContent();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_stateUpdateCallback);
    super.dispose();
  }

  void _loadIFrameContent() async {
    try {
      // Load HTML content from assets
      final htmlContent = await rootBundle.loadString('assets/orb/orb.html');
      
      // Set iframe content using srcdoc
      _iframeElement.srcdoc = htmlContent;
      
      // Wait for iframe to load
      _iframeElement.onLoad.listen((_) {
        setState(() {
          _isLoading = false;
        });
        
        // Send initial state after a short delay
        Future.delayed(const Duration(milliseconds: 500), () {
          _sendOrbUpdate();
        });
      });
      
    } catch (e) {
      print('Error loading iframe content: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Update internal cache from controller and send to iframe
  void _updateOrbFromController({
    String? state,
    double? level,
    String? theme,
    String? status,
  }) {
    // Merge with current cache (only update what's provided)
    if (state != null) _currentState = state;
    if (level != null) _currentLevel = level;
    if (theme != null) _currentTheme = theme;
    if (status != null) _currentStatus = status;
    
    // Send complete state to iframe
    _sendOrbUpdate();
  }
  
  // Update audio level only (doesn't come from controller)
  void _updateAudioLevel(double level) {
    _currentLevel = level;
    _sendOrbUpdate();
  }
  
  // Update state only (for manual state buttons)
  void _updateState(String state) {
    _currentState = state;
    _currentStatus = _getStatusForState(state);
    _sendOrbUpdate();
  }
  
  // The ONLY method that sends to iframe - always sends complete cached state
  void _sendOrbUpdate() {
    if (_isLoading) return;
    
    try {
      final message = {
        'type': 'livekit-update',
        'payload': {
          'state': _currentState,
          'level': _currentLevel,
          'theme': _currentTheme,
          'status': _currentStatus,
        }
      };
      
      _iframeElement.contentWindow?.postMessage(message, '*');
    } catch (e) {
      print('Error sending orb update: $e');
    }
  }

  void _triggerManualState(String state) {
    // Update our cache and send
    _updateState(state);
  }

  String _getStatusForState(String state) {
    switch (state) {
      case 'idle':
        return 'Ready to assist...';
      case 'executing':
        return 'Executing tool...';
      case 'processing':
        return 'Processing request';
      case 'speaking':
        return 'Responding...';
      case 'muted':
        return 'Microphone muted';
      case 'notifying':
        return 'Notification received';
      case 'disconnected':
        return 'Disconnected';
      default:
        return 'Ready to assist...';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTestControls(),
        Expanded(
          child: Stack(
            children: [
              // IFrame view
              HtmlElementView(
                viewType: _viewType,
              ),
              
              // Loading overlay
              if (_isLoading)
                Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Loading Orb...',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTestControls() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Test Orb States (Original 6)',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _buildTestButton('Idle', 'idle', Icons.play_circle_outline, theme),
              _buildTestButton('Executing', 'executing', Icons.build, theme),
              _buildTestButton('Processing', 'processing', Icons.autorenew, theme),
              _buildTestButton('Muted', 'muted', Icons.mic_off, theme),
              _buildTestButton('Notify', 'notifying', Icons.notifications_active, theme),
              _buildTestButton('Disconnected', 'disconnected', Icons.link_off, theme),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Audio Level Simulation',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _buildAudioLevelSlider(theme),
        ],
      ),
    );
  }

  Widget _buildTestButton(String label, String state, IconData icon, ThemeData theme) {
    return Tooltip(
      message: 'Trigger $label state',
      child: ElevatedButton.icon(
        onPressed: () => _triggerManualState(state),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
          foregroundColor: theme.colorScheme.primary,
          elevation: 1,
          side: BorderSide(
            color: theme.colorScheme.primary.withOpacity(0.3),
            width: 1,
          ),
        ),
        icon: Icon(icon, size: 16),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildAudioLevelSlider(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Audio Level: ${(_currentLevel * 100).toInt()}%',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              _currentLevel == 0.0 ? 'Silent' :
              _currentLevel < 0.3 ? 'Low' :
              _currentLevel < 0.7 ? 'Medium' : 'High',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        Slider(
          value: _currentLevel,
          onChanged: (double value) {
            // Don't update audio level if orb is in muted or disconnected state
            if (_currentState == 'muted' || _currentState == 'disconnected') {
              return; // Ignore audio changes in muted/disconnected states
            }
            
            setState(() {
              _updateAudioLevel(value);
            });
          },
          activeColor: theme.colorScheme.primary,
          inactiveColor: theme.colorScheme.primary.withOpacity(0.3),
          min: 0.0,
          max: 1.0,
          divisions: 20, // Creates smooth steps
          label: '${(_currentLevel * 100).toInt()}%',
        ),
        Container(
          height: 4,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Stack(
            children: [
              Container(
                width: MediaQuery.of(context).size.width * _currentLevel,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildQuickLevelButton('Silent', 0.0, Icons.volume_off, theme),
            _buildQuickLevelButton('Low', 0.3, Icons.volume_down, theme),
            _buildQuickLevelButton('Med', 0.6, Icons.volume_up, theme),
            _buildQuickLevelButton('High', 1.0, Icons.hearing, theme),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickLevelButton(String label, double level, IconData icon, ThemeData theme) {
    final isActive = (_currentLevel - level).abs() < 0.1;
    
    return Tooltip(
      message: 'Set audio level to $label',
      child: ElevatedButton.icon(
        onPressed: () {
          // Don't update audio level if orb is in muted or disconnected state
          if (_currentState == 'muted' || _currentState == 'disconnected') {
            return; // Ignore audio changes in muted/disconnected states
          }
          
          setState(() {
            _updateAudioLevel(level);
          });
        },
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: isActive
            ? theme.colorScheme.primary
            : theme.colorScheme.primary.withOpacity(0.1),
          foregroundColor: isActive
            ? Colors.white
            : theme.colorScheme.primary,
          elevation: isActive ? 2 : 1,
          side: BorderSide(
            color: theme.colorScheme.primary.withOpacity(0.3),
            width: 1,
          ),
        ),
        icon: Icon(icon, size: 14),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}