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
  String? _error;
  String? _successMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
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

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Link Extension')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter the code shown on your browser extension to link it to your account.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
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
                Text(_successMessage!, style: TextStyle(color: Colors.green)),
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
