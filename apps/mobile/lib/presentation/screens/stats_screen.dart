import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/database.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../theme/app_theme.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final userId = authState.userId;

    if (userId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final itemsAsync = ref.watch(itemsStreamProvider(userId));

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: itemsAsync.when(
          data: (items) => _StatsBody(items: items),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.exclamationmark_triangle,
                    size: 52,
                    color: context.textTertiary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Unable to load stats',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatsBody extends StatelessWidget {
  final List<Item> items;

  const _StatsBody({required this.items});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final total = items.length;

    final readItems = items.where((item) => item.status == 'read').toList();
    final archivedItems = items
        .where((item) => item.status == 'archived')
        .toList();
    final unreadItems = items.where((item) => item.status == 'unread').toList();

    final totalReadMinutes = readItems.fold<int>(
      0,
      (sum, item) => sum + (item.estimatedReadTime ?? 0),
    );
    final averageReadMinutes = readItems.isEmpty
        ? 0
        : (totalReadMinutes / readItems.length).round();

    final readRate = total == 0 ? 0.0 : (readItems.length / total);

    final weekDays = List.generate(
      7,
      (index) => _dayKey(now.subtract(Duration(days: 6 - index))),
    );

    final savedByDay = {for (final day in weekDays) day: 0};
    for (final item in items) {
      final day = _dayKey(DateTime.fromMillisecondsSinceEpoch(item.createdAt));
      if (savedByDay.containsKey(day)) {
        savedByDay[day] = (savedByDay[day] ?? 0) + 1;
      }
    }

    final readDays = <DateTime>{};
    for (final item in readItems) {
      final timestamp = item.readAt ?? item.updatedAt;
      if (timestamp > 0) {
        readDays.add(_dayKey(DateTime.fromMillisecondsSinceEpoch(timestamp)));
      }
    }
    final streak = _calculateStreak(readDays, now);

    final readThisWeek = readItems.where((item) {
      final timestamp = item.readAt ?? item.updatedAt;
      return timestamp >= weekDays.first.millisecondsSinceEpoch;
    }).length;

    final typeCounts = <String, int>{};
    for (final item in items) {
      final type = item.type.isEmpty ? 'other' : item.type.toLowerCase();
      typeCounts[type] = (typeCounts[type] ?? 0) + 1;
    }
    final sortedTypes = typeCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final tagCounts = <String, int>{};
    for (final item in items) {
      for (final tag in _parseTags(item.tags)) {
        final normalized = tag.trim();
        if (normalized.isEmpty) continue;
        tagCounts[normalized] = (tagCounts[normalized] ?? 0) + 1;
      }
    }
    final topTags = tagCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeaderRow(total: total),
          const SizedBox(height: 16),
          _HeroCard(
            streak: streak,
            savedThisWeek: savedByDay.values.fold<int>(0, (a, b) => a + b),
            readRate: readRate,
            readThisWeek: readThisWeek,
          ),
          const SizedBox(height: 20),
          _SectionTitle(title: 'Overview'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  icon: CupertinoIcons.bookmark_fill,
                  label: 'Saved',
                  value: '$total',
                  tone: AppTheme.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  icon: CupertinoIcons.checkmark_circle_fill,
                  label: 'Read',
                  value: '${readItems.length}',
                  tone: const Color(0xFF3C8D7D),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  icon: CupertinoIcons.bell,
                  label: 'Unread',
                  value: '${unreadItems.length}',
                  tone: const Color(0xFF5B7DA5),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  icon: CupertinoIcons.archivebox_fill,
                  label: 'Archived',
                  value: '${archivedItems.length}',
                  tone: const Color(0xFF916E4D),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SectionTitle(title: 'Time & habits'),
          const SizedBox(height: 12),
          _StatCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _MetricChip(
                      icon: CupertinoIcons.clock_fill,
                      label: 'Reading time',
                      value: _formatMinutes(totalReadMinutes),
                    ),
                    const SizedBox(width: 12),
                    _MetricChip(
                      icon: CupertinoIcons.timer,
                      label: 'Avg read',
                      value: averageReadMinutes == 0
                          ? '—'
                          : '${averageReadMinutes}m',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _ProgressRow(label: 'Completion rate', value: readRate),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SectionTitle(title: 'This week'),
          const SizedBox(height: 12),
          _StatCard(
            child: _WeekChart(savedByDay: savedByDay, now: now),
          ),
          const SizedBox(height: 20),
          _SectionTitle(title: 'Library breakdown'),
          const SizedBox(height: 12),
          _StatCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: sortedTypes.isEmpty
                      ? [_TypeChip(label: 'No items yet', count: 0)]
                      : sortedTypes
                            .map(
                              (entry) => _TypeChip(
                                label: entry.key,
                                count: entry.value,
                              ),
                            )
                            .toList(),
                ),
                const SizedBox(height: 12),
                Text(
                  sortedTypes.isEmpty
                      ? 'Add a few items to unlock insights.'
                      : 'Most saved: ${sortedTypes.first.key}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: context.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SectionTitle(title: 'Top tags'),
          const SizedBox(height: 12),
          _StatCard(
            child: topTags.isEmpty
                ? Text(
                    'No tags yet. Add tags to see your most used labels.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.textSecondary,
                    ),
                  )
                : Column(
                    children: topTags
                        .take(5)
                        .map((tag) => _TagRow(label: tag.key, count: tag.value))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  final int total;

  const _HeaderRow({required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('stats', style: Theme.of(context).textTheme.displayMedium),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: context.surfaceElevated,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            total == 0 ? 'Get started' : 'Last 7 days',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: context.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  final int streak;
  final int savedThisWeek;
  final double readRate;
  final int readThisWeek;

  const _HeroCard({
    required this.streak,
    required this.savedThisWeek,
    required this.readRate,
    required this.readThisWeek,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accent.withValues(alpha: 0.18),
            Theme.of(context).colorScheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.divider.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  CupertinoIcons.flame_fill,
                  color: AppTheme.accent,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$streak day streak',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    '$savedThisWeek saved • $readThisWeek read this week',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ProgressRow(label: 'Read rate', value: readRate),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.headlineSmall);
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color tone;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.divider.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: tone),
          ),
          const SizedBox(height: 12),
          Text(value, style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetricChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: context.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppTheme.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final String label;
  final double value;

  const _ProgressRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: context.textSecondary),
            ),
            Text(
              '${(value * 100).round()}%',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: value.isNaN ? 0 : value,
            minHeight: 8,
            backgroundColor: context.surfaceElevated,
            valueColor: const AlwaysStoppedAnimation(AppTheme.accent),
          ),
        ),
      ],
    );
  }
}

class _WeekChart extends StatelessWidget {
  final Map<DateTime, int> savedByDay;
  final DateTime now;

  const _WeekChart({required this.savedByDay, required this.now});

  @override
  Widget build(BuildContext context) {
    final maxValue = savedByDay.values.fold<int>(1, (a, b) => a > b ? a : b);

    return SizedBox(
      height: 140,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: savedByDay.entries.map((entry) {
          final isToday = _dayKey(now) == entry.key;
          final heightFactor = maxValue == 0 ? 0.0 : entry.value / maxValue;
          return _DayBar(
            day: _weekdayLabel(entry.key.weekday),
            value: heightFactor,
            count: entry.value,
            isToday: isToday,
          );
        }).toList(),
      ),
    );
  }
}

class _DayBar extends StatelessWidget {
  final String day;
  final double value;
  final int count;
  final bool isToday;

  const _DayBar({
    required this.day,
    required this.value,
    required this.count,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    final barHeight = (value * 88).clamp(6, 88).toDouble();
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '$count',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: context.textSecondary),
        ),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          width: 20,
          height: barHeight,
          decoration: BoxDecoration(
            color: isToday ? AppTheme.accent : context.textTertiary,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          day,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isToday ? FontWeight.w600 : FontWeight.normal,
            color: isToday ? AppTheme.accent : context.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final int count;

  const _TypeChip({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: AppTheme.accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _TagRow extends StatelessWidget {
  final String label;
  final int count;

  const _TagRow({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(
            '$count',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: context.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final Widget child;

  const _StatCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.divider.withValues(alpha: 0.5)),
      ),
      child: child,
    );
  }
}

DateTime _dayKey(DateTime date) => DateTime(date.year, date.month, date.day);

int _calculateStreak(Set<DateTime> readDays, DateTime now) {
  var streak = 0;
  var cursor = _dayKey(now);
  while (readDays.contains(cursor)) {
    streak += 1;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}

String _weekdayLabel(int weekday) {
  switch (weekday) {
    case DateTime.monday:
      return 'M';
    case DateTime.tuesday:
      return 'T';
    case DateTime.wednesday:
      return 'W';
    case DateTime.thursday:
      return 'T';
    case DateTime.friday:
      return 'F';
    case DateTime.saturday:
      return 'S';
    case DateTime.sunday:
      return 'S';
    default:
      return '';
  }
}

String _formatMinutes(int minutes) {
  if (minutes <= 0) return '0m';
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  if (hours == 0) return '${remainder}m';
  if (remainder == 0) return '${hours}h';
  return '${hours}h ${remainder}m';
}

List<String> _parseTags(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return [];
  if (trimmed.startsWith('[')) {
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is List) {
        return decoded.whereType<String>().toList();
      }
    } catch (_) {}
  }
  return trimmed
      .split(',')
      .map((tag) => tag.trim())
      .where((tag) => tag.isNotEmpty)
      .toList();
}
