import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'home_screen.dart';
import 'stats_screen.dart';
import 'profile_screen.dart';
import '../widgets/add_item_sheet.dart';

import '../../core/services/share_service.dart';
import '../../providers/notification_provider.dart';
import '../../providers/data_providers.dart';
import '../../data/sync/sync_engine.dart';

class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({super.key});

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> {
  int _currentIndex = 0;
  late final PageController _pageController;
  final _shareService = ShareService();

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _pageIndexForNavIndex(0));
    _shareService.initialize();
    _shareService.contentStream.listen(_handleSharedContent);
    final notificationService = ref.read(notificationServiceProvider);
    notificationService.onAction = _handleNotificationAction;
    ref.read(syncEngineProvider);
  }

  @override
  void dispose() {
    _shareService.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _handleSharedContent(SharedContent content) {
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddItemSheet(
        initialUrl: content.type == ShareType.text ? content.text : null,
        initialFiles: content.type == ShareType.media
            ? content.files.map((f) => f.path).toList()
            : null,
      ),
    );
  }

  Future<void> _handleNotificationAction(String? payload) async {
    if (payload == null || payload.isEmpty) return;
    final data = Uri.splitQueryString(payload);
    final itemId = data['itemId'] ?? payload;
    final action = data['action'];

    if (action == 'open_unread_list') {
      if (!mounted) return;
      setState(() => _currentIndex = 0);
      return;
    }

    final db = ref.read(databaseProvider);
    final syncEngine = ref.read(syncEngineProvider);

    if (itemId.isEmpty) return;

    final item = await db.getItemById(itemId);
    if (item == null && itemId.isNotEmpty) {
      final byConvex = await db.getItemByConvexId(itemId);
      if (byConvex != null) {
        await _applyNotificationAction(byConvex.id, action, syncEngine);
      }
      return;
    }

    await _applyNotificationAction(itemId, action, syncEngine);
  }

  Future<void> _applyNotificationAction(
    String itemId,
    String? action,
    SyncEngine syncEngine,
  ) async {
    switch (action) {
      case 'mark_read':
        await syncEngine.updateItemStatus(itemId, 'read');
        break;
      case 'snooze_30':
        await syncEngine.snoozeItem(itemId, const Duration(minutes: 30));
        break;
      case 'lower_priority':
        await syncEngine.updateItemPriority(itemId, 'low');
        break;
      default:
        break;
    }
  }

  final _pages = const [HomeScreen(), StatsScreen(), ProfileScreen()];

  int _pageIndexForNavIndex(int navIndex) {
    switch (navIndex) {
      case 0:
        return 0;
      case 1:
        return 1;
      case 2:
        return 2;
      default:
        return 0;
    }
  }

  int _navIndexForPageIndex(int pageIndex) {
    switch (pageIndex) {
      case 0:
        return 0;
      case 1:
        return 1;
      case 2:
        return 2;
      default:
        return 0;
    }
  }

  void _onNavTap(int index) {
    final pageIndex = _pageIndexForNavIndex(index);
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        pageIndex,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (pageIndex) {
          final navIndex = _navIndexForPageIndex(pageIndex);
          if (navIndex != _currentIndex) {
            setState(() => _currentIndex = navIndex);
          }
        },
        children: _pages,
      ),
      extendBody: true,
      bottomNavigationBar: _FloatingNavBar(
        currentIndex: _currentIndex,
        onTap: _onNavTap,
      ),
    );
  }
}

class _FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _FloatingNavBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const navHeight = 64.0;
    const bottomMargin = 20.0;

    return SizedBox(
      height: navHeight + bottomMargin,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: navHeight / 2,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      theme.colorScheme.surface.withValues(alpha: 0.8),
                      theme.colorScheme.surface.withValues(alpha: 0.9),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(36, 0, 36, bottomMargin),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Container(
                  height: navHeight,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _NavItem(
                            icon: CupertinoIcons.house,
                            activeIcon: CupertinoIcons.house_fill,
                            label: 'Home',
                            isActive: currentIndex == 0,
                            onTap: () => onTap(0),
                          ),
                          _NavItem(
                            icon: CupertinoIcons.chart_bar,
                            activeIcon: CupertinoIcons.chart_bar_fill,
                            label: 'Stats',
                            isActive: currentIndex == 1,
                            onTap: () => onTap(1),
                          ),
                          _NavItem(
                            icon: CupertinoIcons.person,
                            activeIcon: CupertinoIcons.person_fill,
                            label: 'Profile',
                            isActive: currentIndex == 2,
                            onTap: () => onTap(2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isActive
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 52,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isActive ? activeIcon : icon, size: 22, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
