import 'dart:convert';

import 'package:metadata_fetch/metadata_fetch.dart';
import 'package:http/http.dart' as http;

class MetadataService {
  static const int wordsPerMinute = 225;

  Future<Metadata?> fetchMetadata(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      final document = MetadataFetch.responseToDocument(response);
      return MetadataParser.parse(document);
    } catch (e) {
      return null;
    }
  }

  int calculateReadingTime(String? text) {
    if (text == null || text.isEmpty) return 0;
    final wordCount = text.split(RegExp(r'\s+')).length;
    return (wordCount / wordsPerMinute).ceil();
  }

  int calculateVideoReadingTime(Duration? duration) {
    if (duration == null) return 0;
    return duration.inMinutes;
  }

  Future<TikTokOEmbed?> fetchTikTokOEmbed(String url) async {
    try {
      String oembedUrl = url;

      if (url.contains('vt.tiktok.com') || url.contains('vm.tiktok.com')) {
        final resolved = await _resolveShortUrl(url);
        if (resolved != null) {
          oembedUrl = resolved;
        }
      }

      final endpoint = Uri.https('www.tiktok.com', '/oembed', {
        'url': oembedUrl,
      });
      final response = await http.get(endpoint);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) return null;
      return TikTokOEmbed.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<String?> _resolveShortUrl(String url) async {
    try {
      final client = http.Client();
      final response = await client
          .get(
            Uri.parse(url),
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode >= 300 && response.statusCode < 400) {
        return response.headers['location'];
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<XOEmbed?> fetchXOEmbed(String url) async {
    try {
      final endpoint = Uri.https('publish.twitter.com', '/oembed', {
        'url': url,
      });
      final response = await http.get(endpoint);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) return null;
      return XOEmbed.fromJson(data);
    } catch (_) {
      return null;
    }
  }
}

class TikTokOEmbed {
  final String? title;
  final String? thumbnailUrl;

  const TikTokOEmbed({this.title, this.thumbnailUrl});

  factory TikTokOEmbed.fromJson(Map<String, dynamic> json) {
    return TikTokOEmbed(
      title: json['title'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
    );
  }
}

class XOEmbed {
  final String? html;

  const XOEmbed({this.html});

  factory XOEmbed.fromJson(Map<String, dynamic> json) {
    return XOEmbed(html: json['html'] as String?);
  }
}

class LinkMetadata {
  final String title;
  final String? description;
  final String? imageUrl;
  final String url;

  LinkMetadata({
    required this.title,
    this.description,
    this.imageUrl,
    required this.url,
  });

  factory LinkMetadata.fromMetadata(Metadata metadata, String originalUrl) {
    return LinkMetadata(
      title: metadata.title ?? originalUrl,
      description: metadata.description,
      imageUrl: metadata.image,
      url: metadata.url ?? originalUrl,
    );
  }
}
