import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

void showConfirmationSnackBar(BuildContext context, String message) {
  _showStatusSnackBar(
    context,
    message,
    color: const Color(0xFF34C759),
    textColor: const Color(0xFF34C759),
    icon: CupertinoIcons.checkmark_circle_fill,
  );
}

void showWarningSnackBar(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
}) {
  _showStatusSnackBar(
    context,
    message,
    color: Colors.orange,
    textColor: Colors.orange.shade700,
    icon: CupertinoIcons.exclamationmark_triangle_fill,
    actionLabel: actionLabel,
    onAction: onAction,
  );
}

void _showStatusSnackBar(
  BuildContext context,
  String message, {
  required Color color,
  required Color textColor,
  required IconData icon,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.32),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: textColor, size: 18),
              const SizedBox(width: 8),
              Text(
                message,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: onAction,
                  child: Text(
                    actionLabel,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
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
      duration: const Duration(seconds: 2),
      margin: const EdgeInsets.only(bottom: 40),
    ),
  );
}
