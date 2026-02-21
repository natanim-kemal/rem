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
            if (_isDarkMode) {
              _controller.runJavaScript(_darkModeScript);
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  void dispose() {
    _refreshAnimationController.dispose();
    super.dispose();
  }

  void _toggleDarkMode() {
    setState(() => _isDarkMode = !_isDarkMode);
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
      body: Stack(
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
