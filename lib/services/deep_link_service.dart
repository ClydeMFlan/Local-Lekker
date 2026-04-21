import 'package:app_links/app_links.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  late final AppLinks _appLinks;
  StreamSubscription? _sub;
  final StreamController<String?> _linkController =
      StreamController<String?>.broadcast();

  Stream<String?> get linkStream => _linkController.stream;

  void init() {
    _appLinks = AppLinks();

    // Handle initial link when app is launched from deep link
    _appLinks.getInitialLink().then((link) {
      if (link != null) {
        _handleDeepLink(link.toString());
      }
    });

    // Handle deep links when app is already running
    _sub = _appLinks.uriLinkStream.listen((link) {
      _handleDeepLink(link.toString());
    });
  }

  // Check for initial link synchronously - returns password reset data if present
  // Returns either {'code': 'xxx'} for PKCE flow or {'accessToken': 'xxx', 'refreshToken': 'xxx'} for token flow
  Future<Map<String, String>?> checkForPasswordResetLink() async {
    try {
      if (kDebugMode) {
        print('DeepLinkService: Checking for password reset link...');
      }

      final link = await _appLinks.getInitialLink();

      if (kDebugMode) {
        print('DeepLinkService: Initial link = $link');
      }

      if (link == null) return null;

      final uri = Uri.parse(link.toString());

      if (kDebugMode) {
        print(
          'DeepLinkService: Parsed URI - host: ${uri.host}, path: ${uri.path}',
        );
        print('DeepLinkService: URI fragment: ${uri.fragment}');
        print('DeepLinkService: URI query params: ${uri.queryParameters}');
      }

      // Check if this is an auth callback
      if (uri.host == 'auth' && uri.path == '/callback') {
        // Check for PKCE code first (password reset uses this flow)
        final code = uri.queryParameters['code'];

        if (code != null) {
          if (kDebugMode) {
            print('DeepLinkService: ✅ PKCE password reset code detected!');
          }
          return {'code': code};
        }

        // Fall back to direct token flow (legacy)
        final accessToken = uri.fragment.contains('access_token=')
            ? _extractTokenFromFragment(uri.fragment, 'access_token')
            : uri.queryParameters['access_token'];

        final refreshToken = uri.fragment.contains('refresh_token=')
            ? _extractTokenFromFragment(uri.fragment, 'refresh_token')
            : uri.queryParameters['refresh_token'];

        final type = uri.fragment.contains('type=')
            ? _extractTokenFromFragment(uri.fragment, 'type')
            : uri.queryParameters['type'];

        if (kDebugMode) {
          print(
            'DeepLinkService: Extracted - accessToken: ${accessToken != null}, type: $type',
          );
        }

        // Check if this is a password reset link (recovery or magiclink)
        if (accessToken != null &&
            (type == 'recovery' || type == 'magiclink')) {
          if (kDebugMode) {
            print('DeepLinkService: ✅ Password reset link detected!');
          }
          return {
            'accessToken': accessToken,
            if (refreshToken != null) 'refreshToken': refreshToken,
          };
        } else {
          if (kDebugMode) {
            print('DeepLinkService: ❌ Not a password reset link (type: $type)');
          }
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking for password reset link: $e');
      }
      return null;
    }
  }

  void _handleDeepLink(String link) {
    if (kDebugMode) {
      print('DeepLinkService: Handling deep link: $link');
    }

    // Parse the URL to extract authentication tokens
    final uri = Uri.parse(link);

    // Check if this is an authentication callback
    if (uri.host == 'auth' && uri.path == '/callback') {
      // Check for PKCE code parameter (password recovery uses this)
      final code = uri.queryParameters['code'];

      if (code != null) {
        if (kDebugMode) {
          print(
            'DeepLinkService: PKCE code detected - triggering password reset',
          );
        }
        // This is a password recovery PKCE flow
        _linkController.add('password_reset_pkce:$code');
        return;
      }

      // Extract tokens from URL fragments or query parameters
      final accessToken = uri.fragment.contains('access_token=')
          ? _extractTokenFromFragment(uri.fragment, 'access_token')
          : uri.queryParameters['access_token'];

      final refreshToken = uri.fragment.contains('refresh_token=')
          ? _extractTokenFromFragment(uri.fragment, 'refresh_token')
          : uri.queryParameters['refresh_token'];

      final type = uri.fragment.contains('type=')
          ? _extractTokenFromFragment(uri.fragment, 'type')
          : uri.queryParameters['type'];

      if (kDebugMode) {
        print(
          'DeepLinkService: Parsed tokens - accessToken: ${accessToken != null}, type: $type, refreshToken: ${refreshToken != null}',
        );
      }

      if (accessToken != null && (type == 'recovery' || type == 'magiclink')) {
        // This is a password reset link (both recovery and magiclink types work for password reset)
        _handlePasswordReset(accessToken, refreshToken);
      } else if (accessToken != null && type == 'signup') {
        // This is a signup confirmation link
        _handleSignupConfirmation(accessToken, refreshToken);
      } else if (accessToken != null && type == 'invite') {
        // This is an invite link
        _handleInvite(accessToken, refreshToken);
      } else if (accessToken != null) {
        // If we have access token but no type, assume recovery (for deep link scheme case)
        if (kDebugMode) {
          print(
            'DeepLinkService: Access token present but no type - assuming recovery',
          );
        }
        _handlePasswordReset(accessToken, refreshToken);
      } else {
        if (kDebugMode) {
          print(
            'DeepLinkService: Unknown authentication type or missing tokens',
          );
        }
      }
    }
    // Check if this is a Paystack payment callback
    else if (uri.scheme == 'locallekker' &&
        uri.host == 'payment' &&
        uri.path == '/callback') {
      // This is a Paystack payment callback
      _handlePaymentCallback(uri);
    }
  }

  String? _extractTokenFromFragment(String fragment, String tokenName) {
    final regex = RegExp('$tokenName=([^&]+)');
    final match = regex.firstMatch(fragment);
    return match?.group(1);
  }

  void _handlePasswordReset(String accessToken, String? refreshToken) {
    if (kDebugMode) {
      print(
        'DeepLinkService: Handling password reset with token: $accessToken',
      );
    }

    // Store the tokens for later use in password reset flow
    // You might want to navigate to a password reset screen
    _linkController.add('password_reset:$accessToken:$refreshToken');
  }

  void _handleSignupConfirmation(String accessToken, String? refreshToken) {
    if (kDebugMode) {
      print(
        'DeepLinkService: Handling signup confirmation with token: $accessToken',
      );
    }

    // Store the tokens for later use
    _linkController.add('signup_confirmation:$accessToken:$refreshToken');
  }

  void _handleInvite(String accessToken, String? refreshToken) {
    if (kDebugMode) {
      print('DeepLinkService: Handling invite with token: $accessToken');
    }

    // Store the tokens for later use
    _linkController.add('invite:$accessToken:$refreshToken');
  }

  void _handlePaymentCallback(Uri uri) {
    if (kDebugMode) {
      print('DeepLinkService: Handling Paystack payment callback: $uri');
    }

    // Extract payment reference from query parameters
    final reference = uri.queryParameters['reference'];
    final trxref = uri.queryParameters['trxref'];

    if (reference != null || trxref != null) {
      // Notify listeners about payment callback
      _linkController.add('payment_callback:${reference ?? trxref}');
    } else {
      if (kDebugMode) {
        print('DeepLinkService: Payment callback missing reference parameter');
      }
    }
  }

  void dispose() {
    _sub?.cancel();
    _linkController.close();
  }

  // Method to manually handle a deep link (useful for testing)
  void handleManualLink(String link) {
    _handleDeepLink(link);
  }
}
