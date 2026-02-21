import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebViewScreen extends StatefulWidget {
  final String url;
  final String title;

  const WebViewScreen({super.key, required this.url, required this.title});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen>
    with SingleTickerProviderStateMixin {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isDarkMode = false;
  bool _hasInvalidUrl = false;
  late AnimationController _refreshAnimationController;

  static const String _darkModeScript = '''
  (function() {
    var style = document.createElement('style');
    style.innerHTML = `
      html {
        filter: invert(1) hue-rotate(180deg);
        background: #000 !important;
      }
      img, video, picture, canvas, svg, [style*="background-image"] {
        filter: invert(1) hue-rotate(180deg);
      }
      iframe {
        filter: invert(1) hue-rotate(180deg);
      }
    `;
    style.setAttribute('data-inverted', 'true');
    document.head.appendChild(style);
  })();
''';

  static const String _lightModeScript = '''
  (function() {
    var style = document.querySelector('style[data-inverted]');
    if (style) style.remove();
  })();
''';

  @override
  void initState() {
    super.initState();
    _refreshAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
            _refreshAnimationController.reset();
          },
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
        ),
      );

    final parsedUri = Uri.tryParse(widget.url);
    if (parsedUri != null) {
      _controller.loadRequest(parsedUri);
    } else {
      setState(() => _hasInvalidUrl = true);
    }
  }

  @override
  void dispose() {
    _refreshAnimationController.dispose();
    super.dispose();
  }

  void _toggleDarkMode() {
    setState(() => _isDarkMode = !_isDarkMode);
    _applyDarkMode();
  }

  void _applyDarkMode() {
    if (_isDarkMode) {
      _controller.runJavaScript(_darkModeScript);
    } else {
      _controller.runJavaScript(_lightModeScript);
    }
  }

  void _onRefresh() {
    _refreshAnimationController.forward(from: 0);
    _controller.reload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: theme.textTheme.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          RotationTransition(
            turns: _refreshAnimationController,
            child: IconButton(
              icon: const Icon(CupertinoIcons.refresh),
              onPressed: _onRefresh,
            ),
          ),
          IconButton(
            icon: Icon(
              _isDarkMode ? CupertinoIcons.moon_fill : CupertinoIcons.moon,
            ),
            onPressed: _toggleDarkMode,
          ),
        ],
      ),
      body: _hasInvalidUrl
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      CupertinoIcons.exclamationmark_triangle,
                      size: 48,
                      color: CupertinoColors.systemRed,
                    ),
                    const SizedBox(height: 16),
                    Text('Invalid URL', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      'The URL "${widget.url}" could not be loaded.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_isLoading)
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(),
                  ),
              ],
            ),
    );
  }
}
