import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Voice/ID pair for TTS voice dropdown.
class TtsVoice {
  final String id;
  final String name;
  const TtsVoice({required this.id, required this.name});
}

/// ConfigApiService — wraps the VoxUI backend REST config endpoints.
///
/// Base URL is read lazily from [tokenServiceUrl] each call so it picks
/// up changes the user makes in Settings without needing a new instance.
class ConfigApiService {
  /// Returns the current token service URL (e.g. "http://localhost:7882").
  final String Function() tokenServiceUrl;

  ConfigApiService({required this.tokenServiceUrl});

  Uri _uri(String path) => Uri.parse('${tokenServiceUrl()}$path');

  static const _timeout = Duration(seconds: 8);
  static const _previewTimeout = Duration(seconds: 30);

  /// GET /config — returns current backend config or null on error.
  Future<Map<String, dynamic>?> fetchConfig() async {
    try {
      final resp = await http.get(_uri('/config')).timeout(_timeout);
      if (resp.statusCode == 200) {
        return json.decode(resp.body) as Map<String, dynamic>;
      }
      debugPrint('ConfigApiService: GET /config → ${resp.statusCode}');
    } catch (e) {
      debugPrint('ConfigApiService: GET /config failed: $e');
    }
    return null;
  }

  /// PUT /config — updates backend settings.  Returns true on success.
  Future<bool> updateConfig(Map<String, dynamic> updates) async {
    try {
      final resp = await http
          .put(
            _uri('/config'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(updates),
          )
          .timeout(_timeout);
      if (resp.statusCode == 200) return true;
      debugPrint('ConfigApiService: PUT /config → ${resp.statusCode}: ${resp.body}');
    } catch (e) {
      debugPrint('ConfigApiService: PUT /config failed: $e');
    }
    return false;
  }

  /// GET /voices — returns list of available TTS voices.
  /// Falls back to built-in Kokoro defaults if the endpoint is unreachable.
  Future<List<TtsVoice>> fetchVoices() async {
    try {
      final resp = await http.get(_uri('/voices')).timeout(_timeout);
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        final voices = data['voices'] as List<dynamic>;
        return voices.map((v) {
          final m = v as Map<String, dynamic>;
          return TtsVoice(id: m['id'] as String, name: m['name'] as String);
        }).toList();
      }
    } catch (e) {
      debugPrint('ConfigApiService: GET /voices failed: $e');
    }
    // Built-in fallback — mirrors token_service.py KOKORO_DEFAULT_VOICES
    return const [
      TtsVoice(id: 'af_heart',    name: 'Heart (AF)'),
      TtsVoice(id: 'af_bella',    name: 'Bella (AF)'),
      TtsVoice(id: 'af_nicole',   name: 'Nicole (AF)'),
      TtsVoice(id: 'af_sarah',    name: 'Sarah (AF)'),
      TtsVoice(id: 'af_sky',      name: 'Sky (AF)'),
      TtsVoice(id: 'am_adam',     name: 'Adam (AM)'),
      TtsVoice(id: 'am_michael',  name: 'Michael (AM)'),
      TtsVoice(id: 'bf_emma',     name: 'Emma (BF)'),
      TtsVoice(id: 'bf_isabella', name: 'Isabella (BF)'),
      TtsVoice(id: 'bm_george',   name: 'George (BM)'),
      TtsVoice(id: 'bm_lewis',    name: 'Lewis (BM)'),
    ];
  }

  /// POST /preview — synthesises [text] and returns raw audio bytes.
  /// Returns null on error.
  Future<Uint8List?> previewTts({
    required String text,
    required String voice,
    required double speed,
  }) async {
    try {
      final resp = await http
          .post(
            _uri('/preview'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'text': text, 'voice': voice, 'speed': speed}),
          )
          .timeout(_previewTimeout);
      if (resp.statusCode == 200) return resp.bodyBytes;
      debugPrint('ConfigApiService: POST /preview → ${resp.statusCode}: ${resp.body}');
    } catch (e) {
      debugPrint('ConfigApiService: POST /preview failed: $e');
    }
    return null;
  }
}
