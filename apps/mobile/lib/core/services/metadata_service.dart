import 'dart:convert';

import 'package:metadata_fetch/metadata_fetch.dart';
import 'package:http/http.dart' as http;

class MetadataService {
  Future<Metadata?> fetchMetadata(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      final document = MetadataFetch.responseToDocument(response);
      return MetadataParser.parse(document);
    } catch (e) {
      return null;
    }
  }

  Future<TikTokOEmbed?> fetchTikTokOEmbed(String url) async {
    try {
      final endpoint = Uri.https('www.tiktok.com', '/oembed', {'url': url});
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
