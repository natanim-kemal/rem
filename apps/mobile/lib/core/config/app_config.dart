class AppConfig {
  static const String convexUrl = String.fromEnvironment(
    'CONVEX_URL',
    defaultValue: 'https://robust-tiger-419.convex.cloud',
  );

  static const String clerkPublishableKey = String.fromEnvironment(
    'CLERK_PUBLISHABLE_KEY',
    defaultValue: 'pk_test_ZXF1YWwtbW9yYXktOTEuY2xlcmsuYWNjb3VudHMuZGV2JA',
  );

  static const String clerkIssuerUrl = String.fromEnvironment(
    'CLERK_ISSUER_URL',
    defaultValue: 'https://equal-moray-91.clerk.accounts.dev',
  );
}
