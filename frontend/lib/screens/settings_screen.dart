import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/voice_agent_settings.dart';
import '../providers/app_settings_provider.dart';
import '../widgets/navigation_drawer.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _serverUrlController = TextEditingController();
  final _tokenController = TextEditingController();
  final _tokenServiceUrlController = TextEditingController();
  final _roomController = TextEditingController();
  final _identityController = TextEditingController();
  final _voiceController = TextEditingController();

  bool _settingsModified = false;

  @override
  void initState() {
    super.initState();
    _serverUrlController.addListener(_onSettingsChanged);
    _tokenController.addListener(_onSettingsChanged);
    _tokenServiceUrlController.addListener(_onSettingsChanged);
    _roomController.addListener(_onSettingsChanged);
    _identityController.addListener(_onSettingsChanged);
    _voiceController.addListener(_onSettingsChanged);
  }

  void _onSettingsChanged() {
    if (!_settingsModified) {
      setState(() => _settingsModified = true);
    }
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _tokenController.dispose();
    _tokenServiceUrlController.dispose();
    _roomController.dispose();
    _identityController.dispose();
    _voiceController.dispose();
    super.dispose();
  }

  void _resetToDefaults() {
    final defaults = VoiceAgentSettings.defaults();
    setState(() {
      _serverUrlController.text = defaults.serverUrl;
      _tokenController.text = defaults.token;
      _tokenServiceUrlController.text = defaults.tokenServiceUrl;
      _roomController.text = defaults.room;
      _identityController.text = defaults.identity;
      _voiceController.text = defaults.voice;
      _settingsModified = true;
    });
  }

  void _saveVoiceAgentSettings() {
    final current = ref.read(appSettingsProvider).valueOrNull;
    if (current == null) return;

    final updatedVoiceAgent = current.voiceAgent.copyWith(
      serverUrl: _serverUrlController.text,
      token: _tokenController.text,
      tokenServiceUrl: _tokenServiceUrlController.text,
      room: _roomController.text,
      identity: _identityController.text,
      voice: _voiceController.text,
    );

    ref.read(appSettingsProvider.notifier).updateVoiceAgent(updatedVoiceAgent);

    setState(() {
      _settingsModified = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(appSettingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF252526) : Colors.white,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: const Text('Settings'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            padding: const EdgeInsets.all(8.0),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            height: 1.0,
            color: isDark ? const Color(0xFF333333) : const Color(0xFFE5E5E5),
          ),
        ),
      ),
      drawer: const VOXNavigationDrawer(currentRoute: '/settings'),
      body: Container(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        child: settingsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Error loading settings: $error')),
          data: (settings) {
            // Populate once (avoid clobbering edits)
            if (!_settingsModified && _serverUrlController.text.isEmpty) {
              _serverUrlController.text = settings.voiceAgent.serverUrl;
              _tokenController.text = settings.voiceAgent.token;
              _tokenServiceUrlController.text = settings.voiceAgent.tokenServiceUrl;
              _roomController.text = settings.voiceAgent.room;
              _identityController.text = settings.voiceAgent.identity;
              _voiceController.text = settings.voiceAgent.voice;
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 800),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF252526) : const Color(0xFFF9F9F9),
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(
                      color: isDark ? const Color(0xFF444444) : const Color(0xFFDDDDDD),
                    ),
                  ),
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SettingsAccordion(
                        title: 'Voice Agent',
                        initiallyExpanded: true,
                        children: [
                          _buildTextField(
                            label: 'Server URL',
                            controller: _serverUrlController,
                            placeholder: 'ws://localhost:7880',
                            hint: 'LiveKit server WebSocket URL',
                          ),
                          _buildTextField(
                            label: 'LiveKit Token',
                            controller: _tokenController,
                            placeholder: 'Paste your LiveKit access token',
                            hint: 'Generated by your local token service or LiveKit dev mode',
                            maxLines: 4,
                          
                          _buildTextField(
                            label: 'Token Service URL',
                            controller: _tokenServiceUrlController,
                            placeholder: 'http://localhost:8787',
                            hint: 'Local service that mints JWTs (recommended)',
                          ),
                          _buildTextField(
                            label: 'Room',
                            controller: _roomController,
                            placeholder: 'vox',
                            hint: 'LiveKit room name',
                          ),
                          _buildTextField(
                            label: 'Identity',
                            controller: _identityController,
                            placeholder: 'phone',
                            hint: 'Identity used to mint the token',
                          ),),
                          _buildTextField(
                            label: 'Voice',
                            controller: _voiceController,
                            placeholder: 'af_heart',
                            hint: 'TTS voice ID (Kokoro)',
                          ),
                          const SizedBox(height: 8.0),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: _resetToDefaults,
                                child: const Text('Reset to Defaults'),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 16.0),

                      _SettingsAccordion(
                        title: 'General UI',
                        initiallyExpanded: false,
                        children: [
                          _buildThemeSelector(),
                        ],
                      ),

                      const SizedBox(height: 32.0),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton(
                            onPressed: _settingsModified ? _saveVoiceAgentSettings : null,
                            child: const Text('Save Changes'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String placeholder = '',
    String? hint,
    int maxLines = 1,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14.4,
            fontWeight: FontWeight.w500,
            color: isDark ? const Color(0xFFE0E0E0) : const Color(0xFF333333),
          ),
        ),
        if (hint != null) ...[
          const SizedBox(height: 4.0),
          Text(
            hint,
            style: TextStyle(
              fontSize: 12.0,
              color: isDark ? const Color(0xFF888888) : const Color(0xFF666666),
            ),
          ),
        ],
        const SizedBox(height: 8.0),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: placeholder,
            filled: true,
            fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6.0),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
          ),
        ),
        const SizedBox(height: 16.0),
      ],
    );
  }

  Widget _buildThemeSelector() {
    final themeMode = ref.watch(appSettingsProvider).valueOrNull?.themeMode ?? ThemeMode.system;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Theme'),
        const SizedBox(height: 8.0),
        DropdownButton<ThemeMode>(
          value: themeMode,
          onChanged: (ThemeMode? newValue) {
            if (newValue != null) {
              ref.read(appSettingsProvider.notifier).updateThemeMode(newValue);
            }
          },
          items: const [
            DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
            DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
            DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
          ],
        ),
      ],
    );
  }
}

class _SettingsAccordion extends StatefulWidget {
  final String title;
  final List<Widget> children;
  final bool initiallyExpanded;

  const _SettingsAccordion({
    required this.title,
    required this.children,
    this.initiallyExpanded = false,
  });

  @override
  State<_SettingsAccordion> createState() => _SettingsAccordionState();
}

class _SettingsAccordionState extends State<_SettingsAccordion> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(
          color: isDark ? const Color(0xFF444444) : const Color(0xFFDDDDDD),
        ),
      ),
      child: ExpansionTile(
        initiallyExpanded: widget.initiallyExpanded,
        title: Text(
          widget.title,
          style: TextStyle(
            fontSize: 16.0,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFFE0E0E0) : const Color(0xFF333333),
          ),
        ),
        trailing: Icon(
          _isExpanded ? Icons.expand_less : Icons.expand_more,
          color: isDark ? const Color(0xFFCCCCCC) : const Color(0xFF666666),
        ),
        onExpansionChanged: (expanded) {
          setState(() {
            _isExpanded = expanded;
          });
        },
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.children,
            ),
          ),
        ],
      ),
    );
  }
}
