import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get convexUrl => dotenv.env['CONVEX_URL'] ?? '';
  static String get clerkPublishableKey =>
      dotenv.env['CLERK_PUBLISHABLE_KEY'] ?? '';
  static String get clerkIssuerUrl => dotenv.env['CLERK_ISSUER_URL'] ?? '';
  static String get youtubeApiKey => dotenv.env['YOUTUBE_API_KEY'] ?? '';

  static String get convexSiteUrl {
    final env = dotenv.env['CONVEX_SITE_URL'];
    if (env != null && env.isNotEmpty) return env;
    final url = convexUrl;
    if (url.isEmpty) return '';
    return url.replaceFirst('.convex.cloud', '.convex.site');
  }
}
