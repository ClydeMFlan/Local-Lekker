import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'user_signup_page.dart';
import 'trusted_partner_signup_page.dart' as trusted_partner_signup;
import '../../services/supabase_service.dart';
import 'widgets/otp_verification_dialog.dart';
import '../../widgets/loading_screen.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final _logger = Logger();
  void _showForgotPasswordFlow(BuildContext context) {
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset Password'),
        content: TextField(
          controller: emailController,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isEmpty) return;

              try {
                await SupabaseService.instance.sendPasswordResetOtp(
                  email: email,
                );
                Navigator.pop(dialogContext);
                if (context.mounted) {
                  _showPasswordResetOtpDialog(context, email);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Send Reset Code'),
          ),
        ],
      ),
    );
  }

  void _showPasswordResetOtpDialog(BuildContext context, String email) {
    final otpController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool showPasswordFields = false;
    String? errorMessage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            showPasswordFields ? 'Set New Password' : 'Enter Reset Code',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!showPasswordFields) ...[
                  Text(
                    'We sent a 6-digit code to $email',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: otpController,
                    decoration: InputDecoration(
                      labelText: 'Enter 6-digit code',
                      hintText: '000000',
                      border: const OutlineInputBorder(),
                      errorText: errorMessage,
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ] else ...[
                  TextField(
                    controller: newPasswordController,
                    decoration: const InputDecoration(
                      labelText: 'New Password',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: confirmPasswordController,
                    decoration: InputDecoration(
                      labelText: 'Confirm New Password',
                      border: const OutlineInputBorder(),
                      errorText: errorMessage,
                    ),
                    obscureText: true,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            if (!showPasswordFields)
              ElevatedButton(
                onPressed: () async {
                  final otp = otpController.text.trim();
                  if (otp.length != 6) {
                    setState(
                      () => errorMessage = 'Please enter a valid 6-digit code',
                    );
                    return;
                  }

                  try {
                    // Verify the password reset OTP
                    await SupabaseService.instance.verifyPasswordResetOtp(
                      email: email,
                      otp: otp,
                      newPassword:
                          'temp_password', // Will be updated in next step
                    );

                    setState(() {
                      showPasswordFields = true;
                      errorMessage = null;
                    });
                  } catch (e) {
                    setState(
                      () => errorMessage = e.toString().replaceAll(
                        'Exception: ',
                        '',
                      ),
                    );
                  }
                },
                child: const Text('Verify Code'),
              )
            else
              ElevatedButton(
                onPressed: () async {
                  final newPassword = newPasswordController.text;
                  final confirmPassword = confirmPasswordController.text;

                  if (newPassword.length < 6) {
                    setState(
                      () => errorMessage =
                          'Password must be at least 6 characters',
                    );
                    return;
                  }

                  if (newPassword != confirmPassword) {
                    setState(() => errorMessage = 'Passwords do not match');
                    return;
                  }

                  try {
                    // Update the password
                    await SupabaseService.instance.updatePassword(
                      newPassword: newPassword,
                    );

                    Navigator.pop(dialogContext);

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Password reset successfully!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    setState(
                      () => errorMessage = e.toString().replaceAll(
                        'Exception: ',
                        '',
                      ),
                    );
                  }
                },
                child: const Text('Reset Password'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome to Local Lekker')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => _showSignupDialog(context),
              child: const Text('Sign Up'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _showSigninDialog(context),
              child: const Text('Sign In'),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => _showOtpSigninDialog(context),
              child: const Text('Sign In with OTP'),
            ),
            const SizedBox(height: 20),
            // Show sign out button if user is already signed in
            Builder(
              builder: (context) {
                final currentUser = SupabaseService.instance.getCurrentUser();
                if (currentUser != null) {
                  return Column(
                    children: [
                      Text(
                        'Signed in as: ${currentUser.email}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () async {
                          try {
                            await SupabaseService.instance.signOut();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Signed out successfully'),
                                ),
                              );
                              // Refresh the UI
                              setState(() {});
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Sign out failed: $e')),
                              );
                            }
                          }
                        },
                        child: const Text('Sign Out'),
                      ),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            const SizedBox(height: 20),
            // Debug button to test Supabase connection
            TextButton(
              onPressed: () async {
                try {
                  final currentUser = SupabaseService.instance.getCurrentUser();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          currentUser != null
                              ? 'Connected! User: ${currentUser.email}'
                              : 'Connected! No user signed in',
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Connection test failed: $e')),
                    );
                  }
                }
              },
              child: const Text('Test Connection'),
            ),
            const SizedBox(height: 10),
            // Debug button to test token refresh
            TextButton(
              onPressed: () async {
                try {
                  await SupabaseService.instance.refreshSession();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Token refresh successful'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Token refresh failed: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Refresh Tokens'),
            ),
            const SizedBox(height: 10),
            // Debug button to check session validity
            TextButton(
              onPressed: () async {
                try {
                  final isValid = await SupabaseService.instance
                      .isSessionValid();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isValid
                              ? 'Session is valid'
                              : 'Session is invalid or expired',
                        ),
                        backgroundColor: isValid ? Colors.green : Colors.orange,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Session check failed: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Check Session'),
            ),
            const SizedBox(height: 10),
            // Debug button to test connectivity
            TextButton(
              onPressed: () async {
                try {
                  final isConnected = await SupabaseService.instance
                      .checkConnectivity();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isConnected
                              ? 'Connected to Supabase'
                              : 'Connection failed - check network/permissions',
                        ),
                        backgroundColor: isConnected
                            ? Colors.green
                            : Colors.red,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Connectivity check failed: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Test Connectivity'),
            ),
            const SizedBox(height: 10),
            // Debug button to test database trigger functionality
            TextButton(
              onPressed: () async {
                try {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Testing trigger...')),
                  );

                  final result = await SupabaseService.instance
                      .testTriggerFunctionality();

                  if (mounted) {
                    showDialog(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Trigger Test Results'),
                        content: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Success: ${result['success']}'),
                              const SizedBox(height: 8),
                              Text(
                                'Profile Created: ${result['profile_created']}',
                              ),
                              Text(
                                'Membership Created: ${result['membership_created']}',
                              ),
                              if (result['error'] != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Error: ${result['error']}',
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ],
                              if (result['profile_data'] != null) ...[
                                const SizedBox(height: 8),
                                const Text(
                                  'Profile Data:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(result['profile_data'].toString()),
                              ],
                              if (result['membership_data'] != null) ...[
                                const SizedBox(height: 8),
                                const Text(
                                  'Membership Data:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(result['membership_data'].toString()),
                              ],
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Trigger test failed: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Test Database Trigger'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSignupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Account Type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('User'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UserSignupPage(),
                  ),
                );
              },
            ),
            ListTile(
              title: const Text('Merchant'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const trusted_partner_signup.TrustedPartnerSignupPage(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Start smooth sign-in transition: Show loading screen then let app handle navigation
  Future<void> _startSmoothSignInTransition(
    BuildContext parentContext,
    BuildContext dialogContext,
    String userId,
  ) async {
    _logger.i('Starting sign-in transition for user $userId');

    // Close dialog immediately
    if (Navigator.canPop(dialogContext)) {
      Navigator.pop(dialogContext);
    }

    // Show success message
    if (mounted) {
      ScaffoldMessenger.of(parentContext).showSnackBar(
        const SnackBar(
          content: Text('Sign in successful!'),
          backgroundColor: Colors.green,
        ),
      );
    }

    // Show the Local Lekker loading screen with auto-transition enabled
    _logger.i('Showing Local Lekker loading screen with auto-transition');
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        parentContext,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const LoadingScreen(autoTransitionAfterAuth: true),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 600),
          fullscreenDialog: false,
        ),
        (route) => false, // Remove all previous routes
      );
    }
  }

  void _showSigninDialog(BuildContext context) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final parentContext = context;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign In'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close sign in dialog
              _showForgotPasswordFlow(context);
            },
            child: const Text('Forgot Password?'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text;
              final password = passwordController.text;

              if (email.isEmpty || password.isEmpty) {
                if (mounted) {
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    const SnackBar(content: Text('Please fill in all fields')),
                  );
                }
                return;
              }

              // Check if user is already signed in
              final currentUser = SupabaseService.instance.getCurrentUser();
              if (currentUser != null && currentUser.email == email) {
                _logger.i('User already signed in: ${currentUser.id}');
                await _startSmoothSignInTransition(
                  parentContext,
                  dialogContext,
                  currentUser.id,
                );
                return;
              }

              try {
                _logger.i('Attempting sign in for email: $email');
                final response = await SupabaseService.instance.signIn(
                  email: email,
                  password: password,
                );
                _logger.i(
                  'Sign in response received, user: ${response.user?.id}',
                );

                if (response.user != null) {
                  // Start the smooth transition flow
                  await _startSmoothSignInTransition(
                    parentContext,
                    dialogContext,
                    response.user!.id,
                  );
                } else {
                  _logger.w('Sign in response has no user');
                  try {
                    if (mounted) {
                      ScaffoldMessenger.of(parentContext).showSnackBar(
                        const SnackBar(
                          content: Text('Sign in failed - no user returned'),
                        ),
                      );
                    }
                  } catch (e) {
                    // Context might be invalid
                  }
                }
              } catch (e) {
                _logger.e('Sign in error: $e');
                String errorMessage = 'Sign in error: ${e.toString()}';
                if (e.toString().contains('Invalid login credentials')) {
                  errorMessage = 'Invalid email or password';
                } else if (e.toString().contains('Email not confirmed')) {
                  errorMessage =
                      'Please check your email and confirm your account';
                } else if (e.toString().contains(
                  'over_email_send_rate_limit',
                )) {
                  errorMessage =
                      'Too many attempts. Please wait before trying again';
                }
                try {
                  if (mounted) {
                    ScaffoldMessenger.of(
                      parentContext,
                    ).showSnackBar(SnackBar(content: Text(errorMessage)));
                  }
                } catch (e) {
                  // Context might be invalid
                }
              }
            },
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }

  void _showOtpSigninDialog(BuildContext context) {
    final emailController = TextEditingController();
    final parentContext = context;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign In with OTP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'Enter your email address',
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 10),
            const Text(
              'We\'ll send a 6-digit code to your email for verification.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isEmpty) {
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  const SnackBar(content: Text('Please enter your email')),
                );
                return;
              }

              try {
                Navigator.pop(dialogContext); // Close email dialog

                // Show OTP verification dialog with merchant check
                if (mounted) {
                  showDialog(
                    context: parentContext,
                    barrierDismissible: false,
                    builder: (c) => OtpVerificationDialog(
                      email: email,
                      isForSignIn: true,
                      onVerificationSuccess: (String? userId) async {
                        // Start smooth sign-in transition (dialog will be closed by the method)
                        await _startSmoothSignInTransition(
                          parentContext,
                          parentContext, // Use parentContext as dialogContext since OTP dialog is modal
                          userId!,
                        );
                      },
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(
                  parentContext,
                ).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Send OTP'),
          ),
        ],
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          const SizedBox(width: 8),
          // Logout button with confirmation to avoid accidental logouts.
          IconButton(
            tooltip: 'Logout',
            onPressed: () async {
              final should = await showDialog<bool>(
                context: context,
                builder: (d) => AlertDialog(
                  title: const Text('Confirm logout'),
                  content: const Text(
                    'Are you sure you want to sign out from this device?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(d, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(d, true),
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              );

              if (should == true) {
                await SupabaseService.instance.signOut();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const WelcomePage()),
                  (route) => false, // Remove all previous routes
                );
              }
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: const Center(child: Text('Welcome to Local Lekker!')),
    );
  }
}
