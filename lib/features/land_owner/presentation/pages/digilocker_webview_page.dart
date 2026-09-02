import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// In-app DigiLocker session — portal login (sandbox) or OAuth (production).
class DigiLockerWebViewPage extends StatefulWidget {
  const DigiLockerWebViewPage({
    super.key,
    required this.initialUrl,
    required this.isSandbox,
    this.redirectUriPrefix,
    this.expectedState,
  });

  final String initialUrl;
  final bool isSandbox;
  final String? redirectUriPrefix;
  final String? expectedState;

  @override
  State<DigiLockerWebViewPage> createState() => _DigiLockerWebViewPageState();
}

class _DigiLockerWebViewPageState extends State<DigiLockerWebViewPage> {
  WebViewController? _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _openExternal();
      return;
    }
    _initWebView();
  }

  Future<void> _openExternal() async {
    final uri = Uri.parse(widget.initialUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    if (mounted) Navigator.pop(context);
  }

  void _initWebView() {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _loading = true),
          onPageFinished: (_) => setState(() => _loading = false),
          onWebResourceError: (err) {
            if (mounted) {
              setState(() => _error = err.description);
            }
          },
          onNavigationRequest: (request) {
            final url = request.url;
            final prefix = widget.redirectUriPrefix;
            if (prefix != null &&
                prefix.isNotEmpty &&
                url.toLowerCase().startsWith(prefix.toLowerCase())) {
              _handleOAuthRedirect(url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.initialUrl));

    _controller = controller;
  }

  void _handleOAuthRedirect(String url) {
    final uri = Uri.parse(url);
    final code = uri.queryParameters['code'];
    final state = uri.queryParameters['state'];
    final error = uri.queryParameters['error'];

    if (error != null && error.isNotEmpty) {
      if (mounted) {
        Navigator.pop(
          context,
          DigiLockerWebViewResult.error(
            uri.queryParameters['error_description'] ?? error,
          ),
        );
      }
      return;
    }

    if (code == null || code.isEmpty) {
      if (mounted) {
        Navigator.pop(
          context,
          const DigiLockerWebViewResult.error('No authorization code received.'),
        );
      }
      return;
    }

    final expected = widget.expectedState;
    if (expected != null &&
        expected.isNotEmpty &&
        state != null &&
        state.isNotEmpty &&
        state != expected) {
      if (mounted) {
        Navigator.pop(
          context,
          const DigiLockerWebViewResult.error('Login state mismatch. Please try again.'),
        );
      }
      return;
    }

    if (mounted) {
      Navigator.pop(context, DigiLockerWebViewResult.code(code));
    }
  }

  void _closeSandbox() {
    Navigator.pop(context, const DigiLockerWebViewResult.done());
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('DigiLocker'),
        actions: [
          if (widget.isSandbox)
            TextButton(
              onPressed: _closeSandbox,
              child: const Text('Done'),
            ),
        ],
      ),
      body: Stack(
        children: [
          if (_controller != null) WebViewWidget(controller: _controller!),
          if (_loading)
            const LinearProgressIndicator(minHeight: 2),
          if (_error != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: Material(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Result from [DigiLockerWebViewPage].
class DigiLockerWebViewResult {
  const DigiLockerWebViewResult._({
    this.authorizationCode,
    this.errorMessage,
    this.completed = false,
  });

  const DigiLockerWebViewResult.code(String code)
      : this._(authorizationCode: code);

  const DigiLockerWebViewResult.error(String message)
      : this._(errorMessage: message);

  const DigiLockerWebViewResult.done() : this._(completed: true);

  final String? authorizationCode;
  final String? errorMessage;
  final bool completed;

  bool get isSuccess => authorizationCode != null && authorizationCode!.isNotEmpty;
}
