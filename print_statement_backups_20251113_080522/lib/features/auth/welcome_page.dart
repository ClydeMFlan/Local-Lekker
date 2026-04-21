import 'package:flutter/material.dart';
import 'dart:async';
import 'members_signup_page.dart';
import 'trusted_partner_signup_page.dart' as trusted_partner_signup;
import '../../services/supabase_service.dart';
import 'widgets/otp_verification_dialog.dart';
import '../../widgets/loading_screen.dart';
import 'set_initial_password_page.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
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

  // Show OTP verification dialog for admin-created user password setup
  void _showOtpVerificationForPasswordSetup(
    BuildContext context,
    String email,
    String newPassword,
  ) {
    final otpController = TextEditingController();
    String? errorMessage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Verify Your Email'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'We sent a 6-digit verification code to $email',
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
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
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
                  print(
                    '🔐 WelcomePage: Verifying OTP and setting password for: $email',
                  );

                  // Verify OTP and update password
                  await SupabaseService.instance.verifyPasswordResetOtp(
                    email: email,
                    otp: otp,
                    newPassword: newPassword,
                  );

                  // Update profile to mark password as set
                  final userId = SupabaseService.instance.getCurrentUser()?.id;
                  if (userId != null) {
                    await SupabaseService.instance.updateUserProfile(
                      userId: userId,
                      profileData: {'password_set': true},
                    );
                  }

                  Navigator.pop(dialogContext); // Close OTP dialog

                  if (!context.mounted) return;

                  // Sign in with new password
                  try {
                    final response = await SupabaseService.instance.signIn(
                      email: email,
                      password: newPassword,
                    );

                    if (response.user != null) {
                      await _startSmoothSignInTransition(
                        context,
                        dialogContext,
                        response.user!.id,
                      );
                    }
                  } catch (signInError) {
                    print(
                      '🔐 WelcomePage: Sign in after password setup error: $signInError',
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Password set successfully! Please sign in.',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  }
                } catch (e) {
                  print('🔐 WelcomePage: OTP verification error: $e');
                  setState(
                    () => errorMessage = e.toString().replaceAll(
                      'Exception: ',
                      '',
                    ),
                  );
                }
              },
              child: const Text('Verify & Continue'),
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
              title: const Text('Member'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MembersSignupPage(),
                  ),
                );
              },
            ),
            ListTile(
              title: const Text('Trusted Partner'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        trusted_partner_signup.TrustedPartnerSignupPage(),
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
    print('🔐 WelcomePage: Starting sign-in transition for user $userId');

    // Close dialog immediately
    if (Navigator.canPop(dialogContext)) {
      Navigator.pop(dialogContext);
    }

    // Check if user is admin-created and needs to set password
    try {
      final user = SupabaseService.instance.getCurrentUser();
      if (user != null) {
        final adminStatus = await SupabaseService.instance
            .checkAdminCreatedStatus(user.email ?? '');

        final isAdminCreated = adminStatus['admin_created'] == true;
        final passwordSet = adminStatus['password_set'] == true;

        print(
          '🔐 WelcomePage: Admin status - admin_created: $isAdminCreated, password_set: $passwordSet',
        );

        if (isAdminCreated && !passwordSet) {
          // Redirect to password setup page
          print('🔐 WelcomePage: Redirecting to initial password setup');
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              parentContext,
              MaterialPageRoute(
                builder: (context) => const SetInitialPasswordPage(),
              ),
              (route) => false,
            );
          }
          return;
        }
      }
    } catch (e) {
      print('🔐 WelcomePage: Error checking admin status: $e');
      // Continue with normal flow if check fails
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
    print(
      '🔐 WelcomePage: Showing Local Lekker loading screen with auto-transition',
    );
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
    final passwordFocusNode = FocusNode();
    final parentContext = context;

    // Email validation state
    bool isEmailValid = false;
    bool isCheckingEmail = false;
    Timer? emailCheckTimer;

    // Admin-created user state
    bool isAdminCreated = false;
    bool needsPasswordSetup = false;
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(needsPasswordSetup ? 'Set Your Password' : 'Sign In'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    hintText: 'Enter your email address',
                    errorText:
                        emailController.text.isNotEmpty &&
                            !isEmailValid &&
                            !isCheckingEmail
                        ? 'Email not found'
                        : null,
                    suffixIcon: isCheckingEmail
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : emailController.text.isNotEmpty
                        ? Icon(
                            isEmailValid ? Icons.check_circle : Icons.error,
                            color: isEmailValid ? Colors.green : Colors.red,
                          )
                        : null,
                  ),
                  keyboardType: TextInputType.emailAddress,
                  enabled: !needsPasswordSetup, // Disable when setting password
                  onChanged: (value) {
                    // Cancel previous timer
                    emailCheckTimer?.cancel();

                    if (value.isEmpty) {
                      setState(() {
                        isEmailValid = false;
                        isCheckingEmail = false;
                      });
                      return;
                    }

                    // Debounce email validation
                    emailCheckTimer = Timer(
                      const Duration(milliseconds: 500),
                      () async {
                        setState(() => isCheckingEmail = true);

                        print(
                          '🔐 WelcomePage: Validating email: "${value.trim()}"',
                        );
                        final exists = await SupabaseService.instance
                            .checkEmailExists(value.trim());
                        print(
                          '🔐 WelcomePage: Email validation result: $exists',
                        );

                        if (exists) {
                          // Check if user is admin-created
                          final adminStatus = await SupabaseService.instance
                              .checkAdminCreatedStatus(value.trim());

                          print('🔐 WelcomePage: Admin status: $adminStatus');

                          isAdminCreated = adminStatus['admin_created'] == true;
                          needsPasswordSetup =
                              isAdminCreated &&
                              adminStatus['password_set'] == false;
                        }

                        if (mounted) {
                          setState(() {
                            isEmailValid = exists;
                            isCheckingEmail = false;
                          });
                          if (exists && !needsPasswordSetup) {
                            // Focus password field for regular users
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (passwordFocusNode.canRequestFocus) {
                                passwordFocusNode.requestFocus();
                              }
                            });
                          }
                        }
                      },
                    );
                  },
                ),
                if (needsPasswordSetup) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Your account was created by an administrator. Please set your password to continue.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    focusNode: passwordFocusNode,
                    decoration: const InputDecoration(
                      labelText: 'New Password',
                      hintText: 'Create a strong password',
                      border: OutlineInputBorder(),
                      helperText: 'At least 6 characters',
                    ),
                    obscureText: true,
                    onChanged: (value) {
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: confirmPasswordController,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      hintText: 'Re-enter your password',
                      border: const OutlineInputBorder(),
                      errorText:
                          confirmPasswordController.text.isNotEmpty &&
                              passwordController.text !=
                                  confirmPasswordController.text
                          ? 'Passwords do not match'
                          : null,
                    ),
                    obscureText: true,
                    onChanged: (value) {
                      setState(() {});
                    },
                  ),
                ] else if (isEmailValid) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    focusNode: passwordFocusNode,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter your password',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    onChanged: (value) {
                      // Trigger rebuild to enable/disable Sign In button
                      setState(() {});
                    },
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            if (!needsPasswordSetup)
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close sign in dialog
                  _showForgotPasswordFlow(context);
                },
                child: const Text('Forgot Password?'),
              ),
            ElevatedButton(
              onPressed:
                  isEmailValid &&
                      passwordController.text.isNotEmpty &&
                      (!needsPasswordSetup ||
                          (passwordController.text.length >= 6 &&
                              passwordController.text ==
                                  confirmPasswordController.text))
                  ? () async {
                      final email = emailController.text;
                      final password = passwordController.text;

                      if (needsPasswordSetup) {
                        // Handle admin-created user password setup
                        try {
                          print(
                            '🔐 WelcomePage: Setting up password for admin-created user: $email',
                          );

                          // First sign in with temp password to get session
                          // We need to get the temp password from somewhere...
                          // Actually, we can't sign in without knowing the temp password
                          // So we need to use the password reset flow instead

                          // Send OTP for password reset
                          await SupabaseService.instance.client.auth
                              .resetPasswordForEmail(email);

                          if (!mounted) return;

                          Navigator.pop(
                            dialogContext,
                          ); // Close password setup dialog

                          // Show OTP dialog for verification
                          _showOtpVerificationForPasswordSetup(
                            parentContext,
                            email,
                            password,
                          );

                          ScaffoldMessenger.of(parentContext).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please check your email for the verification code',
                              ),
                            ),
                          );
                        } catch (e) {
                          print('🔐 WelcomePage: Password setup error: $e');
                          if (mounted) {
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              SnackBar(content: Text('Error: ${e.toString()}')),
                            );
                          }
                        }
                        return;
                      }

                      // Regular sign-in flow
                      // Check if user is already signed in
                      final currentUser = SupabaseService.instance
                          .getCurrentUser();
                      if (currentUser != null && currentUser.email == email) {
                        print(
                          '🔐 WelcomePage: User already signed in: ${currentUser.id}',
                        );
                        await _startSmoothSignInTransition(
                          parentContext,
                          dialogContext,
                          currentUser.id,
                        );
                        return;
                      }

                      try {
                        print(
                          '🔐 WelcomePage: Attempting sign in for email: $email',
                        );
                        final response = await SupabaseService.instance.signIn(
                          email: email,
                          password: password,
                        );
                        print(
                          '🔐 WelcomePage: Sign in response received, user: ${response.user?.id}',
                        );

                        if (response.user != null) {
                          // Start the smooth transition flow
                          await _startSmoothSignInTransition(
                            parentContext,
                            dialogContext,
                            response.user!.id,
                          );
                        } else {
                          print('🔐 WelcomePage: Sign in response has no user');
                          try {
                            if (mounted) {
                              ScaffoldMessenger.of(parentContext).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Sign in failed - no user returned',
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            // Context might be invalid
                          }
                        }
                      } catch (e) {
                        print('🔐 WelcomePage: Sign in error: $e');
                        String errorMessage = 'Sign in error: ${e.toString()}';
                        if (e.toString().contains(
                          'Invalid login credentials',
                        )) {
                          errorMessage = 'Invalid email or password';
                        } else if (e.toString().contains(
                          'Email not confirmed',
                        )) {
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
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              SnackBar(content: Text(errorMessage)),
                            );
                          }
                        } catch (e) {
                          // Context might be invalid
                        }
                      }
                    }
                  : null,
              child: const Text('Sign In'),
            ),
          ],
        ),
      ),
    );
  }

  void _showOtpSigninDialog(BuildContext context) {
    final emailController = TextEditingController();
    final parentContext = context;

    // Email validation state
    bool isEmailValid = false;
    bool isCheckingEmail = false;
    Timer? emailCheckTimer;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Sign In with OTP'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    hintText: 'Enter your email address',
                    errorText:
                        emailController.text.isNotEmpty &&
                            !isEmailValid &&
                            !isCheckingEmail
                        ? 'Email not found'
                        : null,
                    suffixIcon: isCheckingEmail
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : emailController.text.isNotEmpty
                        ? Icon(
                            isEmailValid ? Icons.check_circle : Icons.error,
                            color: isEmailValid ? Colors.green : Colors.red,
                          )
                        : null,
                  ),
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (value) {
                    // Cancel previous timer
                    emailCheckTimer?.cancel();

                    if (value.isEmpty) {
                      setState(() {
                        isEmailValid = false;
                        isCheckingEmail = false;
                      });
                      return;
                    }

                    // Debounce email validation
                    emailCheckTimer = Timer(
                      const Duration(milliseconds: 500),
                      () async {
                        setState(() => isCheckingEmail = true);

                        print(
                          '🔐 WelcomePage: Validating email (forgot password): "${value.trim()}"',
                        );
                        final exists = await SupabaseService.instance
                            .checkEmailExists(value.trim());
                        print(
                          '🔐 WelcomePage: Email validation result (forgot password): $exists',
                        );

                        if (mounted) {
                          setState(() {
                            isEmailValid = exists;
                            isCheckingEmail = false;
                          });
                        }
                      },
                    );
                  },
                ),
                const SizedBox(height: 10),
                const Text(
                  'We\'ll send a 6-digit code to your email for verification.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isEmailValid
                  ? () async {
                      final email = emailController.text.trim();

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
                    }
                  : null,
              child: const Text('Send OTP'),
            ),
          ],
        ),
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
