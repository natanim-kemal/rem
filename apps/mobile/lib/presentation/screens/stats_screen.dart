import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Stats', style: Theme.of(context).textTheme.displayMedium),
              const SizedBox(height: 24),

              _StatCard(
                child: Column(
                  children: [
                    Icon(
                      CupertinoIcons.flame_fill,
                      size: 48,
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 8),
                    Text('7', style: Theme.of(context).textTheme.displayLarge),
                    Text(
                      'Day Streak',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      child: _StatItem(
                        icon: CupertinoIcons.bookmark_fill,
                        value: '42',
                        label: 'Saved',
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatCard(
                      child: _StatItem(
                        icon: CupertinoIcons.checkmark_circle_fill,
                        value: '28',
                        label: 'Read',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      child: _StatItem(
                        icon: CupertinoIcons.clock_fill,
                        value: '4.2h',
                        label: 'Reading Time',
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatCard(
                      child: _StatItem(
                        icon: CupertinoIcons.archivebox_fill,
                        value: '12',
                        label: 'Archived',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Text(
                'This Week',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              _StatCard(
                child: SizedBox(
                  height: 120,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _DayBar(day: 'M', value: 0.4),
                      _DayBar(day: 'T', value: 0.6),
                      _DayBar(day: 'W', value: 0.3),
                      _DayBar(day: 'T', value: 0.8),
                      _DayBar(day: 'F', value: 0.5),
                      _DayBar(day: 'S', value: 0.2),
                      _DayBar(day: 'S', value: 0.7, isToday: true),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 24, color: AppTheme.accent),
        const SizedBox(height: 8),
        Text(value, style: Theme.of(context).textTheme.displaySmall),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.textSecondary),
        ),
      ],
    );
  }
}

class _DayBar extends StatelessWidget {
  final String day;
  final double value;
  final bool isToday;

  const _DayBar({required this.day, required this.value, this.isToday = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 24,
          height: 80 * value,
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
