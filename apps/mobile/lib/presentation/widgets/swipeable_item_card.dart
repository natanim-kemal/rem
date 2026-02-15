import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SwipeableItemCard extends StatefulWidget {
  final Widget child;
  final String itemId;
  final String currentStatus;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback? onDismissed;
  final VoidCallback? onTap;

  const SwipeableItemCard({
    super.key,
    required this.child,
    required this.itemId,
    required this.currentStatus,
    required this.onStatusChanged,
    this.onDismissed,
    this.onTap,
  });

  @override
  State<SwipeableItemCard> createState() => _SwipeableItemCardState();
}

class _SwipeableItemCardState extends State<SwipeableItemCard> {
  Offset? _downPos;
  DateTime? _downTime;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRead = widget.currentStatus == 'read';
    final isArchived = widget.currentStatus == 'archived';

    return Listener(
      onPointerDown: (e) {
        _downPos = e.position;
        _downTime = DateTime.now();
      },
      onPointerUp: (e) {
        if (_downPos != null && _downTime != null) {
          final dist = (e.position - _downPos!).distance;
          final duration = DateTime.now().difference(_downTime!);
          // Treat as a tap if finger moved < 20px and held < 300ms
          if (dist < 20 && duration.inMilliseconds < 300) {
            widget.onTap?.call();
          }
        }
        _downPos = null;
        _downTime = null;
      },
      onPointerCancel: (_) {
        _downPos = null;
        _downTime = null;
      },
      child: Dismissible(
        key: ValueKey('swipe_${widget.itemId}'),
        confirmDismiss: (direction) async {
          HapticFeedback.mediumImpact();

          if (direction == DismissDirection.startToEnd) {
            widget.onStatusChanged(isRead ? 'unread' : 'read');
          } else if (direction == DismissDirection.endToStart) {
            widget.onStatusChanged(isArchived ? 'unread' : 'archived');
          }

          return false;
        },
        background: _SwipeBackground(
          alignment: Alignment.centerLeft,
          color: isRead
              ? theme.colorScheme.onSurfaceVariant
              : const Color(0xFF2FBF9A),
          icon: isRead
              ? CupertinoIcons.envelope
              : CupertinoIcons.checkmark_circle,
          label: isRead ? 'Unread' : 'Read',
        ),
        secondaryBackground: _SwipeBackground(
          alignment: Alignment.centerRight,
          color: isArchived
              ? theme.colorScheme.onSurfaceVariant
              : const Color(0xFF1A8A6E),
          icon: isArchived
              ? CupertinoIcons.tray_arrow_up
              : CupertinoIcons.archivebox,
          label: isArchived ? 'Unarchive' : 'Archive',
        ),
        child: widget.child,
      ),
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
      padding: EdgeInsets.only(left: isLeft ? 24 : 0, right: isLeft ? 0 : 24),
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
