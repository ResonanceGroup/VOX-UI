import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/app_preferences.dart';
import '../models/app_preferences_notifier.dart';
import '../models/agent_profile.dart';
import '../models/services/config_api_service.dart';
import '../models/services/preferences_service.dart';
import '../Controllers/ai_controller.dart';
import '../Views/main_view.dart';
import 'theme_manager.dart';

/// Settings View with per-agent profile support.
/// Profile dropdown at top selects LLM/STT/TTS settings.
/// Connection settings are global (shared across profiles).
class SettingsView extends StatelessWidget {
  final VoidCallback? onSaved;
  const SettingsView({super.key, this.onSaved});

  @override
  Widget build(BuildContext context) {
    return _SettingsBody(onSaved: onSaved);
  }
}

class _SettingsBody extends StatefulWidget {
  final VoidCallback? onSaved;
  const _SettingsBody({this.onSaved});

  @override
  State<_SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends State<_SettingsBody> {
  // ── Profile state ────────────────────────────────────────────────────────
  late List<AgentProfile> _profiles;
  String? _activeId;
  late AgentProfile _editing;

  // ── Text controllers ──────────────────────────────────────────────────────
  late final TextEditingController _backendBaseUrlCtrl;
  late final TextEditingController _livekitUrlCtrl;
  late final TextEditingController _tokenServiceUrlCtrl;

  late final TextEditingController _llmUrlCtrl;
  late final TextEditingController _llmModelCtrl;
  late final TextEditingController _llmApiKeyCtrl;

  late final TextEditingController _sttUrlCtrl;
  late final TextEditingController _sttModelCtrl;

  late final TextEditingController _ttsUrlCtrl;
  late final TextEditingController _ttsModelCtrl;
  late final TextEditingController _previewTextCtrl;

  // -- Agent behavior controllers
  late final TextEditingController _llmReadTimeoutCtrl;
  late final TextEditingController _llmMaxRetriesCtrl;
  late final TextEditingController _maxContextItemsCtrl;
  bool _preemptiveGeneration = false;
  bool _discardWhileGenerating = true;

  // ── Voice dropdown ─────────────────────────────────────────────────────
  List<TtsVoice> _voices = [];
  bool _loadingVoices = false;
  String _selectedVoice = 'af_heart';
  double _ttsSpeed = 1.0;

  // ── Preview ─────────────────────────────────────────────────────────────
  bool _previewLoading = false;
  final _audioPlayer = AudioPlayer();

  // ── LLM/STT test ─────────────────────────────────────────────────────────
  bool _llmTesting = false;
  String? _llmTestResult;
  bool _sttTesting = false;
  String? _sttTestResult;

  // ── Save state ──────────────────────────────────────────────────────────
  bool _saving = false;
  String? _saveStatus;

  // ── Services ────────────────────────────────────────────────────────────
  late ConfigApiService _configApi;

  @override
  void initState() {
    super.initState();
    final prefs = context.read<PreferencesService>();
    final notifier = context.read<AppPreferencesNotifier>();

    _profiles = List.from(notifier.agentProfiles);
    _activeId = notifier.activeProfileId;
    final active = notifier.activeProfile ?? (_profiles.isNotEmpty ? _profiles.first : null);

    if (active != null) {
      _editing = active;
      _activeId = active.id;
    } else {
      _editing = AgentProfile(id: const Uuid().v4(), name: 'Default');
      _activeId = _editing.id;
    }

    _backendBaseUrlCtrl  = TextEditingController(text: prefs.backendBaseUrl);
    _livekitUrlCtrl     = TextEditingController(text: prefs.livekitUrl);
    _tokenServiceUrlCtrl = TextEditingController(text: prefs.tokenServiceUrl);

    _llmUrlCtrl   = TextEditingController(text: _editing.llmBaseUrl);
    _llmModelCtrl = TextEditingController(text: _editing.llmModelName);
    _llmApiKeyCtrl = TextEditingController(text: _editing.llmApiKey);

    _sttUrlCtrl   = TextEditingController(text: _editing.sttUrl);
    _sttModelCtrl = TextEditingController(text: _editing.sttModel);

    _ttsUrlCtrl   = TextEditingController(text: _editing.ttsUrl);
    _ttsModelCtrl = TextEditingController(text: _editing.ttsModel);
    _previewTextCtrl = TextEditingController(text: 'Hello! This is a voice preview from VoxUI.');

    _llmReadTimeoutCtrl = TextEditingController(text: _editing.llmReadTimeout.toString());
    _llmMaxRetriesCtrl = TextEditingController(text: _editing.llmMaxRetries.toString());
    _maxContextItemsCtrl = TextEditingController(text: _editing.maxContextItems.toString());
    _preemptiveGeneration = _editing.preemptiveGeneration;
    _discardWhileGenerating = _editing.discardWhileGenerating;

    _selectedVoice = _editing.ttsVoice.isEmpty ? 'af_heart' : _editing.ttsVoice;
    _ttsSpeed = _editing.ttsSpeed;

    _configApi = ConfigApiService(tokenServiceUrl: () => _tokenServiceUrlCtrl.text.trim());

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final notifier = context.read<AppPreferencesNotifier>();
      await notifier.syncFromBackend();
      if (mounted) {
        final updated = notifier.agentProfiles;
        final activeId = notifier.activeProfileId ?? (updated.isNotEmpty ? updated.first.id : null);
        final active = updated.firstWhere((p) => p.id == activeId, orElse: () => updated.isNotEmpty ? updated.first : _editing);
        setState(() {
          _profiles = List.from(updated);
          _activeId = activeId;
          _editing = active;
          _llmUrlCtrl.text    = active.llmBaseUrl;
          _llmModelCtrl.text  = active.llmModelName;
          _llmApiKeyCtrl.text = active.llmApiKey;
          _sttUrlCtrl.text    = active.sttUrl;
          _sttModelCtrl.text  = active.sttModel;
          _ttsUrlCtrl.text    = active.ttsUrl;
          _ttsModelCtrl.text  = active.ttsModel;
          _selectedVoice = active.ttsVoice.isEmpty ? 'af_heart' : active.ttsVoice;
          _ttsSpeed      = active.ttsSpeed;
          _llmReadTimeoutCtrl.text = active.llmReadTimeout.toString();
          _llmMaxRetriesCtrl.text = active.llmMaxRetries.toString();
          _maxContextItemsCtrl.text = active.maxContextItems.toString();
          _preemptiveGeneration = active.preemptiveGeneration;
          _discardWhileGenerating = active.discardWhileGenerating;
        });
      }
      _loadVoices();
    });
  }

  @override
  void dispose() {
    _backendBaseUrlCtrl.dispose();
    _livekitUrlCtrl.dispose();
    _tokenServiceUrlCtrl.dispose();
    _llmUrlCtrl.dispose();
    _llmModelCtrl.dispose();
    _llmApiKeyCtrl.dispose();
    _sttUrlCtrl.dispose();
    _sttModelCtrl.dispose();
    _ttsUrlCtrl.dispose();
    _ttsModelCtrl.dispose();
    _previewTextCtrl.dispose();
    _llmReadTimeoutCtrl.dispose();
    _llmMaxRetriesCtrl.dispose();
    _maxContextItemsCtrl.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // ── Profile switch ───────────────────────────────────────────────────────

  void _switchToProfile(String? id) {
    if (id == null) return;
    final profile = _profiles.firstWhere((p) => p.id == id, orElse: () => _editing);
    setState(() {
      _activeId = id;
      _editing = profile;
      _llmUrlCtrl.text = profile.llmBaseUrl;
      _llmModelCtrl.text = profile.llmModelName;
      _llmApiKeyCtrl.text = profile.llmApiKey;
      _sttUrlCtrl.text = profile.sttUrl;
      _sttModelCtrl.text = profile.sttModel;
      _ttsUrlCtrl.text = profile.ttsUrl;
      _ttsModelCtrl.text = profile.ttsModel;
      _selectedVoice = profile.ttsVoice.isEmpty ? 'af_heart' : profile.ttsVoice;
      _ttsSpeed = profile.ttsSpeed;
      _llmReadTimeoutCtrl.text = profile.llmReadTimeout.toString();
      _llmMaxRetriesCtrl.text = profile.llmMaxRetries.toString();
      _maxContextItemsCtrl.text = profile.maxContextItems.toString();
      _preemptiveGeneration = profile.preemptiveGeneration;
      _discardWhileGenerating = profile.discardWhileGenerating;
      _llmTestResult = null;
      _sttTestResult = null;
    });
  }

  void _addProfile() {
    final newProfile = AgentProfile(
      id: const Uuid().v4(),
      name: 'Profile ${_profiles.length + 1}',
    );
    setState(() {
      _profiles = [..._profiles, newProfile];
      _activeId = newProfile.id;
      _editing = newProfile;
      _llmUrlCtrl.clear();
      _llmModelCtrl.clear();
      _llmApiKeyCtrl.clear();
      _sttUrlCtrl.clear();
      _sttModelCtrl.clear();
      _ttsUrlCtrl.clear();
      _ttsModelCtrl.text = 'tts-1';
      _selectedVoice = 'af_heart';
      _ttsSpeed = 1.0;
    });
  }

  void _deleteCurrentProfile() {
    if (_profiles.length <= 1) return;
    setState(() {
      _profiles = _profiles.where((p) => p.id != _activeId).toList();
      _activeId = _profiles.first.id;
      _switchToProfile(_activeId);
    });
  }

  void _renameCurrentProfile() {
    final ctrl = TextEditingController(text: _editing.name);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Rename Profile'),
      content: TextField(controller: ctrl, autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () {
          final name = ctrl.text.trim();
          if (name.isEmpty) return;
          setState(() {
            _editing = _editing.copyWith(name: name);
            _profiles = [for (final p in _profiles) if (p.id == _editing.id) _editing else p];
          });
          Navigator.pop(ctx);
        }, child: const Text('Rename')),
      ],
    ));
  }

  // ── Load voices ──────────────────────────────────────────────────────────

  Future<void> _loadVoices() async {
    setState(() => _loadingVoices = true);
    final ttsUrl = _ttsUrlCtrl.text.trim();
    final voices = await _configApi.fetchVoices(ttsUrl: ttsUrl.isNotEmpty ? ttsUrl : null);
    if (!mounted) return;
    setState(() {
      _voices = voices;
      _loadingVoices = false;
      if (_selectedVoice.isNotEmpty && !voices.any((v) => v.id == _selectedVoice) && voices.isNotEmpty) {
        _selectedVoice = voices.first.id;
      }
    });
  }

  // ── Save ─────────────────────────────────────────────────────────────────

  Future<void> _saveSettings() async {
    final prefs = context.read<PreferencesService>();
    final notifier = context.read<AppPreferencesNotifier>();

    // Build updated profile
    final updated = _editing.copyWith(
      llmBaseUrl: _llmUrlCtrl.text.trim(),
      llmModelName: _llmModelCtrl.text.trim(),
      llmApiKey: _llmApiKeyCtrl.text.trim(),
      sttUrl: _sttUrlCtrl.text.trim(),
      sttModel: _sttModelCtrl.text.trim(),
      ttsUrl: _ttsUrlCtrl.text.trim(),
      ttsModel: _ttsModelCtrl.text.trim(),
      ttsVoice: _selectedVoice,
      ttsSpeed: _ttsSpeed,
      llmReadTimeout: int.tryParse(_llmReadTimeoutCtrl.text.trim()) ?? 120,
      llmMaxRetries: int.tryParse(_llmMaxRetriesCtrl.text.trim()) ?? 3,
      maxContextItems: int.tryParse(_maxContextItemsCtrl.text.trim()) ?? 10,
      preemptiveGeneration: _preemptiveGeneration,
      discardWhileGenerating: _discardWhileGenerating,
    );

    _profiles = [for (final p in _profiles) if (p.id == updated.id) updated else p];
    _editing = updated;

    // Save global
    prefs.backendBaseUrl = _backendBaseUrlCtrl.text.trim();
    prefs.livekitUrl = _livekitUrlCtrl.text.trim();
    prefs.tokenServiceUrl = _tokenServiceUrlCtrl.text.trim();

    // Save profiles to notifier
    await notifier.setActiveProfileId(_activeId);
    for (final p in _profiles) {
      await notifier.updateAgentProfile(p);
    }

    setState(() { _saving = true; _saveStatus = null; });

    // Push to backend
    final ok = await _configApi.updateConfig({
      'stt_url': updated.sttUrl,
      'stt_model': updated.sttModel,
      'tts_url': updated.ttsUrl,
      'tts_voice': updated.ttsVoice,
      'tts_speed': updated.ttsSpeed,
      'tts_model': updated.ttsModel,
      'llm_base_url': updated.llmBaseUrl,
      'llm_model': updated.llmModelName,
      'llm_api_key': updated.llmApiKey,
      'llm_read_timeout': updated.llmReadTimeout,
      'llm_max_retries': updated.llmMaxRetries,
      'max_context_items': updated.maxContextItems,
      'preemptive_generation': updated.preemptiveGeneration,
      'discard_while_generating': updated.discardWhileGenerating,
    });

    if (!mounted) return;
    setState(() { _saving = false; _saveStatus = ok ? 'ok' : 'error'; });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Settings saved and synced to backend.' : 'Saved locally. Backend unreachable.'),
      backgroundColor: ok ? Colors.green.shade700 : Colors.orange.shade700,
      duration: const Duration(seconds: 3),
    ));

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _saveStatus = null);
    });

    // Also persist full profile list to backend
    if (ok) {
      final profileMaps = _profiles.map((p) => p.toJson()).toList();
      await _configApi.saveProfiles(profileMaps, activeProfileId: _activeId);
    }

    if (ok) {
      // Always reconnect on profile switch — the agent's linked_participant
      // is bound to the old session, so a fresh connection ensures the new
      // lk.agent.events stream is delivered to this client.
      final controller = context.read<AIController>();
      await controller.disconnect();
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) controller.connect();
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) widget.onSaved?.call();
      });
    }
  }

  // ── TTS preview ───────────────────────────────────────────────────────────

  Future<void> _playPreview() async {
    final text = _previewTextCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _previewLoading = true);
    final ttsUrl = _ttsUrlCtrl.text.trim();
    final ttsModel = _ttsModelCtrl.text.trim();
    final bytes = await _configApi.previewTts(
      text: text, voice: _selectedVoice, speed: _ttsSpeed,
      ttsUrl: ttsUrl.isNotEmpty ? ttsUrl : null,
      ttsModel: ttsModel.isNotEmpty ? ttsModel : null,
    );
    if (!mounted) return;
    setState(() => _previewLoading = false);

    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Preview failed — check TTS URL and backend status.'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    await _audioPlayer.stop();
    await _audioPlayer.play(BytesSource(bytes));
  }

  // ── LLM test ──────────────────────────────────────────────────────────────

  Future<void> _testLlm() async {
    setState(() { _llmTesting = true; _llmTestResult = null; });
    try {
      final uri = Uri.parse('${_tokenServiceUrlCtrl.text.trim()}/test-llm');
      final resp = await http.get(uri).timeout(const Duration(seconds: 25));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        if (data['ok'] == true) {
          final reply = (data['reply'] as String?) ?? '';
          setState(() => _llmTestResult = 'OK: ${reply.isEmpty ? "connection OK" : reply}');
        } else {
          final err = data['error'] as String? ?? 'unknown error';
          setState(() => _llmTestResult = 'ERR: ${err.length > 60 ? err.substring(0, 60) : err}');
        }
      } else {
        setState(() => _llmTestResult = 'ERR: HTTP ${resp.statusCode}');
      }
    } catch (e) {
      setState(() => _llmTestResult = 'ERR: ${e.toString().split('\n').first.substring(0, 60)}');
    } finally {
      setState(() => _llmTesting = false);
    }
  }

  // ── STT test ──────────────────────────────────────────────────────────────

  Future<void> _testStt() async {
    setState(() { _sttTesting = true; _sttTestResult = null; });
    try {
      final uri = Uri.parse('${_tokenServiceUrlCtrl.text.trim()}/test-stt');
      final resp = await http.get(uri).timeout(const Duration(seconds: 12));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        if (data['ok'] == true) {
          final models = (data['models'] as List?)?.join(', ') ?? 'OK';
          setState(() => _sttTestResult = 'OK: $models');
        } else {
          final err = data['error'] as String? ?? 'unknown error';
          setState(() => _sttTestResult = 'ERR: ${err.length > 60 ? err.substring(0, 60) : err}');
        }
      } else {
        setState(() => _sttTestResult = 'ERR: HTTP ${resp.statusCode}');
      }
    } catch (e) {
      setState(() => _sttTestResult = 'ERR: ${e.toString().split('\n').first.substring(0, 60)}');
    } finally {
      setState(() => _sttTesting = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppPreferencesNotifier>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scale = settings.uiScale;

    return Container(
      color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF9F9F9),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16 * scale, 16 * scale, 16 * scale, 24 * scale),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildProfileDropdown(isDark, scale),
            SizedBox(height: 24 * scale),
            _buildLlmSection(isDark, scale),
            SizedBox(height: 24 * scale),
            _buildSttSection(isDark, scale),
            SizedBox(height: 24 * scale),
            _buildTtsSection(isDark, scale),
            SizedBox(height: 24 * scale),
            _buildAgentBehaviorSection(isDark, scale),
            SizedBox(height: 24 * scale),
            _buildConnectionSection(isDark, scale),
            SizedBox(height: 24 * scale),
            _buildThemeSection(settings, isDark, scale),
            SizedBox(height: 24 * scale),
            _buildUIScalingSection(settings, isDark, scale),
            SizedBox(height: 24 * scale),
            _buildResetButton(context, settings, scale),
            SizedBox(height: 16 * scale),
            _buildSaveButton(scale),
            SizedBox(height: 24 * scale),
            Text(
              'Build $kVoxUiBuildId',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12 * scale,
                color: isDark ? Colors.white.withOpacity(0.45) : Colors.black.withOpacity(0.45),
              ),
            ),
            SizedBox(height: 32 * scale),
          ],
        ),
      ),
    );
  }

  // ── Profile Dropdown ─────────────────────────────────────────────────────

  Widget _buildProfileDropdown(bool isDark, double scale) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8 * scale),
        side: BorderSide(color: AppColors.primaryBlue, width: 2),
      ),
      child: Padding(
        padding: EdgeInsets.all(16 * scale),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_tree_outlined, size: 22 * scale, color: AppColors.primaryBlue),
                SizedBox(width: 10 * scale),
                Text('Active Profile', style: TextStyle(
                  fontSize: 16 * scale, fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                )),
                const Spacer(),
                IconButton(icon: Icon(Icons.add, size: 22 * scale), tooltip: 'Add profile',
                    onPressed: _addProfile),
                if (_profiles.length > 1)
                  IconButton(icon: Icon(Icons.delete_outline, size: 22 * scale), tooltip: 'Delete profile',
                      onPressed: _deleteCurrentProfile),
                IconButton(icon: Icon(Icons.edit_outlined, size: 22 * scale), tooltip: 'Rename profile',
                    onPressed: _renameCurrentProfile),
              ],
            ),
            SizedBox(height: 12 * scale),
            DropdownButtonFormField<String>(
              value: _activeId,
              items: _profiles.map((p) => DropdownMenuItem(
                value: p.id,
                child: Text(p.name, style: TextStyle(fontSize: 15 * scale)),
              )).toList(),
              onChanged: _switchToProfile,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8 * scale)),
                contentPadding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 12 * scale),
              ),
            ),
          ],
        ),
      ),
    );
  }


  // ── Agent Behavior ──────────────────────────────────────────────────────

  Widget _buildAgentBehaviorSection(bool isDark, double scale) {
    return _Section(title: 'Agent Behavior', icon: Icons.tune_outlined,
        scale: scale, isDark: isDark,
        child: Padding(
          padding: EdgeInsets.all(16 * scale),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _field(label: 'Read Timeout (seconds)', ctrl: _llmReadTimeoutCtrl, scale: scale, isDark: isDark,
                  hint: '120', helperText: 'How long to wait for LLM response'),
              SizedBox(height: 16 * scale),
              _field(label: 'Max Retries', ctrl: _llmMaxRetriesCtrl, scale: scale, isDark: isDark,
                  hint: '3', helperText: 'Retry count on connection failure'),
              SizedBox(height: 16 * scale),
              _field(label: 'Max Context Items', ctrl: _maxContextItemsCtrl, scale: scale, isDark: isDark,
                  hint: '10', helperText: '1 = slim mode (for agents with own memory)'),
              SizedBox(height: 16 * scale),
              SwitchListTile(
                title: Text('Preemptive Generation', style: TextStyle(fontSize: 15 * scale, fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black87)),
                subtitle: Text('Allow interrupting the agent mid-processing',
                    style: TextStyle(fontSize: 13 * scale,
                        color: isDark ? Colors.white54 : Colors.black54)),
                value: _preemptiveGeneration,
                onChanged: (v) => setState(() => _preemptiveGeneration = v),
                activeColor: AppColors.primaryBlue,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              SwitchListTile(
                title: Text('Discard While Generating', style: TextStyle(fontSize: 15 * scale, fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black87)),
                subtitle: Text('Drop new voice input while agent is responding - prevents echo',
                    style: TextStyle(fontSize: 13 * scale,
                        color: isDark ? Colors.white54 : Colors.black54)),
                value: _discardWhileGenerating,
                onChanged: (v) => setState(() => _discardWhileGenerating = v),
                activeColor: AppColors.primaryBlue,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ],
          ),
        ));
  }
  // ── Connection (Global) ─────────────────────────────────────────────────

  Widget _buildConnectionSection(bool isDark, double scale) {
    return _Section(title: 'Connection', icon: Icons.cloud_outlined,
        scale: scale, isDark: isDark, initiallyExpanded: true,
        child: Padding(
          padding: EdgeInsets.all(16 * scale),
          child: Column(children: [
            _field(label: 'Backend Base URL', ctrl: _backendBaseUrlCtrl, scale: scale, isDark: isDark,
                hint: 'https://rg-w00-chat.resonancegroupusa.com'),
            SizedBox(height: 16 * scale),
            _field(label: 'LiveKit Server URL', ctrl: _livekitUrlCtrl, scale: scale, isDark: isDark),
            SizedBox(height: 16 * scale),
            _field(label: 'Token Service URL', ctrl: _tokenServiceUrlCtrl, scale: scale, isDark: isDark,
                hint: 'http://localhost:7882'),
          ]),
        ));
  }

  // ── LLM ─────────────────────────────────────────────────────────────────

  Widget _buildLlmSection(bool isDark, double scale) {
    return _Section(title: 'LLM', icon: Icons.psychology_outlined,
        scale: scale, isDark: isDark,
        child: Padding(
          padding: EdgeInsets.all(16 * scale),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _field(label: 'LLM Base URL', ctrl: _llmUrlCtrl, scale: scale, isDark: isDark,
                  hint: 'http://localhost:8642/v1'),
              SizedBox(height: 16 * scale),
              _field(label: 'Model Name', ctrl: _llmModelCtrl, scale: scale, isDark: isDark,
                  hint: 'Qwen3.6-35B-A3B-AWQ'),
              SizedBox(height: 16 * scale),
              _field(label: 'API Key', ctrl: _llmApiKeyCtrl, scale: scale, isDark: isDark,
                  hint: 'Leave blank if not required', obscure: true),
              SizedBox(height: 16 * scale),
              _testRow(label: 'Test LLM', icon: Icons.send_outlined,
                  loading: _llmTesting, result: _llmTestResult, onTap: _testLlm, scale: scale, isDark: isDark),
            ],
          ),
        ));
  }

  // ── STT ─────────────────────────────────────────────────────────────────

  Widget _buildSttSection(bool isDark, double scale) {
    return _Section(title: 'STT (Speech-to-Text)', icon: Icons.mic_outlined,
        scale: scale, isDark: isDark,
        child: Padding(
          padding: EdgeInsets.all(16 * scale),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _field(label: 'STT Base URL', ctrl: _sttUrlCtrl, scale: scale, isDark: isDark,
                  hint: 'http://10.0.0.128:8090'),
              SizedBox(height: 16 * scale),
              _field(label: 'STT Model', ctrl: _sttModelCtrl, scale: scale, isDark: isDark,
                  hint: 'Systran/faster-distil-whisper-medium.en'),
              SizedBox(height: 16 * scale),
              _testRow(label: 'Test STT', icon: Icons.hearing_outlined,
                  loading: _sttTesting, result: _sttTestResult, onTap: _testStt, scale: scale, isDark: isDark),
            ],
          ),
        ));
  }

  // ── TTS ─────────────────────────────────────────────────────────────────

  Widget _buildTtsSection(bool isDark, double scale) {
    return _Section(title: 'TTS (Text-to-Speech)', icon: Icons.volume_up_outlined,
        scale: scale, isDark: isDark,
        child: Padding(
          padding: EdgeInsets.all(16 * scale),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _field(label: 'TTS Base URL', ctrl: _ttsUrlCtrl, scale: scale, isDark: isDark,
                  hint: 'http://10.0.0.128:8880',
                  suffix: IconButton(
                    icon: _loadingVoices
                        ? SizedBox(width: 18 * scale, height: 18 * scale,
                            child: const CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.refresh),
                    tooltip: 'Reload voice list',
                    onPressed: _loadingVoices ? null : _loadVoices,
                  )),
              SizedBox(height: 16 * scale),
              _field(label: 'TTS Model', ctrl: _ttsModelCtrl, scale: scale, isDark: isDark,
                  hint: 'tts-1'),
              SizedBox(height: 16 * scale),
              Text('Voice', style: TextStyle(fontSize: 14 * scale, fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : Colors.black87)),
              SizedBox(height: 8 * scale),
              _loadingVoices
                  ? const LinearProgressIndicator()
                  : DropdownButtonFormField<String>(
                      value: _voices.any((v) => v.id == _selectedVoice) ? _selectedVoice
                          : (_voices.isNotEmpty ? _voices.first.id : null),
                      items: _voices.map((v) => DropdownMenuItem(
                        value: v.id,
                        child: Text('${v.name}  (${v.id})', style: TextStyle(fontSize: 14 * scale)),
                      )).toList(),
                      onChanged: (v) => setState(() => _selectedVoice = v ?? 'af_heart'),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8 * scale)),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 12 * scale),
                      ),
                    ),
              SizedBox(height: 20 * scale),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Speed', style: TextStyle(fontSize: 14 * scale, fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : Colors.black87)),
                  Text('${_ttsSpeed.toStringAsFixed(1)}x', style: TextStyle(
                    fontSize: 14 * scale, fontWeight: FontWeight.w600, color: AppColors.primaryBlue)),
                ],
              ),
              Slider(value: _ttsSpeed, min: 0.5, max: 2.0, divisions: 15,
                  label: '${_ttsSpeed.toStringAsFixed(1)}x',
                  activeColor: AppColors.primaryBlue,
                  onChanged: (v) => setState(() => _ttsSpeed = v)),
              Divider(height: 24 * scale, color: isDark ? const Color(0xFF444444) : const Color(0xFFCCCCCC)),
              Text('Voice Preview', style: TextStyle(fontSize: 14 * scale, fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black87)),
              SizedBox(height: 10 * scale),
              TextField(controller: _previewTextCtrl, maxLines: 3,
                  style: TextStyle(fontSize: 15 * scale),
                  decoration: InputDecoration(
                    hintText: 'Type something to preview...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8 * scale)),
                    contentPadding: EdgeInsets.all(12 * scale),
                  )),
              SizedBox(height: 12 * scale),
              ElevatedButton.icon(
                onPressed: _previewLoading ? null : _playPreview,
                icon: _previewLoading
                    ? SizedBox(width: 18 * scale, height: 18 * scale,
                        child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(Icons.volume_up, size: 20 * scale),
                label: Text(_previewLoading ? 'Synthesising...' : 'Play Preview',
                    style: TextStyle(fontSize: 16 * scale, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14 * scale),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10 * scale)),
                ),
              ),
            ],
          ),
        ));
  }

  // ── Theme ───────────────────────────────────────────────────────────────

  Widget _buildThemeSection(AppPreferencesNotifier settings, bool isDark, double scale) {
    return _Section(title: 'Theme', icon: Icons.brightness_6_outlined,
        scale: scale, isDark: isDark,
        child: Column(children: [
          _themeRadio('Dark', ThemeMode.dark, settings, scale),
          Divider(height: 1 * scale),
          _themeRadio('Light', ThemeMode.light, settings, scale),
          Divider(height: 1 * scale),
          _themeRadio('System', ThemeMode.system, settings, scale),
        ]));
  }

  Widget _themeRadio(String label, ThemeMode mode, AppPreferencesNotifier settings, double scale) {
    return RadioListTile<ThemeMode>(
      title: Text(label, style: TextStyle(fontSize: 16 * scale, fontWeight: FontWeight.w500)),
      value: mode, groupValue: settings.themeMode,
      onChanged: (v) {
        if (v == null) return;
        settings.setThemeMode(v);
        context.read<ThemeManager>().setThemeMode(v);
      },
      activeColor: AppColors.primaryBlue,
    );
  }

  // ── UI Scaling ───────────────────────────────────────────────────────────

  Widget _buildUIScalingSection(AppPreferencesNotifier settings, bool isDark, double scale) {
    return _Section(title: 'UI Size', icon: Icons.zoom_in,
        scale: scale, isDark: isDark,
        child: Column(children: [
          _radioTile('Small', '85%', UISize.small, settings.uiSize, settings.setUISize, scale),
          Divider(height: 1 * scale),
          _radioTile('Medium', '100%', UISize.medium, settings.uiSize, settings.setUISize, scale),
          Divider(height: 1 * scale),
          _radioTile('Large', '115%', UISize.large, settings.uiSize, settings.setUISize, scale),
        ]));
  }

  Widget _radioTile<T>(String title, String sub, T val, T group, ValueChanged<T> onChange, double scale) {
    return RadioListTile<T>(
      title: Text(title, style: TextStyle(fontSize: 16 * scale, fontWeight: FontWeight.w500)),
      subtitle: Text(sub, style: TextStyle(fontSize: 14 * scale)),
      value: val, groupValue: group,
      onChanged: (v) { if (v != null) onChange(v); },
      activeColor: AppColors.primaryBlue,
    );
  }

  // ── Reset ────────────────────────────────────────────────────────────────

  Widget _buildResetButton(BuildContext context, AppPreferencesNotifier settings, double scale) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16 * scale),
      child: ElevatedButton.icon(
        onPressed: () => _confirmReset(context, settings),
        icon: Icon(Icons.restore, size: 20 * scale),
        label: Text('Reset All Settings', style: TextStyle(fontSize: 16 * scale, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? const Color(0xFF444444) : const Color(0xFFF0F0F0),
          foregroundColor: isDark ? const Color(0xFFCCCCCC) : const Color(0xFF555555),
          padding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 16 * scale),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12 * scale),
            side: BorderSide(color: isDark ? const Color(0xFF555555) : const Color(0xFFCCCCCC)),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  void _confirmReset(BuildContext context, AppPreferencesNotifier settings) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Reset Settings?'),
      content: const Text('Resets all local settings. Backend config is unchanged.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            settings.resetToDefaults();
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings reset.')));
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(ctx).brightness == Brightness.dark
                ? const Color(0xFF444444) : const Color(0xFFF0F0F0),
            foregroundColor: Theme.of(ctx).brightness == Brightness.dark
                ? const Color(0xFFCCCCCC) : const Color(0xFF555555),
            elevation: 0,
          ),
          child: const Text('Reset'),
        ),
      ],
    ));
  }

  // ── Floating Save Button ────────────────────────────────────────────────

  Widget _buildSaveButton(double scale) {
    IconData icon;
    Color color = AppColors.primaryBlue;
    if (_saving) {
      icon = Icons.hourglass_top;
    } else if (_saveStatus == 'ok') {
      icon = Icons.check_circle;
      color = Colors.green.shade600;
    } else if (_saveStatus == 'error') {
      icon = Icons.warning_amber_rounded;
      color = Colors.orange.shade600;
    } else {
      icon = Icons.save;
    }

    return ElevatedButton.icon(
      onPressed: _saving ? null : _saveSettings,
      icon: _saving
          ? SizedBox(width: 20 * scale, height: 20 * scale,
              child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Icon(icon, size: 22 * scale),
      label: Text(_saving ? 'Saving...' : 'Save & Sync to Backend',
          style: TextStyle(fontSize: 16 * scale, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 16 * scale),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14 * scale)),
        elevation: 6,
      ),
    );
  }

  // ── Test row helper ─────────────────────────────────────────────────────

  Widget _testRow({
    required String label, required IconData icon,
    required bool loading, required String? result,
    required VoidCallback onTap, required double scale, required bool isDark,
  }) {
    final isOK = result != null && result.startsWith('OK');
    final isErr = result != null && result.startsWith('ERR');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: loading ? null : onTap,
          icon: loading
              ? SizedBox(width: 16 * scale, height: 16 * scale,
                  child: CircularProgressIndicator(strokeWidth: 2,
                      color: isDark ? Colors.white54 : Colors.black54))
              : Icon(icon, size: 18 * scale),
          label: Text(label, style: TextStyle(fontSize: 14 * scale)),
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: 10 * scale),
            side: BorderSide(color: isOK ? Colors.green.shade600
                : isErr ? Colors.red.shade400
                : (isDark ? const Color(0xFF555555) : const Color(0xFFCCCCCC))),
            foregroundColor: isOK ? Colors.green.shade600
                : isErr ? Colors.red.shade400
                : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
        if (result != null) ...[
          SizedBox(height: 6 * scale),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 8 * scale),
            decoration: BoxDecoration(
              color: isOK ? Colors.green.withOpacity(0.10) : Colors.red.withOpacity(0.10),
              borderRadius: BorderRadius.circular(6 * scale),
              border: Border.all(
                color: isOK ? Colors.green.shade600.withOpacity(0.4)
                    : Colors.red.shade400.withOpacity(0.4),
              ),
            ),
            child: Text(result!, style: TextStyle(
              fontSize: 12 * scale, fontFamily: 'Courier New',
              color: isOK ? Colors.green.shade700 : Colors.red.shade700)),
          ),
        ],
      ],
    );
  }

  // ── Shared field widget ─────────────────────────────────────────────────

  Widget _field({
    required String label, required TextEditingController ctrl,
    required double scale, required bool isDark,
    String? hint, String? helperText, Widget? suffix, bool obscure = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 14 * scale, fontWeight: FontWeight.w500,
            color: isDark ? Colors.white70 : Colors.black87)),
        SizedBox(height: 8 * scale),
        TextField(
          controller: ctrl, obscureText: obscure,
          style: TextStyle(fontSize: 15 * scale, color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: hint, helperText: helperText, suffixIcon: suffix,
            filled: true,
            fillColor: isDark ? const Color(0xFF3A3A3A) : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8 * scale),
              borderSide: BorderSide(color: isDark ? const Color(0xFF555555) : const Color(0xFFCCCCCC)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8 * scale),
              borderSide: BorderSide(color: isDark ? const Color(0xFF555555) : const Color(0xFFCCCCCC)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8 * scale),
              borderSide: BorderSide(color: AppColors.primaryBlue, width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 12 * scale),
          ),
        ),
      ],
    );
  }
}

// ── Collapsible section container ─────────────────────────────────────────

class _Section extends StatefulWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final double scale;
  final bool isDark;
  final bool initiallyExpanded;

  const _Section({required this.title, required this.icon, required this.child,
      required this.scale, required this.isDark, this.initiallyExpanded = false});

  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.isDark ? const Color(0xFF444444) : const Color(0xFFCCCCCC);
    final cardBg = widget.isDark ? const Color(0xFF2C2C2C) : Colors.white;
    final headerText = widget.isDark ? const Color(0xFFEEEEEE) : const Color(0xFF333333);
    final chevronColor = widget.isDark ? const Color(0xFFAAAAAA) : const Color(0xFF666666);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8 * widget.scale),
        side: BorderSide(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16 * widget.scale, vertical: 14 * widget.scale),
              child: Row(
                children: [
                  Icon(widget.icon, size: 20 * widget.scale, color: AppColors.primaryBlue),
                  SizedBox(width: 10 * widget.scale),
                  Text(widget.title, style: TextStyle(
                    fontSize: 15 * widget.scale, fontWeight: FontWeight.w600, color: headerText)),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.expand_more, size: 22 * widget.scale, color: chevronColor),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: widget.child,
            crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}
