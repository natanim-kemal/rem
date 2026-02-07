class NotificationPreferences {
  final bool enabled;
  final String dailyDigestTime;
  final int maxPerDay;
  final String quietHoursStart;
  final String quietHoursEnd;
  final int? timezoneOffsetMinutes;

  const NotificationPreferences({
    required this.enabled,
    required this.dailyDigestTime,
    required this.maxPerDay,
    required this.quietHoursStart,
    required this.quietHoursEnd,
    this.timezoneOffsetMinutes,
  });

  factory NotificationPreferences.defaults() {
    return const NotificationPreferences(
      enabled: true,
      dailyDigestTime: '09:00',
      maxPerDay: 5,
      quietHoursStart: '22:00',
      quietHoursEnd: '08:00',
      timezoneOffsetMinutes: 0,
    );
  }

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      enabled: json['enabled'] as bool? ?? true,
      dailyDigestTime: json['dailyDigestTime'] as String? ?? '09:00',
      maxPerDay: json['maxPerDay'] as int? ?? 5,
      quietHoursStart: json['quietHoursStart'] as String? ?? '22:00',
      quietHoursEnd: json['quietHoursEnd'] as String? ?? '08:00',
      timezoneOffsetMinutes: json['timezoneOffsetMinutes'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'dailyDigestTime': dailyDigestTime,
      'maxPerDay': maxPerDay,
      'quietHoursStart': quietHoursStart,
      'quietHoursEnd': quietHoursEnd,
      'timezoneOffsetMinutes': timezoneOffsetMinutes,
    };
  }

  NotificationPreferences copyWith({
    bool? enabled,
    String? dailyDigestTime,
    int? maxPerDay,
    String? quietHoursStart,
    String? quietHoursEnd,
    int? timezoneOffsetMinutes,
  }) {
    return NotificationPreferences(
      enabled: enabled ?? this.enabled,
      dailyDigestTime: dailyDigestTime ?? this.dailyDigestTime,
      maxPerDay: maxPerDay ?? this.maxPerDay,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      timezoneOffsetMinutes:
          timezoneOffsetMinutes ?? this.timezoneOffsetMinutes,
    );
  }
}
