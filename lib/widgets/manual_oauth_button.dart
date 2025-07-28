import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class ManualOAuthButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool enabled;

  const ManualOAuthButton({
    super.key,
    this.text = 'Sign in with Google',
    this.onPressed,
    this.enabled = true,
  });

  @override
  State<ManualOAuthButton> createState() => _ManualOAuthButtonState();
}

class _ManualOAuthButtonState extends State<ManualOAuthButton> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        final isLoading = _isLoading || authService.loading;

        return SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: widget.enabled && !isLoading ? _handleSignIn : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black54),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Google logo
                      Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          image: DecorationImage(
                            image: NetworkImage(
                              'https://developers.google.com/identity/images/g-logo.png',
                            ),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        widget.text,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Future<void> _handleSignIn() async {
    if (widget.onPressed != null) {
      widget.onPressed!();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      
      if (kIsWeb) {
        // For web, use manual OAuth
        await authService.signInWithManualOAuth();
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Redirecting to Google for authentication...'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        // For mobile, show not implemented message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mobile OAuth not yet implemented'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Manual OAuth button error: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign in failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

/// Alternative OAuth button with custom styling
class CustomManualOAuthButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool enabled;
  final Color? backgroundColor;
  final Color? textColor;
  final IconData? icon;

  const CustomManualOAuthButton({
    super.key,
    this.text = 'Continue with Google',
    this.onPressed,
    this.enabled = true,
    this.backgroundColor,
    this.textColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        final isLoading = authService.loading;

        return Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: backgroundColor ?? Colors.amber,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: enabled && !isLoading ? _handleSignIn : null,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: isLoading
                    ? const Center(
                        child: SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                          ),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (icon != null) ...[
                            Icon(
                              icon,
                              color: textColor ?? Colors.black,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                          ],
                          Text(
                            text,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: textColor ?? Colors.black,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleSignIn() async {
    if (onPressed != null) {
      onPressed!();
      return;
    }

    // This would need context, so for now just call the callback
    debugPrint('🔐 Custom OAuth button pressed');
  }
}

/// OAuth status indicator widget
class OAuthStatusWidget extends StatelessWidget {
  const OAuthStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        if (authService.loading) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Authenticating...'),
              ],
            ),
          );
        }

        if (authService.isAuthenticated) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 16),
                const SizedBox(width: 12),
                Text('Signed in as ${authService.currentUser?.email ?? 'User'}'),
              ],
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}
