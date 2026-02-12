import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SwipeableItemCard extends StatelessWidget {
  final Widget child;
  final String itemId;
  final String currentStatus;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback? onDismissed;

  const SwipeableItemCard({
    super.key,
    required this.child,
    required this.itemId,
    required this.currentStatus,
    required this.onStatusChanged,
    this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRead = currentStatus == 'read';
    final isArchived = currentStatus == 'archived';

    return Dismissible(
      key: ValueKey('swipe_$itemId'),
      confirmDismiss: (direction) async {
        HapticFeedback.mediumImpact();

        if (direction == DismissDirection.startToEnd) {
          onStatusChanged(isRead ? 'unread' : 'read');
        } else if (direction == DismissDirection.endToStart) {
          onStatusChanged(isArchived ? 'unread' : 'archived');
        }

        return false;
      },
      background: _SwipeBackground(
        alignment: Alignment.centerLeft,
        color: isRead ? theme.colorScheme.onSurfaceVariant : const Color(0xFF2FBF9A),
        icon: isRead ? CupertinoIcons.envelope : CupertinoIcons.checkmark_circle,
        label: isRead ? 'Unread' : 'Read',
      ),
      secondaryBackground: _SwipeBackground(
        alignment: Alignment.centerRight,
        color: isArchived ? theme.colorScheme.onSurfaceVariant : const Color(0xFF1A8A6E),
        icon: isArchived ? CupertinoIcons.tray_arrow_up : CupertinoIcons.archivebox,
        label: isArchived ? 'Unarchive' : 'Archive',
      ),
      child: child,
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  final AlignmentGeometry alignment;
  final Color color;
  final IconData icon;
  final String label;

  const _SwipeBackground({
    required this.alignment,
    required this.color,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isLeft = alignment == Alignment.centerLeft;

    return Container(
      alignment: alignment,
      padding: EdgeInsets.only(
        left: isLeft ? 24 : 0,
        right: isLeft ? 0 : 24,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isLeft) ...[
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Icon(icon, color: color, size: 22),
          if (isLeft) ...[
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
