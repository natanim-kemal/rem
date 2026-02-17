enum ContentBlockType {
  paragraph,
  heading1,
  heading2,
  heading3,
  image,
  quote,
  listItem,
}

class ContentBlock {
  final ContentBlockType type;
  final String content;
  final String? imageUrl;

  const ContentBlock({
    required this.type,
    required this.content,
    this.imageUrl,
  });
}
