import 'dart:convert';
import 'dart:io';

class TokenService {
  Future<String> fetchToken({
    required Uri baseUrl,
    required String room,
    required String identity,
    String? name,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(baseUrl.resolve('/token'));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({
        'room': room,
        'identity': identity,
        'name': name,
        'canPublish': true,
        'canSubscribe': true,
      }));

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('Token service error ${response.statusCode}: $body');
      }

      final json = jsonDecode(body) as Map<String, dynamic>;
      final token = json['token'] as String?;
      if (token == null || token.isEmpty) {
        throw const FormatException('Token service response missing token');
      }

      return token;
    } finally {
      client.close(force: true);
    }
  }
}
