import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/convex_client.dart';
import '../core/services/notification_service.dart';

class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final String? userId;
  final String? email;
  final String? firstName;
  final String? lastName;
  final String? imageUrl;
  final String? error;

  const AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.userId,
    this.email,
    this.firstName,
    this.lastName,
    this.imageUrl,
    this.error,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    String? userId,
    String? email,
    String? firstName,
    String? lastName,
    String? imageUrl,
    String? error,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      imageUrl: imageUrl ?? this.imageUrl,
      error: error,
    );
  }

  String get displayName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    }
    return firstName ?? email ?? 'User';
  }
}

class AuthNotifier extends Notifier<AuthState> {
  ConvexClient get _convex => ref.read(convexClientProvider);

  @override
  AuthState build() => const AuthState();

  void setAuthFromClerk({
    required String userId,
    required String token,
    String? email,
    String? firstName,
    String? lastName,
    String? imageUrl,
  }) {
    _convex.setAuthToken(token);

    state = AuthState(
      isAuthenticated: true,
      isLoading: false,
      userId: userId,
      email: email,
      firstName: firstName,
      lastName: lastName,
      imageUrl: imageUrl,
    );

    NotificationService().registerTokenWithBackend((token, platform) async {
      await _convex.mutation('users:registerPushToken', {
        'token': token,
        'platform': platform,
      });
    });
  }

  Future<void> signOut() async {
    _convex.setAuthToken(null);
    state = const AuthState();
  }
}

final convexClientProvider = Provider<ConvexClient>((ref) {
  return ConvexClient();
});

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});
