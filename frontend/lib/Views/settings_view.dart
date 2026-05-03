import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_preferences.dart';
import '../models/app_preferences_notifier.dart';
import '../models/services/config_api_service.dart';
import '../models/services/preferences_service.dart';
import 'theme_manager.dart';

/// Settings View — Connection, LLM Profiles, Voice Endpoints (with live preview).
class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SettingsBody();
  }
}

// ---------------------------------------------------------------------------
// Body (StatefulWidget so we can hold controllers + async state)
// ---------------------------------------------------------------------------

class _SettingsBody extends StatefulWidget {
  const _SettingsBody();

  @override
  State<_SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends State<_SettingsBody> {
  // ── Text controllers ────────────────────────────────────────────────────
  late final TextEditingController _livekitUrlCtrl;
  late final TextEditingController _tokenServiceUrlCtrl;
  late final TextEditingController _sttUrlCtrl;
  late final TextEditingController _sttModelCtrl;
  late final TextEditingController _ttsUrlCtrl;
  late final TextEditingController _llmUrlCtrl;
  late final TextEditingController _llmModelCtrl;
  late final TextEditingController _previewTextCtrl;

  // ── Voice dropdown ───────────────────────────────────────────────────────
  List<TtsVoice> _voices = [];
  bool _loadingVoices = false;

  // ── TTS Speed ───────────────────────────────────────────────────────────
  double _ttsSpeed = 1.0;
  String? _selectedVoice;

  // ── Preview ─────────────────────────────────────────────────────────────
  bool _previewLoading = false;
  final _audioPlayer = AudioPlayer();

  // ── Save state ──────────────────────────────────────────────────────────
  bool _saving = false;
  String? _saveStatus; // 'ok' | 'error' | null

  // ── Services ────────────────────────────────────────────────────────────
  late ConfigApiService _configApi;

  @override
  void initState() {
    super.initState();
    final prefs = context.read<PreferencesService>();
    _ttsSpeed = prefs.ttsSpeed;
    _selectedVoice = prefs.ttsVoice;

    _livekitUrlCtrl     = TextEditingController(text: prefs.livekitUrl);
    _tokenServiceUrlCtrl = TextEditingController(text: prefs.tokenServiceUrl);
    _sttUrlCtrl         = TextEditingController(text: prefs.sttBaseUrl);
    _sttModelCtrl       = TextEditingController(text: '');
    _ttsUrlCtrl         = TextEditingController(text: prefs.ttsBaseUrl);
    _llmUrlCtrl         = TextEditingController(text: '');
    _llmModelCtrl       = TextEditingController(text: '');
    _previewTextCtrl    = TextEditingController(
        text: 'Hello! This is a voice preview from VoxUI.');

    _configApi = ConfigApiService(
      tokenServiceUrl: () => _tokenServiceUrlCtrl.text.trim(),
    );

    // Load backend config + voices after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBackendConfig();
      _loadVoices();
    });
  }

  @override
  void dispose() {
    _livekitUrlCtrl.dispose();
    _tokenServiceUrlCtrl.dispose();
    _sttUrlCtrl.dispose();
    _sttModelCtrl.dispose();
    _ttsUrlCtrl.dispose();
    _llmUrlCtrl.dispose();
    _llmModelCtrl.dispose();
    _previewTextCtrl.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // ── Backend helpers ──────────────────────────────────────────────────────

  Future<void> _loadBackendConfig() async {
    final cfg = await _configApi.fetchConfig();
    if (cfg == null || !mounted) return;
    setState(() {
      if (cfg['stt_url']      != null) _sttUrlCtrl.text   = cfg['stt_url']!;
      if (cfg['stt_model']    != null) _sttModelCtrl.text = cfg['stt_model']!;
      if (cfg['tts_url']      != null) _ttsUrlCtrl.text   = cfg['tts_url']!;
      if (cfg['llm_base_url'] != null) _llmUrlCtrl.text   = cfg['llm_base_url']!;
      if (cfg['llm_model']    != null) _llmModelCtrl.text = cfg['llm_model']!;
      if (cfg['tts_voice']    != null) {
        _selectedVoice = cfg['tts_voice'] as String;
      }
      if (cfg['tts_speed']    != null) {
        _ttsSpeed = (cfg['tts_speed'] as num).toDouble();
      }
    });
  }

  Future<void> _loadVoices() async {
    setState(() => _loadingVoices = true);
    final voices = await _configApi.fetchVoices();
    if (!mounted) return;
    setState(() {
      _voices = voices;
      _loadingVoices = false;
      // If selected voice isn't in the list, reset to first
      if (_selectedVoice != null &&
          !voices.any((v) => v.id == _selectedVoice)) {
        _selectedVoice = voices.isNotEmpty ? voices.first.id : null;
      }
    });
  }

  Future<void> _saveSettings() async {
    final prefs  = context.read<PreferencesService>();
    final notifier = context.read<AppPreferencesNotifier>();

    // Persist connection settings locally
    prefs.livekitUrl      = _livekitUrlCtrl.text.trim();
    prefs.tokenServiceUrl = _tokenServiceUrlCtrl.text.trim();
    prefs.sttBaseUrl      = _sttUrlCtrl.text.trim();
    prefs.ttsBaseUrl      = _ttsUrlCtrl.text.trim();
    prefs.ttsVoice        = _selectedVoice ?? 'af_heart';
    prefs.ttsSpeed        = _ttsSpeed;
    notifier.ttsVoice     = prefs.ttsVoice;
    notifier.ttsSpeed     = _ttsSpeed;

    setState(() { _saving = true; _saveStatus = null; });

    // Push to backend
    final ok = await _configApi.updateConfig({
      'stt_url':       _sttUrlCtrl.text.trim(),
      'stt_model':     _sttModelCtrl.text.trim(),
      'tts_url':       _ttsUrlCtrl.text.trim(),
      'tts_voice':     _selectedVoice ?? 'af_heart',
      'tts_speed':     _ttsSpeed,
      'llm_base_url':  _llmUrlCtrl.text.trim(),
      'llm_model':     _llmModelCtrl.text.trim(),
    });

    if (!mounted) return;
    setState(() {
      _saving = false;
      _saveStatus = ok ? 'ok' : 'error';
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Settings saved and synced to backend.' : 'Saved locally. Backend unreachable.'),
      backgroundColor: ok ? Colors.green.shade700 : Colors.orange.shade700,
      duration: const Duration(seconds: 3),
    ));

    // Auto-clear status icon after 4 s
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _saveStatus = null);
    });
  }

  Future<void> _playPreview() async {
    final text  = _previewTextCtrl.text.trim();
    final voice = _selectedVoice ?? 'af_heart';
    if (text.isEmpty) return;

    setState(() => _previewLoading = true);
    final bytes = await _configApi.previewTts(
      text: text, voice: voice, speed: _ttsSpeed,
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

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppPreferencesNotifier>();
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final scale    = settings.uiScale;

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [const Color(0xFF1A1A2E), const Color(0xFF16213E)]
                  : [const Color(0xFFF0F4F8), const Color(0xFFE1E8ED)],
            ),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24 * scale, 32 * scale, 24 * scale, 100 * scale),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(isDark, scale),
                SizedBox(height: 32 * scale),
                _buildConnectionSection(isDark, scale),
                SizedBox(height: 24 * scale),
                _buildLlmSection(settings, isDark, scale),
                SizedBox(height: 24 * scale),
                _buildVoiceSection(isDark, scale),
                SizedBox(height: 24 * scale),
                _buildPreviewCard(isDark, scale),
                SizedBox(height: 24 * scale),
                _buildThemeSection(settings, isDark, scale),
                SizedBox(height: 24 * scale),
                _buildUIScalingSection(settings, isDark, scale),
                SizedBox(height: 24 * scale),
                _buildResetButton(context, settings, scale),
                SizedBox(height: 32 * scale),
              ],
            ),
          ),
        ),

        // Floating save button
        Positioned(
          bottom: 24 * scale,
          left: 24 * scale,
          right: 24 * scale,
          child: _buildSaveButton(scale),
        ),
      ],
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader(bool isDark, double scale) {
    return Row(
      children: [
        Icon(Icons.admin_panel_settings, size: 36,
            color: isDark ? AppColors.primaryBlue : const Color(0xFF0066CC)),
        SizedBox(width: 16 * scale),
        Text('Settings',
            style: TextStyle(
              color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
              fontSize: 28 * scale,
              fontWeight: FontWeight.bold,
            )),
      ],
    );
  }

  // ── Connection ───────────────────────────────────────────────────────────

  Widget _buildConnectionSection(bool isDark, double scale) {
    return _Section(title: 'Connection', icon: Icons.cloud_outlined,
        scale: scale, isDark: isDark,
        child: Padding(
          padding: EdgeInsets.all(16 * scale),
          child: Column(children: [
            _field(label: 'LiveKit Server URL',   ctrl: _livekitUrlCtrl,      scale: scale, isDark: isDark),
            SizedBox(height: 16 * scale),
            _field(label: 'Token Service URL',    ctrl: _tokenServiceUrlCtrl, scale: scale, isDark: isDark,
                hint: 'http://localhost:7882',
                suffix: IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Reload config from backend',
                  onPressed: () { _loadBackendConfig(); _loadVoices(); },
                )),
          ]),
        ));
  }

  // ── LLM ─────────────────────────────────────────────────────────────────

  Widget _buildLlmSection(AppPreferencesNotifier settings, bool isDark, double scale) {
    final profiles  = settings.llmProfiles;
    final activeId  = settings.activeProfileId;

    return _Section(title: 'LLM', icon: Icons.psychology_outlined,
        scale: scale, isDark: isDark,
        child: Padding(
          padding: EdgeInsets.all(16 * scale),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _field(label: 'LLM Base URL', ctrl: _llmUrlCtrl, scale: scale, isDark: isDark,
                  hint: 'http://laptop-hermes.resonancegroupusa.com'),
              SizedBox(height: 16 * scale),
              _field(label: 'Model Name', ctrl: _llmModelCtrl, scale: scale, isDark: isDark,
                  hint: 'qwen3-30b-a3b-instruct'),
              if (profiles.isNotEmpty) ...[
                SizedBox(height: 16 * scale),
                Text('Saved Profiles', style: TextStyle(
                  fontSize: 13 * scale, fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white60 : Colors.black54,
                )),
                SizedBox(height: 8 * scale),
                ...profiles.map((p) {
                  final active = p.id == activeId;
                  return Padding(
                    padding: EdgeInsets.only(bottom: 6 * scale),
                    child: ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10 * scale),
                        side: BorderSide(
                          color: active ? AppColors.primaryBlue : Colors.transparent,
                          width: active ? 1.5 : 0,
                        ),
                      ),
                      leading: Radio<String>(
                        value: p.id, groupValue: activeId,
                        onChanged: (_) {
                          settings.setActiveProfileId(p.id);
                          _llmUrlCtrl.text   = p.baseUrl;
                          _llmModelCtrl.text = p.modelName;
                        },
                        activeColor: AppColors.primaryBlue,
                      ),
                      title: Text(p.name, style: TextStyle(fontSize: 14 * scale)),
                      subtitle: Text('${p.modelName}  •  ${p.baseUrl}',
                          style: TextStyle(fontSize: 11 * scale,
                              color: isDark ? Colors.white54 : Colors.black45)),
                      onTap: () {
                        settings.setActiveProfileId(p.id);
                        _llmUrlCtrl.text   = p.baseUrl;
                        _llmModelCtrl.text = p.modelName;
                      },
                    ),
                  );
                }),
              ],
            ],
          ),
        ));
  }

  // ── Voice Endpoints ───────────────────────────────────────────────────────

  Widget _buildVoiceSection(bool isDark, double scale) {
    return _Section(title: 'Voice Endpoints', icon: Icons.record_voice_over_outlined,
        scale: scale, isDark: isDark,
        child: Padding(
          padding: EdgeInsets.all(16 * scale),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _field(label: 'STT Base URL', ctrl: _sttUrlCtrl, scale: scale, isDark: isDark,
                  hint: 'https://jetson-whisper.resonancegroupusa.com'),
              SizedBox(height: 16 * scale),
              _field(label: 'STT Model', ctrl: _sttModelCtrl, scale: scale, isDark: isDark,
                  hint: 'Systran/faster-distil-whisper-small.en'),
              SizedBox(height: 16 * scale),
              _field(label: 'TTS Base URL', ctrl: _ttsUrlCtrl, scale: scale, isDark: isDark,
                  hint: 'https://jetson-kokoro.resonancegroupusa.com',
                  suffix: IconButton(
                    icon: _loadingVoices
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.refresh),
                    tooltip: 'Reload voice list',
                    onPressed: _loadingVoices ? null : _loadVoices,
                  )),
              SizedBox(height: 16 * scale),

              // Voice dropdown
              Text('TTS Voice', style: TextStyle(
                fontSize: 14 * scale, fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : Colors.black87,
              )),
              SizedBox(height: 8 * scale),
              _loadingVoices
                  ? const LinearProgressIndicator()
                  : DropdownButtonFormField<String>(
                      value: _voices.any((v) => v.id == _selectedVoice)
                          ? _selectedVoice
                          : (_voices.isNotEmpty ? _voices.first.id : null),
                      items: _voices.map((v) => DropdownMenuItem(
                        value: v.id,
                        child: Text('${v.name}  (${v.id})',
                            style: TextStyle(fontSize: 14 * scale)),
                      )).toList(),
                      onChanged: (v) => setState(() => _selectedVoice = v),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8 * scale)),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 12 * scale, vertical: 12 * scale),
                        hintText: _voices.isEmpty ? 'Loading voices...' : null,
                      ),
                    ),

              SizedBox(height: 20 * scale),

              // Speed slider
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Speed', style: TextStyle(
                    fontSize: 14 * scale, fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white70 : Colors.black87,
                  )),
                  Text('${_ttsSpeed.toStringAsFixed(1)}×',
                      style: TextStyle(
                        fontSize: 14 * scale, fontWeight: FontWeight.w600,
                        color: AppColors.primaryBlue,
                      )),
                ],
              ),
              Slider(
                value: _ttsSpeed,
                min: 0.5, max: 2.0,
                divisions: 15,
                label: '${_ttsSpeed.toStringAsFixed(1)}×',
                activeColor: AppColors.primaryBlue,
                onChanged: (v) => setState(() => _ttsSpeed = v),
              ),
            ],
          ),
        ));
  }

  // ── Voice Preview ─────────────────────────────────────────────────────────

  Widget _buildPreviewCard(bool isDark, double scale) {
    return _Section(title: 'Voice Preview', icon: Icons.play_circle_outline,
        scale: scale, isDark: isDark,
        child: Padding(
          padding: EdgeInsets.all(16 * scale),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _previewTextCtrl,
                maxLines: 3,
                style: TextStyle(fontSize: 15 * scale),
                decoration: InputDecoration(
                  hintText: 'Type something to preview...',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8 * scale)),
                  contentPadding: EdgeInsets.all(12 * scale),
                ),
              ),
              SizedBox(height: 12 * scale),
              ElevatedButton.icon(
                onPressed: _previewLoading ? null : _playPreview,
                icon: _previewLoading
                    ? SizedBox(width: 18 * scale, height: 18 * scale,
                        child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(Icons.volume_up, size: 20 * scale),
                label: Text(
                  _previewLoading ? 'Synthesising...' : 'Play Preview',
                  style: TextStyle(fontSize: 16 * scale, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14 * scale),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10 * scale)),
                ),
              ),
            ],
          ),
        ));
  }

  // ── Theme ─────────────────────────────────────────────────────────────────

  Widget _buildThemeSection(AppPreferencesNotifier settings, bool isDark, double scale) {
    return _Section(title: 'Theme', icon: Icons.brightness_6_outlined,
        scale: scale, isDark: isDark,
        child: Column(children: [
          _themeRadio('Dark',   ThemeMode.dark,   settings, scale),
          Divider(height: 1 * scale),
          _themeRadio('Light',  ThemeMode.light,  settings, scale),
          Divider(height: 1 * scale),
          _themeRadio('System', ThemeMode.system, settings, scale),
        ]));
  }

  Widget _themeRadio(String label, ThemeMode mode,
      AppPreferencesNotifier settings, double scale) {
    return RadioListTile<ThemeMode>(
      title: Text(label, style: TextStyle(fontSize: 16 * scale, fontWeight: FontWeight.w500)),
      value: mode,
      groupValue: settings.themeMode,
      onChanged: (v) {
        if (v == null) return;
        settings.setThemeMode(v);
        // Also update ThemeManager so the app reacts immediately
        context.read<ThemeManager>().setThemeMode(v);
      },
      activeColor: AppColors.primaryBlue,
    );
  }

  // ── UI Scaling ────────────────────────────────────────────────────────────

  Widget _buildUIScalingSection(AppPreferencesNotifier settings, bool isDark, double scale) {
    return _Section(title: 'UI Size', icon: Icons.zoom_in,
        scale: scale, isDark: isDark,
        child: Column(children: [
          _radioTile('Small', '85%',  UISize.small,  settings.uiSize, settings.setUISize, scale),
          Divider(height: 1 * scale),
          _radioTile('Medium', '100%', UISize.medium, settings.uiSize, settings.setUISize, scale),
          Divider(height: 1 * scale),
          _radioTile('Large', '115%',  UISize.large,  settings.uiSize, settings.setUISize, scale),
        ]));
  }

  Widget _radioTile<T>(String title, String sub, T val, T group,
      ValueChanged<T> onChange, double scale) {
    return RadioListTile<T>(
      title: Text(title, style: TextStyle(fontSize: 16 * scale, fontWeight: FontWeight.w500)),
      subtitle: Text(sub, style: TextStyle(fontSize: 14 * scale)),
      value: val, groupValue: group,
      onChanged: (v) { if (v != null) onChange(v); },
      activeColor: AppColors.primaryBlue,
    );
  }

  // ── Reset ─────────────────────────────────────────────────────────────────

  Widget _buildResetButton(BuildContext context, AppPreferencesNotifier settings, double scale) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16 * scale),
      child: ElevatedButton.icon(
        onPressed: () => _confirmReset(context, settings),
        icon: Icon(Icons.restore, size: 20 * scale),
        label: Text('Reset All Settings', style: TextStyle(
            fontSize: 16 * scale, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.error,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 16 * scale),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12 * scale)),
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
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings reset.')));
          },
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error, foregroundColor: Colors.white),
          child: const Text('Reset'),
        ),
      ],
    ));
  }

  // ── Floating Save Button ──────────────────────────────────────────────────

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
      label: Text(
        _saving ? 'Saving...' : 'Save & Sync to Backend',
        style: TextStyle(fontSize: 16 * scale, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 16 * scale),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14 * scale)),
        elevation: 6,
      ),
    );
  }

  // ── Shared widgets ────────────────────────────────────────────────────────

  Widget _field({
    required String label,
    required TextEditingController ctrl,
    required double scale,
    required bool isDark,
    String? hint,
    Widget? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(
          fontSize: 14 * scale, fontWeight: FontWeight.w500,
          color: isDark ? Colors.white70 : Colors.black87,
        )),
        SizedBox(height: 8 * scale),
        TextField(
          controller: ctrl,
          style: TextStyle(fontSize: 15 * scale),
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: suffix,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8 * scale)),
            contentPadding: EdgeInsets.symmetric(
                horizontal: 12 * scale, vertical: 12 * scale),
          ),
        ),
      ],
    );
  }
}

// ── Section container ───────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final double scale;
  final bool isDark;

  const _Section({
    required this.title, required this.icon, required this.child,
    required this.scale, required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16 * scale),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.1), blurRadius: 8 * scale,
          offset: Offset(0, 4 * scale),
        )],
        border: Border.all(
          color: isDark
              ? AppColors.primaryBlue.withOpacity(0.3)
              : const Color(0xFF0066CC).withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(16 * scale),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.primaryBlue.withOpacity(0.15)
                  : const Color(0xFF0066CC).withOpacity(0.1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16 * scale),
                topRight: Radius.circular(16 * scale),
              ),
            ),
            child: Row(children: [
              Icon(icon, size: 24 * scale,
                  color: isDark ? AppColors.primaryBlue : const Color(0xFF0066CC)),
              SizedBox(width: 12 * scale),
              Text(title, style: TextStyle(
                fontSize: 18 * scale, fontWeight: FontWeight.bold,
                color: isDark ? AppColors.primaryBlue : const Color(0xFF0066CC),
              )),
            ]),
          ),
          child,
        ],
      ),
    );
  }
}
