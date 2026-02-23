import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';

class LinkExtensionScreen extends ConsumerStatefulWidget {
  const LinkExtensionScreen({super.key});

  @override
  ConsumerState<LinkExtensionScreen> createState() =>
      _LinkExtensionScreenState();
}

class _LinkExtensionScreenState extends ConsumerState<LinkExtensionScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  bool _isRevoking = false;
  String? _error;
  String? _successMessage;
  List<dynamic> _linkedDevices = [];

  @override
  void initState() {
    super.initState();
    _loadLinkedDevices();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadLinkedDevices() async {
    try {
      final convex = ref.read(convexClientProvider);
      final devices = await convex.query('pairing:getLinkedDevices');
      setState(() {
        _linkedDevices = devices ?? [];
      });
    } catch (e) {
      return;
    }
  }

  Future<void> _approvePairing() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _error = 'Please enter a code');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _successMessage = null;
    });

    try {
      final convex = ref.read(convexClientProvider);
      final token = convex.authToken;

      if (token == null) {
        setState(() {
          _isLoading = false;
          _error = 'You must be signed in to link an extension.';
        });
        return;
      }

      await convex.mutation('pairing:approvePairing', {
        'code': code,
        'deviceName': 'Browser Extension',
        'token': token,
      });

      setState(() {
        _isLoading = false;
        _successMessage = 'Device linked successfully!';
      });

      _codeController.clear();
      await _loadLinkedDevices();

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() => _successMessage = null);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _revokeAllDevices() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke All Devices'),
        content: const Text(
          'This will disconnect all linked browser extensions. They will need to be re-linked to access your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Revoke All',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isRevoking = true);
    try {
      final convex = ref.read(convexClientProvider);
      await convex.mutation('pairing:revokeAllDevices');
      await _loadLinkedDevices();
      setState(() {
        _isRevoking = false;
        _successMessage = 'All devices revoked successfully';
      });
    } catch (e) {
      setState(() {
        _isRevoking = false;
        _error = e.toString();
      });
    }
  }

  String _formatExpiry(int expiryTimestamp) {
    final expiry = DateTime.fromMillisecondsSinceEpoch(expiryTimestamp);
    final now = DateTime.now();
    final diff = expiry.difference(now);

    if (diff.isNegative) return 'Expired';
    if (diff.inDays > 0) return '${diff.inDays}d left';
    if (diff.inHours > 0) return '${diff.inHours}h left';
    return '${diff.inMinutes}m left';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Link Extension')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadLinkedDevices,
          child: ListView(
            padding: const EdgeInsets.all(24.0),
            children: [
              if (_linkedDevices.isNotEmpty) ...[
                Text(
                  'Connected Devices',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      ...List.generate(_linkedDevices.length, (index) {
                        final device = _linkedDevices[index];
                        return ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 20,
                            ),
                          ),
                          title: const Text('Browser Extension'),
                          subtitle: Text(
                            'Expires: ${_formatExpiry(device['expiresAt'] as int)}',
                          ),
                        );
                      }),
                      const Divider(height: 1),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.error.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.delete_outline,
                            color: Theme.of(context).colorScheme.error,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          'Revoke All Devices',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        onTap: _isRevoking ? null : _revokeAllDevices,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 24),
              ],
              Text(
                'Link New Device',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'Enter the code shown on your browser extension to link it to your account.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Pairing Code',
                  hintText: 'XXXX-XXXX',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.link),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (_successMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _successMessage!,
                  style: const TextStyle(color: Colors.green),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _approvePairing,
                  child: _isLoading
                      ? const CupertinoActivityIndicator()
                      : const Text('Link Device'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
