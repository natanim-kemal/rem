import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get convexUrl => dotenv.env['CONVEX_URL'] ?? '';
  static String get clerkPublishableKey => dotenv.env['CLERK_PUBLISHABLE_KEY'] ?? '';
  static String get clerkIssuerUrl => dotenv.env['CLERK_ISSUER_URL'] ?? '';
  static String get youtubeApiKey => dotenv.env['YOUTUBE_API_KEY'] ?? '';
}
