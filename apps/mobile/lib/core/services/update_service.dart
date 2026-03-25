import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:ota_update/ota_update.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'update_service.g.dart';

@riverpod
class UpdateService extends _$UpdateService {
  final _dio = Dio();
  static const _repo = 'natanim-kemal/rem';

  @override
  void build() {}

  Future<void> checkForUpdates(
    BuildContext context, {
    bool silent = true,
  }) async {
    if (!Platform.isAndroid) return;

    try {
      final response = await _dio.get(
        'https://api.github.com/repos/$_repo/releases/latest',
      );
      final data = response.data;
      final String latestTag = data['tag_name'];

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = Version.parse(packageInfo.version);

      final latestVersionStr = latestTag.startsWith('v')
          ? latestTag.substring(1)
          : latestTag;
      final latestVersion = Version.parse(latestVersionStr);

      if (latestVersion > currentVersion) {
        final assets = data['assets'] as List;
        final asset = assets.cast<Map<String, dynamic>>().firstWhere(
          (a) => a['name'] == 'rem-android.apk',
          orElse: () => <String, dynamic>{},
        );

        if (asset.isNotEmpty && context.mounted) {
          final downloadUrl = asset['browser_download_url'];
          _showUpdateDialog(
            context,
            latestTag,
            downloadUrl,
          );
        }
      } else if (!silent && context.mounted) {
        _showNoUpdateSnackBar(context);
      }
    } catch (e) {
      if (!silent && context.mounted) {
        _showErrorSnackBar(context, e.toString());
      }
    }
  }

  void _showUpdateDialog(
    BuildContext context,
    String version,
    String url,
  ) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Update Available ($version)'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 8),
            Text('A new version is available. Would you like to update now?'),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Later'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Update Now'),
            onPressed: () {
              Navigator.pop(context);
              _startUpdate(context, url);
            },
          ),
        ],
      ),
    );
  }

  void _startUpdate(BuildContext context, String url) {
    try {
      OtaUpdate().execute(url, destinationFilename: 'rem-android.apk').listen((
        OtaEvent event,
      ) {
        if (event.status == OtaStatus.DOWNLOADING) {
          developer.log('Downloading: ${event.value}%', name: 'UpdateService');
        }
      });
    } catch (e) {
      _showErrorSnackBar(context, 'Update failed: $e');
    }
  }

  void _showNoUpdateSnackBar(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('App is up to date')));
  }

  void _showErrorSnackBar(BuildContext context, String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error checking for updates: $error')),
    );
  }
}
