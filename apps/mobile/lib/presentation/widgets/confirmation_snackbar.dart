import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

void showConfirmationSnackBar(BuildContext context, String message) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  _showStatusSnackBar(
    context,
    message,
    backgroundColor: isDark ? const Color(0xFF141414) : const Color(0xFFF2F2F7),
    accentColor: const Color(0xFF34C759),
    icon: CupertinoIcons.checkmark_circle_fill,
  );
}

void showWarningSnackBar(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  _showStatusSnackBar(
    context,
    message,
    backgroundColor: isDark ? const Color(0xFF141414) : const Color(0xFFF2F2F7),
    accentColor: Colors.orange,
    icon: CupertinoIcons.exclamationmark_triangle_fill,
    actionLabel: actionLabel,
    onAction: onAction,
  );
}

void showUndoSnackBar(
  BuildContext context,
  String message, {
  required VoidCallback onUndo,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  _showStatusSnackBar(
    context,
    message,
    backgroundColor: isDark ? const Color(0xFF141414) : const Color(0xFFF2F2F7),
    accentColor: const Color(0xFF2FBF9A),
    icon: CupertinoIcons.checkmark_circle_fill,
    actionLabel: 'UNDO',
    onAction: onUndo,
    duration: const Duration(seconds: 4),
    isUndo: true,
  );
}

void _showStatusSnackBar(
  BuildContext context,
  String message, {
  required Color backgroundColor,
  required Color accentColor,
  required IconData icon,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 2),
  bool isUndo = false,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final textColor = isDark ? Colors.white : Colors.black;
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: backgroundColor.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accentColor, size: 18),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  message,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(width: 16),
                Container(
                  decoration: BoxDecoration(
                    color: isUndo
                        ? accentColor.withValues(alpha: 0.2)
                        : isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onAction,
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        child: Text(
                          actionLabel,
                          style: TextStyle(
                            color: isUndo ? accentColor : textColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            letterSpacing: isUndo ? 0.5 : 0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      duration: duration,
      margin: const EdgeInsets.only(bottom: 15, left: 16, right: 16),
    ),
  );
}
