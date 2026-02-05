import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/sync/sync_engine.dart';
import '../../providers/data_providers.dart';

class SyncStatusIndicator extends ConsumerWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncEngine = ref.watch(syncEngineProvider);

    return StreamBuilder<SyncStatus>(
      stream: syncEngine.syncStatusStream,
      initialData: syncEngine.currentStatus,
      builder: (context, snapshot) {
        final status = snapshot.data ?? SyncStatus.idle;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _getBackgroundColor(status).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildIcon(status),
              const SizedBox(width: 6),
              Text(
                _getStatusText(status),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _getTextColor(status),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIcon(SyncStatus status) {
    switch (status) {
      case SyncStatus.syncing:
        return const SizedBox(
          width: 12,
          height: 12,
          child: CupertinoActivityIndicator(radius: 6),
        );
      case SyncStatus.offline:
        return Icon(
          CupertinoIcons.wifi_slash,
          size: 12,
          color: _getTextColor(status),
        );
      case SyncStatus.error:
        return Icon(
          CupertinoIcons.exclamationmark_triangle,
          size: 12,
          color: _getTextColor(status),
        );
      case SyncStatus.idle:
        return Icon(
          CupertinoIcons.checkmark_circle,
          size: 12,
          color: _getTextColor(status),
        );
    }
  }

  String _getStatusText(SyncStatus status) {
    switch (status) {
      case SyncStatus.syncing:
        return 'Syncing...';
      case SyncStatus.offline:
        return 'Offline';
      case SyncStatus.error:
        return 'Sync Error';
      case SyncStatus.idle:
        return 'Synced';
    }
  }

  Color _getBackgroundColor(SyncStatus status) {
    switch (status) {
      case SyncStatus.syncing:
        return Colors.blue;
      case SyncStatus.offline:
        return Colors.orange;
      case SyncStatus.error:
        return Colors.red;
      case SyncStatus.idle:
        return Colors.green;
    }
  }

  Color _getTextColor(SyncStatus status) {
    switch (status) {
      case SyncStatus.syncing:
        return Colors.blue.shade700;
      case SyncStatus.offline:
        return Colors.orange.shade700;
      case SyncStatus.error:
        return Colors.red.shade700;
      case SyncStatus.idle:
        return Colors.green.shade700;
    }
  }
}
