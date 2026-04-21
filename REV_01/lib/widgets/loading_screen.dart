import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../services/navigation_service.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({
    super.key,
    this.autoTransitionAfterAuth = false,
    this.showMinimumDuration = true,
  });

  final bool autoTransitionAfterAuth;
  final bool showMinimumDuration;

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with TickerProviderStateMixin {
  final _logger = Logger();
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _backgroundController;
  late Animation<double> _logoAnimation;
  late Animation<double> _backgroundAnimation;

  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _logger.d('LoadingScreen: initState - Loading screen created');

    // Logo bounce animation
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _logoAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    // Text typing animation
    _textController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Background pulsing animation
    _backgroundController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _backgroundAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _backgroundController, curve: Curves.easeInOut),
    );

    // Start animations
    _logger.d('LoadingScreen: Starting logo animation');
    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!_isDisposed && mounted) {
        _logger.d('LoadingScreen: Starting text animation');
        _textController.forward();

        // If auto-transition is enabled, start the transition after text animation
        if (widget.autoTransitionAfterAuth) {
          _logger.d(
            'LoadingScreen: Auto-transition enabled, scheduling transition',
          );
          Future.delayed(const Duration(milliseconds: 1200), () {
            if (!_isDisposed && mounted) {
              _logger.d(
                'LoadingScreen: Auto-transition timer fired, performing transition',
              );
              _performAutoTransition(context);
            } else {
              _logger.d(
                'LoadingScreen: Auto-transition cancelled - disposed: $_isDisposed, mounted: $mounted',
              );
            }
          });
        } else if (widget.showMinimumDuration) {
          // For initial app loading, show minimum duration then transition to default screen
          Future.delayed(const Duration(milliseconds: 2000), () {
            if (!_isDisposed && mounted) {
              _logger.d(
                'LoadingScreen: Minimum duration reached, transitioning to default screen',
              );
              _performTransitionToDefault(context);
            }
          });
        }
      }
    });
  }

  Future<void> _performAutoTransition(BuildContext context) async {
    _logger.d('LoadingScreen: Performing auto-transition after authentication');

    try {
      // Use NavigationService to determine the appropriate home page based on member role
      if (mounted) {
        _logger.d(
          'LoadingScreen: Determining appropriate home page based on member role...',
        );

        // Import NavigationService at the top of the file
        final navigationService = NavigationService();
        final targetScreen = await navigationService.getInitialScreen();

        _logger.d(
          'LoadingScreen: Navigating to ${targetScreen.runtimeType} with fade transition',
        );

        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                targetScreen,
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
        _logger.d('LoadingScreen: Auto-transition completed successfully');
      } else {
        _logger.d('LoadingScreen: Auto-transition cancelled - not mounted');
      }
    } catch (e) {
      _logger.e('LoadingScreen: Error during auto-transition: $e');
      // Fallback: just pop the loading screen
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _performTransitionToDefault(BuildContext context) async {
    _logger.d(
      'LoadingScreen: Performing transition to default screen based on auth status',
    );

    try {
      if (mounted) {
        // Use NavigationService to determine the appropriate screen based on auth and role
        final navigationService = NavigationService();
        final targetScreen = await navigationService.getInitialScreen();

        _logger.d(
          'LoadingScreen: Navigating to ${targetScreen.runtimeType} with fade transition',
        );

        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                targetScreen,
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
        _logger.d(
          'LoadingScreen: Default screen transition completed successfully',
        );
      } else {
        _logger.d(
          'LoadingScreen: Default screen transition cancelled - not mounted',
        );
      }
    } catch (e) {
      _logger.e('LoadingScreen: Error during default screen transition: $e');
      // Fallback: just pop the loading screen
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  void dispose() {
    _logger.d('LoadingScreen: dispose - Loading screen being disposed');
    _isDisposed = true;
    _logoController.dispose();
    _textController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _logger.d('LoadingScreen: build - Loading screen rendering');
    return Scaffold(
      body: AnimatedBuilder(
        animation: _backgroundAnimation,
        builder: (context, child) {
          return Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/locallekker_background.png'),
                fit: BoxFit.cover,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo animation
                  AnimatedBuilder(
                    animation: _logoAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _logoAnimation.value,
                        child: Container(
                          width: 250, // Increased from 200 to 250
                          height: 250, // Increased from 200 to 250
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/locallekker_logo.png',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                // Fallback to icon if image fails to load
                                return const Icon(
                                  Icons.restaurant,
                                  size: 100, // Increased from 80 to 100
                                  color: Color(0xFF4CAF50),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 40),

                  // Loading dots animation
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (index) {
                      return AnimatedBuilder(
                        animation: _backgroundController,
                        builder: (context, child) {
                          final delay = index * 0.2;
                          final animation = Tween<double>(begin: 0.3, end: 1.0)
                              .animate(
                                CurvedAnimation(
                                  parent: _backgroundController,
                                  curve: Interval(
                                    delay,
                                    delay + 0.4,
                                    curve: Curves.easeInOut,
                                  ),
                                ),
                              );

                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(animation.value),
                              shape: BoxShape.circle,
                            ),
                          );
                        },
                      );
                    }),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Wrapper widget for smooth page transitions with loading screen
class LoadingTransition extends StatelessWidget {
  final Widget child;

  const LoadingTransition({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return child;
  }

  /// Navigate with loading screen transition
  static Future<void> navigateWithLoading(
    BuildContext context,
    Future<Widget> Function() screenBuilder,
  ) async {
    // Show loading screen
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const LoadingScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );

    try {
      // Build the target screen
      final targetScreen = await screenBuilder();

      // Replace loading screen with target screen
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => targetScreen,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    } catch (e) {
      // On error, go back to previous screen
      Navigator.pop(context);
      rethrow;
    }
  }
}
