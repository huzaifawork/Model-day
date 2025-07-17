import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/manual_oauth_service.dart';

class OAuthTestPage extends StatefulWidget {
  const OAuthTestPage({super.key});

  @override
  State<OAuthTestPage> createState() => _OAuthTestPageState();
}

class _OAuthTestPageState extends State<OAuthTestPage> {
  String _status = 'Ready to test OAuth';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('OAuth Test Page'),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[700]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'OAuth Status',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _status,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Configuration Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Configuration',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Client ID: 373125623062-6tlqmnc91u973gtdivp9urfilorekb3e.apps.googleusercontent.com',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Redirect URI: http://localhost:3000/auth/callback',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Scopes: openid, email, profile, calendar',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Test Buttons
            
            ElevatedButton(
              onPressed: _isLoading ? null : _testDirectOAuth,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                      ),
                    )
                  : const Text('Test Direct OAuth Flow'),
            ),

            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: _generateOAuthUrl,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Generate OAuth URL (Debug)'),
            ),
            
            const SizedBox(height: 16),
            
            ElevatedButton(
              onPressed: _checkCurrentUser,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Check Current User'),
            ),
            
            const SizedBox(height: 16),
            
            ElevatedButton(
              onPressed: _clearUserData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Clear User Data'),
            ),
            
            const SizedBox(height: 24),
            
            // Instructions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.yellow.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.yellow.withValues(alpha: 0.3)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Instructions',
                    style: TextStyle(
                      color: Colors.yellow,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '1. Make sure you have configured the redirect URI in Google Cloud Console\n'
                    '2. Click "Test Manual OAuth Sign-In" to start the flow\n'
                    '3. When you see "Google hasn\'t verified this app", click "Advanced"\n'
                    '4. Click "Go to ModelDay (unsafe)" to continue\n'
                    '5. Grant the requested permissions\n'
                    '6. You should be redirected back to the app',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testDirectOAuth() async {
    setState(() {
      _isLoading = true;
      _status = 'Starting direct OAuth flow...';
    });

    try {
      final result = await ManualOAuthService.signInWeb();
      setState(() {
        _status = 'OAuth flow initiated: ${result.toString()}';
      });
    } catch (e) {
      setState(() {
        _status = 'OAuth flow failed: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkCurrentUser() async {
    setState(() {
      _status = 'Checking current user...';
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.currentUser;
      final isManualOAuth = await authService.isManualOAuthUser();
      
      setState(() {
        _status = 'Current user: ${currentUser?.email ?? 'None'}\n'
                 'Manual OAuth: $isManualOAuth\n'
                 'Authenticated: ${authService.isAuthenticated}';
      });
    } catch (e) {
      setState(() {
        _status = 'Error checking user: $e';
      });
    }
  }

  Future<void> _clearUserData() async {
    setState(() {
      _status = 'Clearing user data...';
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signOut();

      setState(() {
        _status = 'User data cleared successfully';
      });
    } catch (e) {
      setState(() {
        _status = 'Error clearing user data: $e';
      });
    }
  }

  Future<void> _generateOAuthUrl() async {
    setState(() {
      _status = 'Generating OAuth URL...';
    });

    try {
      // Generate OAuth URL manually for debugging
      const clientId = '373125623062-6tlqmnc91u973gtdivp9urfilorekb3e.apps.googleusercontent.com';
      const redirectUri = 'http://localhost:3000/auth/callback';
      const scopes = 'openid email profile https://www.googleapis.com/auth/calendar';
      final state = DateTime.now().millisecondsSinceEpoch.toString();

      final params = {
        'client_id': clientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': scopes,
        'state': state,
        'access_type': 'offline',
        'prompt': 'consent',
        'include_granted_scopes': 'true',
      };

      final uri = Uri.parse('https://accounts.google.com/o/oauth2/v2/auth').replace(queryParameters: params);
      final oauthUrl = uri.toString();

      setState(() {
        _status = 'OAuth URL Generated!\n\n'
                 'COPY THIS URL AND PASTE IN NEW BROWSER TAB:\n\n'
                 '$oauthUrl\n\n'
                 'This will help debug if the issue is with URL generation or launching.';
      });

      debugPrint('🔗 MANUAL OAUTH URL: $oauthUrl');

    } catch (e) {
      setState(() {
        _status = 'Error generating OAuth URL: $e';
      });
    }
  }
}
