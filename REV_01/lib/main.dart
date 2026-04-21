import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logger/logger.dart';
import 'core/theme/theme.dart';
import 'features/auth/welcome_page.dart';
import 'services/supabase_service.dart';
import 'services/navigation_service.dart';
import 'services/deep_link_service.dart';
import 'widgets/loading_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final logger = Logger();
  logger.i('main: App starting...');

  // Load environment variables with error handling
  try {
    await dotenv.load(fileName: '.env');
    logger.i('main: Environment variables loaded successfully');
  } catch (e) {
    logger.w('Warning: Could not load .env file: ');
    logger.w('Using default environment values');
    logger.w('main: Failed to load .env file, using defaults');
  }

  logger.i('main: Initializing Supabase...');
  await SupabaseService.instance.init();
  logger.i('main: Supabase initialized');

  // Initialize deep link service
  logger.i('main: Initializing deep link service...');
  DeepLinkService().init();

  logger.i('main: Running LocalLekkerApp...');
  runApp(const LocalLekkerApp());
}

class LocalLekkerApp extends StatefulWidget {
  const LocalLekkerApp({super.key});

  @override
  State<LocalLekkerApp> createState() => _LocalLekkerAppState();
}

class _LocalLekkerAppState extends State<LocalLekkerApp>
    with WidgetsBindingObserver {
  final _logger = Logger();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _logger.d('AppLifecycle: Lifecycle observer initialized');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _logger.d('AppLifecycle: Lifecycle observer disposed');
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    _logger.d('AppLifecycle: App lifecycle state changed to: $state');

    switch (state) {
      case AppLifecycleState.paused:
        // App is in background
        _logger.d(
          'AppLifecycle: App paused (background) - preparing for potential sign-out',
        );
        break;

      case AppLifecycleState.detached:
        // App is being terminated
        _logger.d(
          'AppLifecycle: App detached (terminating) - signing out user',
        );
        await _performAutomaticSignOut();
        break;

      case AppLifecycleState.resumed:
        // App is back to foreground
        _logger.d('AppLifecycle: App resumed (foreground)');
        break;

      case AppLifecycleState.inactive:
        // App is inactive
        _logger.d('AppLifecycle: App inactive');
        break;

      case AppLifecycleState.hidden:
        // App is hidden (iOS specific)
        _logger.d('AppLifecycle: App hidden');
        break;
    }
  }

  Future<void> _performAutomaticSignOut() async {
    try {
      final currentUser = SupabaseService.instance.getCurrentUser();
      if (currentUser != null) {
        _logger.i(
          'AppLifecycle: Automatically signing out user: ${currentUser.email}',
        );
        await SupabaseService.instance.signOut();
        _logger.i('AppLifecycle: Automatic sign-out completed successfully');
      } else {
        _logger.d('AppLifecycle: No user to sign out');
      }
    } catch (e) {
      _logger.e('AppLifecycle: Error during automatic sign-out: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Local Lekker',
      theme: AppTheme.lightTheme,
      home: const AppInitializer(),
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  final _logger = Logger();
  late Future<Widget> _initialScreenFuture;

  @override
  void initState() {
    super.initState();
    _logger.d(
      'AppInitializer.initState: Starting initial screen determination...',
    );
    _initialScreenFuture = NavigationService().getInitialScreen();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _initialScreenFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Show the branded loading screen while determining initial screen
          _logger.d(
            'AppInitializer.build: ConnectionState.waiting - showing LoadingScreen',
          );
          return const LoadingScreen(showMinimumDuration: true);
        } else if (snapshot.hasError) {
          // On error, show loading screen that transitions to welcome page
          _logger.e(
            'AppInitializer.build: Error determining initial screen: ${snapshot.error}',
          );
          return const LoadingScreen(showMinimumDuration: true);
        } else {
          // Future completed, get the target screen
          final targetScreen = snapshot.data ?? const WelcomePage();
          _logger.d(
            'AppInitializer.build: Future completed, target screen: ${targetScreen.runtimeType}',
          );

          // For authenticated users, show loading screen that transitions to home
          if (targetScreen is WelcomePage) {
            // For unauthenticated users, show loading screen that transitions to welcome
            _logger.d(
              'AppInitializer.build: Showing LoadingScreen that will transition to WelcomePage',
            );
            return const LoadingScreen(showMinimumDuration: true);
          } else {
            // For authenticated users, show loading screen with auto-transition
            _logger.d(
              'AppInitializer.build: Showing LoadingScreen with auto-transition for authenticated user',
            );
            return const LoadingScreen(
              autoTransitionAfterAuth: true,
              showMinimumDuration: false,
            );
          }
        }
      },
    );
  }
}
