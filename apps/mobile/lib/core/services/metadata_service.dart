import 'package:metadata_fetch/metadata_fetch.dart';
import 'package:http/http.dart' as http;

class MetadataService {
  Future<Metadata?> fetchMetadata(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      final document = MetadataFetch.responseToDocument(response);
      return MetadataParser.parse(document);
    } catch (e) {
      // Fallback or log error
      return null;
    }
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
