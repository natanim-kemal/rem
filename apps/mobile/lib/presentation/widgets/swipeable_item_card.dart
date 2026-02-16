import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SwipeableItemCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: child,
    );
  }
}
