import 'package:http/http.dart' as http;

class JinaService {
  static const String _baseUrl = 'https://r.jina.ai';
  static const Duration _timeout = Duration(seconds: 20);

  Future<String?> extractContent(String url) async {
    try {
      final encodedUrl = Uri.encodeComponent(url);
      final endpoint = Uri.parse('$_baseUrl/$encodedUrl');

      final response = await http
          .get(endpoint, headers: {'Accept': 'text/markdown'})
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final content = response.body.trim();
        if (content.isNotEmpty && !_isErrorResponse(content)) {
          return content;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<String?> extractHtmlContent(String url) async {
    try {
      final encodedUrl = Uri.encodeComponent(url);
      final endpoint = Uri.parse('$_baseUrl/$encodedUrl');

      final response = await http
          .get(endpoint, headers: {'Accept': 'text/html'})
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final content = response.body.trim();
        if (content.isNotEmpty && !_isErrorResponse(content)) {
          return content;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  bool _isErrorResponse(String content) {
    final lowerContent = content.toLowerCase();
    return lowerContent.contains('error:') ||
        lowerContent.contains('failed to fetch') ||
        lowerContent.contains('unable to retrieve') ||
        lowerContent.contains('404 not found') ||
        lowerContent.contains('access denied');
  }
}
