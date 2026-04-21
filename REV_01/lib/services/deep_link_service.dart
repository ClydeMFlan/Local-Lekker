import 'package:app_links/app_links.dart';
import 'dart:async';
import 'package:logger/logger.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  late final AppLinks _appLinks;
  StreamSubscription? _sub;
  final StreamController<String?> _linkController =
      StreamController<String?>.broadcast();
  final Logger _logger = Logger();

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

  void _handleDeepLink(String link) {
    _logger.i('Handling deep link: $link');

    // Parse the URL to extract authentication tokens
    final uri = Uri.parse(link);

    // Check if this is an authentication callback
    if (uri.host == 'auth' && uri.path == '/callback') {
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

      if (accessToken != null && type == 'recovery') {
        // This is a password reset link
        _handlePasswordReset(accessToken, refreshToken);
      } else if (accessToken != null && type == 'signup') {
        // This is a signup confirmation link
        _handleSignupConfirmation(accessToken, refreshToken);
      } else if (accessToken != null && type == 'invite') {
        // This is an invite link
        _handleInvite(accessToken, refreshToken);
      } else {
        _logger.w('Unknown authentication type or missing tokens');
      }
    }
  }

  String? _extractTokenFromFragment(String fragment, String tokenName) {
    final regex = RegExp('$tokenName=([^&]+)');
    final match = regex.firstMatch(fragment);
    return match?.group(1);
  }

  void _handlePasswordReset(String accessToken, String? refreshToken) {
    _logger.i('Handling password reset with token: $accessToken');

    // Store the tokens for later use in password reset flow
    // You might want to navigate to a password reset screen
    _linkController.add('password_reset:$accessToken:$refreshToken');
  }

  void _handleSignupConfirmation(String accessToken, String? refreshToken) {
    _logger.i('Handling signup confirmation with token: $accessToken');

    // Store the tokens for later use
    _linkController.add('signup_confirmation:$accessToken:$refreshToken');
  }

  void _handleInvite(String accessToken, String? refreshToken) {
    _logger.i('Handling invite with token: $accessToken');

    // Store the tokens for later use
    _linkController.add('invite:$accessToken:$refreshToken');
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
