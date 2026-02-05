import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/notification_service.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService();
  service.initialize();

  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

final fcmTokenProvider = Provider<String?>((ref) {
  final service = ref.watch(notificationServiceProvider);
  return service.fcmToken;
});
