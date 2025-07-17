import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/manual_oauth_service.dart';
import '../services/auth_service.dart';

class OAuthCallbackPage extends StatefulWidget {
  const OAuthCallbackPage({super.key});

  @override
  State<OAuthCallbackPage> createState() => _OAuthCallbackPageState();
}

class _OAuthCallbackPageState extends State<OAuthCallbackPage> {
  bool _isProcessing = true;
  String _status = 'Processing OAuth callback...';
  String? _error;

  @override
  void initState() {
    super.initState();
    _handleCallback();
  }

  Future<void> _handleCallback() async {
    try {
      if (!kIsWeb) {
        setState(() {
          _error = 'OAuth callback page is only for web platform';
          _isProcessing = false;
        });
        return;
      }

      // Get URL parameters
      final uri = Uri.base;
      final code = uri.queryParameters['code'];
      final state = uri.queryParameters['state'];
      final error = uri.queryParameters['error'];

      debugPrint('🔍 OAuth callback URL: ${uri.toString()}');
      debugPrint('🔍 Authorization code: ${code != null ? 'present' : 'missing'}');
      debugPrint('🔍 State parameter: ${state != null ? 'present' : 'missing'}');
      debugPrint('🔍 Error parameter: $error');

      if (error != null) {
        setState(() {
          _error = 'OAuth error: $error';
          _isProcessing = false;
        });
        return;
      }

      if (code == null || state == null) {
        setState(() {
          _error = 'Missing authorization code or state parameter';
          _isProcessing = false;
        });
        return;
      }

      setState(() {
        _status = 'Exchanging authorization code for tokens...';
      });

      // Handle the OAuth callback
      final userData = await ManualOAuthService.handleCallback(
        code: code,
        state: state,
      );

      if (userData != null) {
        setState(() {
          _status = 'Completing sign in...';
        });

        // Store current user ID for session management
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('current_user_id', userData['id']);

        // Update auth service state
        if (mounted) {
          final authService = Provider.of<AuthService>(context, listen: false);
          await authService.handleManualOAuthSuccess(userData);
        }

        setState(() {
          _status = 'Sign in successful! Redirecting...';
          _isProcessing = false;
        });

        // Redirect to main app after a short delay
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/welcome');
        }
      } else {
        setState(() {
          _error = 'Failed to process OAuth callback';
          _isProcessing = false;
        });
      }
    } catch (e) {
      debugPrint('❌ OAuth callback error: $e');
      setState(() {
        _error = 'OAuth callback failed: ${e.toString()}';
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo or app icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.security,
                  size: 40,
                  color: Colors.black,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Title
              Text(
                'OAuth Authentication',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 24),
              
              // Status or error message
              if (_isProcessing) ...[
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                ),
                const SizedBox(height: 16),
                Text(
                  _status,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
              ] else if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Authentication Failed',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.red.shade300,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacementNamed('/');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Back to Login'),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        color: Colors.green,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Authentication Successful',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _status,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.green.shade300,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 32),
              
              // Additional info
              Text(
                'Please wait while we complete your authentication...',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white54,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
