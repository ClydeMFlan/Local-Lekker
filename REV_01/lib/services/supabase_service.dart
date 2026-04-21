import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseService {
  SupabaseService._();

  static final SupabaseService instance = SupabaseService._();

  late final SupabaseClient client;
  final Logger _logger = Logger();

  Future<void> init() async {
    _logger.i('init() method called');
    _logger.i('Initializing Supabase...');
    // Use environment variables
    final url = dotenv.env['SUPABASE_URL'] ?? 'http://localhost:54321';
    final anonKey =
        dotenv.env['SUPABASE_ANON_KEY'] ??
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';
    _logger.d('Using URL: $url');
    await Supabase.initialize(url: url, anonKey: anonKey);
    client = Supabase.instance.client;
    _logger.i('Supabase initialized successfully');

    // Initialize auth state change listener
    _initAuthStateListener();
  }

  // Authentication methods
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? userMetadata,
  }) async {
    try {
      final resp = await client.auth.signUp(
        email: email,
        password: password,
        data: userMetadata,
      );

      // Log the response for easier debugging of email/otp delivery issues
      try {
        _logger.i('SupabaseService.signUp: response.user=${resp.user}');
        _logger.i('SupabaseService.signUp: response.session=${resp.session}');
      } catch (_) {
        // best-effort logging; do not throw from logging
      }

      return resp;
    } catch (e) {
      // Handle rate limiting
      if (e.toString().contains('over_email_send_rate_limit')) {
        throw Exception(
          'Too many signup attempts. Please wait a moment before trying again.',
        );
      }
      rethrow;
    }
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    _logger.i('Attempting sign in for $email');
    _logger.d(
      'Build mode: ${const bool.fromEnvironment('dart.vm.product') ? 'RELEASE' : 'DEBUG'}',
    );

    try {
      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      _logger.i('Sign in successful for $email, user: ${response.user?.id}');
      return response;
    } catch (e) {
      _logger.e('Sign in failed for $email: $e');

      // Handle specific token grant errors
      if (e.toString().contains('token') || e.toString().contains('grant')) {
        _logger.w('Token grant error during sign in: $e');
        throw Exception(
          'Authentication failed. Please try again or check your connection.',
        );
      }

      // Handle network/connectivity issues
      if (e.toString().contains('network') ||
          e.toString().contains('connection')) {
        throw Exception(
          'Network error. Please check your internet connection and try again.',
        );
      }

      rethrow;
    }
  }

  Future<void> signOut() async {
    await client.auth.signOut();
  }

  Future<void> resetPassword({required String email}) async {
    try {
      // Use OTP-based password reset for mobile apps instead of email links
      await sendPasswordResetOtp(email: email);
      _logger.i('Password reset OTP sent to: $email');
    } catch (e) {
      _logger.e('Password reset failed for $email: $e');
      rethrow;
    }
  }

  Future<void> sendPasswordResetOtp({required String email}) async {
    try {
      // For mobile apps, use signInWithOtp to send OTP without redirect
      await client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: false, // Don't create user if they don't exist
      );
      _logger.i('Password reset OTP sent to: $email');
    } catch (e) {
      _logger.e('Password reset OTP failed for $email: $e');
      rethrow;
    }
  }

  Future<void> updatePassword({required String newPassword}) async {
    try {
      await client.auth.updateUser(UserAttributes(password: newPassword));
      _logger.i('Password updated successfully');
    } catch (e) {
      _logger.e('Password update failed: $e');
      rethrow;
    }
  }

  // Verify password reset OTP and update password
  Future<AuthResponse> verifyPasswordResetOtp({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    try {
      // Verify the OTP using email type since we used signInWithOtp method
      final response = await client.auth.verifyOTP(
        email: email,
        token: otp,
        type: OtpType.email, // Use email type for signInWithOtp
      );

      if (response.user == null) {
        throw Exception('OTP verification failed');
      }

      _logger.i(
        'Password reset OTP verified for user: ${response.user!.email}',
      );

      // Now update the password
      await updatePassword(newPassword: newPassword);

      _logger.i('Password reset completed successfully for: $email');
      return response;
    } catch (e) {
      _logger.e('Password reset OTP verification failed: $e');
      if (e.toString().contains('expired')) {
        throw Exception('OTP has expired. Please request a new one.');
      } else if (e.toString().contains('invalid')) {
        throw Exception('Invalid OTP code. Please check and try again.');
      }
      throw Exception('Password reset failed. Please try again.');
    }
  }

  // Get current user
  User? getCurrentUser() {
    final user = client.auth.currentUser;
    _logger.d(
      user != null ? 'User authenticated: ${user.id}' : 'No authenticated user',
    );
    return user;
  }

  /// Fetch the role for the specified user id, or the current user if
  /// [userId] is not provided. Returns the role string (e.g. 'admin') or null.
  Future<String?> getUserRole({String? userId}) async {
    final user = client.auth.currentUser;
    final lookupId = userId ?? user?.id;
    if (lookupId == null) return null;

    _logger.d('looking up role for userId=$lookupId');

    try {
      // First priority: check user metadata (set during signup - most authoritative)
      if (user?.userMetadata != null &&
          user!.userMetadata!.containsKey('user_type')) {
        final userType = user.userMetadata!['user_type']?.toString();
        if (userType != null && userType.isNotEmpty) {
          _logger.d('using user metadata, user_type="$userType"');
          return userType;
        }
      }

      // Second priority: prefer the memberships table (memberships.user_id -> role).
      try {
        final memRes = await client
            .from('memberships')
            .select('role')
            .eq('user_id', lookupId)
            .limit(1)
            .maybeSingle();

        Map<String, dynamic>? memMap;
        if (memRes is Map<String, dynamic>) memMap = memRes;
        if (memMap != null && memMap.containsKey('role')) {
          final role = memMap['role']?.toString();
          _logger.d('found role in memberships table: "$role"');
          return role;
        } else {
          _logger.d('no role found in memberships table');
        }
      } catch (e) {
        // Check if this is the infinite recursion error
        if (e.toString().contains('infinite recursion detected in policy')) {
          _logger.w(
            'SupabaseService.getUserRole: Infinite recursion in memberships policy detected, skipping memberships table query',
          );
          // Skip to RPC fallback instead of trying profiles table
        } else {
          // Not fatal — we'll fall back to profiles or RPC below.
          _logger.e(
            'SupabaseService.getUserRole: memberships lookup failed: $e',
          );
        }
      }

      // Third priority: fallback to profiles table (profiles.id -> role).
      try {
        final profRes = await client
            .from('profiles')
            .select('role')
            .eq('id', lookupId)
            .limit(1)
            .maybeSingle();

        Map<String, dynamic>? profMap;
        if (profRes is Map<String, dynamic>) profMap = profRes;
        if (profMap != null && profMap.containsKey('role')) {
          final role = profMap['role']?.toString();
          _logger.d('found role in profiles table: "$role"');
          return role;
        } else {
          _logger.d('no role found in profiles table');
        }
      } catch (e) {
        // Check if this is also an infinite recursion error
        if (e.toString().contains('infinite recursion detected in policy')) {
          _logger.w(
            'SupabaseService.getUserRole: Infinite recursion in profiles policy detected, skipping profiles table query',
          );
          // Skip to RPC fallback
        } else {
          _logger.e('SupabaseService.getUserRole: profiles lookup failed: $e');
        }
      }

      // Final fallback: call a secure RPC (e.g. SECURITY DEFINER) that returns
      // the caller's role. Many projects expose `get_my_role()` for this.
      try {
        final rpcRes = await client.rpc('get_my_role');
        if (rpcRes == null) return null;

        if (rpcRes is String) return rpcRes;
        if (rpcRes is Map && rpcRes.containsKey('role')) {
          return rpcRes['role']?.toString();
        }
        if (rpcRes is List && rpcRes.isNotEmpty) {
          final first = rpcRes.first;
          if (first is Map && first.containsKey('role')) {
            return first['role']?.toString();
          }
          if (first is String) return first;
        }
      } catch (e) {
        _logger.e('SupabaseService.getUserRole RPC fallback failed: $e');
        // If the simple get_my_role RPC is not available (or RLS prevents
        // reading memberships), try calling the secure admin dashboard RPC
        // which is implemented as a SECURITY DEFINER function in the
        // backend. If it returns any data for the caller, we can infer
        // the caller is an admin. This is a best-effort fallback to
        // handle RLS-protected setups where memberships can't be selected.
        try {
          dynamic dashRes;
          try {
            dashRes = await client.rpc('secure_get_admin_dashboard').select();
          } catch (_) {
            dashRes = await client.rpc('get_admin_dashboard').select();
          }

          if (dashRes != null) {
            if (dashRes is List && dashRes.isNotEmpty) return 'admin';
            if (dashRes is Map && dashRes.isNotEmpty) return 'admin';
          }
        } catch (e2) {
          _logger.e(
            'SupabaseService.getUserRole admin-dashboard RPC fallback failed: $e2',
          );
        }
      }

      return null;
    } catch (e) {
      // Keep debug print for now; callers will handle null role gracefully.
      _logger.e('Error fetching user role: $e');
      return null;
    }
  }

  // Check if user is authenticated
  bool isAuthenticated() {
    return client.auth.currentUser != null;
  }

  /// Returns true if the resolved role for [userId] (or current user when
  /// omitted) equals 'admin' (case-insensitive). Useful for quick guards.
  Future<bool> isAdmin({String? userId}) async {
    final role = await getUserRole(userId: userId);
    return (role ?? '').toLowerCase() == 'admin';
  }

  /// Returns true if the resolved role for [userId] (or current user when
  /// omitted) equals 'trusted_partner' (case-insensitive). Useful for quick guards.
  /// Trusted partners don't require subscription payments.
  Future<bool> isTrustedPartner({String? userId}) async {
    final role = await getUserRole(userId: userId);
    final result = (role ?? '').toLowerCase() == 'trusted_partner';
    _logger.d('userId=$userId, role="$role", isTrustedPartner=$result');
    return result;
  }

  // Listen to auth state changes
  Stream<AuthState> get authStateChanges {
    return client.auth.onAuthStateChange;
  }

  // Initialize auth state change listener
  void _initAuthStateListener() {
    _logger.i('Setting up auth state change listener');
    client.auth.onAuthStateChange.listen(
      (AuthState authState) {
        _logger.d('Auth state changed: ${authState.event}');
        _logger.d('Session exists: ${authState.session != null}');
        _logger.d('User exists: ${authState.session?.user != null}');

        switch (authState.event) {
          case AuthChangeEvent.signedIn:
            _logger.i('User signed in: ${authState.session?.user.id}');
            _logger.d(
              'Access token: ${authState.session?.accessToken != null ? "Present" : "Null"}',
            );
            _logger.d(
              'Refresh token: ${authState.session?.refreshToken != null ? "Present" : "Null"}',
            );
            break;
          case AuthChangeEvent.signedOut:
            _logger.i('User signed out');
            break;
          case AuthChangeEvent.tokenRefreshed:
            _logger.i('Token refreshed successfully');
            _logger.d(
              'New access token: ${authState.session?.accessToken != null ? "Present" : "Null"}',
            );
            break;
          case AuthChangeEvent.userUpdated:
            _logger.i('User updated');
            break;
          case AuthChangeEvent.passwordRecovery:
            _logger.i('Password recovery initiated');
            break;
          case AuthChangeEvent.userDeleted:
            _logger.i('User deleted');
            break;
          default:
            _logger.w('Unknown auth event: ${authState.event}');
        }

        // Handle token refresh errors
        if (authState.session == null &&
            authState.event != AuthChangeEvent.signedOut) {
          _logger.w('Auth state changed but no session available');
          _logger.w('This might indicate a token grant error');
        }

        // Check for token expiration
        if (authState.session?.expiresAt != null) {
          final expiresAt = DateTime.fromMillisecondsSinceEpoch(
            authState.session!.expiresAt! * 1000,
          );
          final now = DateTime.now();
          final timeUntilExpiry = expiresAt.difference(now);
          _logger.d('Token expires in: ${timeUntilExpiry.inMinutes} minutes');

          if (timeUntilExpiry.isNegative) {
            _logger.w('Warning - Token has expired!');
          }
        }
      },
      onError: (error) {
        _logger.e('Auth state change error: $error');
        // Handle token grant errors specifically
        if (error.toString().contains('token') ||
            error.toString().contains('grant')) {
          _logger.w('Token grant error detected: $error');
          _logger.w('This may require re-authentication');
        }

        // Handle network errors that might cause token issues
        if (error.toString().contains('network') ||
            error.toString().contains('connection')) {
          _logger.w('Network error during auth state change: $error');
        }
      },
    );
  }

  // OTP Verification methods
  Future<void> sendOtp({
    required String email,
    String? phone,
    required String method,
    bool isForSignIn = false,
  }) async {
    try {
      if (method == 'email') {
        if (isForSignIn) {
          // For sign-in OTP, use signInWithOtp which sends OTP without creating account
          await client.auth.signInWithOtp(
            email: email,
            shouldCreateUser: false, // Don't create user if they don't exist
          );
          _logger.i('Sign-in OTP sent to: $email');
        } else {
          // For signup OTP, use signInWithOtp which creates account and sends 6-digit OTP
          await client.auth.signInWithOtp(
            email: email,
            shouldCreateUser: true, // Create user if they don't exist
          );
          _logger.i('Sign-up OTP sent to: $email');
        }
      } else if (method == 'sms' && phone != null) {
        // For SMS, we'd need to use a third-party SMS service
        // For now, we'll use email as fallback
        if (isForSignIn) {
          await client.auth.signInWithOtp(
            email: email,
            shouldCreateUser: false,
          );
          _logger.i('Sign-in OTP sent to: $email (SMS fallback)');
        } else {
          await client.auth.signInWithOtp(
            email: email,
            shouldCreateUser: true, // Create user if they don't exist
          );
          _logger.i('Sign-up OTP sent to: $email (SMS fallback)');
        }
      }
      _logger.i('OTP sent successfully to $email via $method');
    } catch (e) {
      // Print full exception type and value for debugging
      _logger.e('Error sending OTP (${e.runtimeType}): $e');
      if (e.toString().contains('rate_limit')) {
        throw Exception(
          'Too many OTP requests. Please wait before trying again.',
        );
      }
      throw Exception('Failed to send OTP. Please try again.');
    }
  }

  Future<AuthResponse> verifyOtp({
    required String email,
    String? phone,
    required String otp,
    required String method,
    bool isForSignIn = false,
  }) async {
    try {
      // For sign-in OTPs (sent via signInWithOtp), use email type
      // For signup OTPs (sent via signUp), use signup type
      final otpType = (method == 'email' && isForSignIn)
          ? OtpType.email
          : OtpType.signup;

      final response = await client.auth.verifyOTP(
        email: email,
        token: otp,
        type: otpType,
      );

      if (response.user == null) {
        throw Exception('OTP verification failed');
      }

      _logger.i('OTP verified successfully for user: ${response.user!.email}');

      // Best-effort: ensure a matching row exists in `public.users` so
      // subsequent RPCs that reference that table via foreign keys don't
      // fail for newly created auth users. This avoids a race between
      // Supabase Auth and application tables in environments where
      // historical data may be missing.
      try {
        final authUser = response.user!;
        final upsertRow = <String, dynamic>{
          'id': authUser.id,
          'email': authUser.email,
          // created_at column is often timestamptz with default now();
          // include it explicitly as ISO string to be safe when the
          // column exists and is NOT NULL.
          'created_at': DateTime.now().toIso8601String(),
        };

        // Log the raw PostgREST result so we can see if RLS silently
        // blocked the insert or returned an empty response.
        final upsertRes = await client.from('users').upsert(upsertRow).select();
        _logger.i(
          '✅ public.users upsert result for ${authUser.id}: $upsertRes',
        );
      } catch (e) {
        // Non-fatal. Log for observability but don't break OTP flow.
        _logger.w('⚠️ Failed to upsert public.users after OTP: $e');
      }

      return response;
    } catch (e) {
      _logger.e('Error verifying OTP: $e');

      // Handle specific token grant errors
      if (e.toString().contains('token') || e.toString().contains('grant')) {
        _logger.e('Token grant error during OTP verification: $e');
        throw Exception(
          'Verification failed due to authentication error. Please try again.',
        );
      }

      if (e.toString().contains('expired')) {
        throw Exception('OTP has expired. Please request a new one.');
      } else if (e.toString().contains('invalid')) {
        throw Exception('Invalid OTP code. Please check and try again.');
      }
      throw Exception('OTP verification failed. Please try again.');
    }
  }

  // Enhanced OTP sign-in method
  Future<AuthResponse> signInWithOtp({
    required String email,
    String? phone,
    required String method,
  }) async {
    try {
      // Send OTP for sign-in
      await sendOtp(
        email: email,
        phone: phone,
        method: method,
        isForSignIn: true,
      );

      // Return a response indicating OTP was sent
      // The actual verification will happen separately
      return AuthResponse(user: null, session: null);
    } catch (e) {
      _logger.e('Error in OTP sign-in: $e');
      rethrow;
    }
  }

  // Store additional user data after signup
  Future<void> createUserProfile({
    required String userId,
    required Map<String, dynamic> userData,
  }) async {
    try {
      _logger.i('Creating profile for userId=$userId');

      // Check if email is already used by another user
      if (userData['email'] != null) {
        final existingProfile = await client
            .from('profiles')
            .select('id')
            .eq('email', userData['email'])
            .neq('id', userId)
            .maybeSingle();

        if (existingProfile != null) {
          throw Exception('Email already in use by another user');
        }
      }

      // Get the user type from metadata to determine the correct role
      final currentUser = client.auth.currentUser;
      String? userType = currentUser?.userMetadata?['user_type'] as String?;

      // If not found in userMetadata, try to get it from raw_app_meta_data
      if (userType == null && currentUser != null) {
        try {
          // Query the profiles table to see what role was already assigned by the trigger
          final existingProfile = await client
              .from('profiles')
              .select('role')
              .eq('id', userId)
              .maybeSingle();

          if (existingProfile != null && existingProfile['role'] != null) {
            // Use the role that was already assigned by the trigger
            final existingRole = existingProfile['role'] as String;
            userType = existingRole == 'trusted_partner'
                ? 'trusted_partner'
                : 'member';
            _logger.d('Using existing role from trigger: $existingRole');
          }
        } catch (e) {
          _logger.w('Could not read existing profile: $e');
        }
      }

      // Default to 'member' if still not found
      userType ??= 'member';
      final role = userType == 'trusted_partner' ? 'trusted_partner' : 'member';

      _logger.d('User type from metadata: $userType, assigned role: $role');

      final profileData = {
        'id': userId,
        'email': userData['email'],
        'name': userData['name'],
        'surname': userData['surname'],
        'date_of_birth': userData['date_of_birth'],
        'gender': userData['gender'],
        'ethnicity': userData['ethnicity'],
        'province': userData['province'],
        'street': userData['street'],
        'suburb': userData['suburb'],
        'city': userData['city'],
        'contact': userData['contact'],
        'role': role, // ✅ Now uses the correct role based on user_type metadata
      };

      // Remove null values
      profileData.removeWhere((key, value) => value == null);

      await client.from('profiles').upsert(profileData);

      _logger.i(
        '🔐 SupabaseService.createUserProfile: Profile created/updated successfully with role: $role',
      );
    } catch (e) {
      _logger.e('Error creating profile: $e');
      // Continue without failing the signup process
      // The user authentication was successful, which is the main requirement
    }
  }

  /// Authorize a user as a trusted partner by inserting/upserting a row in the
  /// `memberships` table (user_id -> role = 'trusted_partner') and attempting to
  /// set the `profiles.role` to 'trusted_partner' as a best-effort step. Returns
  /// true when the operation completed without throwing (it may still be
  /// rejected by DB policies remotely; callers should handle false/throws).
  Future<bool> authorizeTrustedPartner({required String userId}) async {
    try {
      final row = {'user_id': userId, 'role': 'trusted_partner'};

      // Try to upsert into memberships so repeated attempts don't fail.
      try {
        await client.from('memberships').upsert(row).select();
        _logger.i(
          'authorizeTrustedPartner: memberships row upserted for $userId',
        );
      } catch (e) {
        _logger.e('authorizeTrustedPartner: could not upsert memberships: $e');
      }

      // Best-effort: update profiles.role if the table exists and policies
      // allow it for the current principal.
      try {
        await client.from('profiles').upsert({
          'id': userId,
          'role': 'trusted_partner',
        }).select();
        _logger.i(
          'authorizeTrustedPartner: profiles.role upserted for $userId',
        );
      } catch (e) {
        _logger.e('authorizeTrustedPartner: could not upsert profiles: $e');
      }

      return true;
    } catch (e) {
      _logger.e('authorizeTrustedPartner failed: $e');
      return false;
    }
  }

  // Store trusted partner data after signup
  Future<void> createTrustedPartnerProfile({
    required String userId,
    required Map<String, dynamic> trustedPartnerData,
  }) async {
    try {
      // Only include columns that exist in the current `trusted_partners` table to
      // avoid Postgrest errors when sending unknown fields (e.g. 'city').
      // At the moment the table in the database contains at least:
      // - id (uuid)
      // - user_id (uuid)
      // - business_name (text NOT NULL)
      // - created_at (timestamptz default now())
      // Keep this list small and explicit. If you later add columns to the
      // DB, update this list or add migrations to keep the client in sync.
      final allowed = <String>{'user_id', 'business_name', 'created_at'};

      final row = <String, dynamic>{
        'user_id': userId,
        'business_name': trustedPartnerData['business_name'],
        // created_at can be left to the DB default, but include if provided
        if (trustedPartnerData.containsKey('created_at'))
          'created_at': trustedPartnerData['created_at'],
      };

      // Remove null values and any keys not in the allowed set
      row.removeWhere((k, v) => v == null || !allowed.contains(k));

      // Try to insert the trusted partner row. Use insert() so we don't accidentally
      // trigger upsert semantics against the primary key. Do not request
      // fields the DB doesn't have.
      final inserted = await client
          .from('trusted_partners')
          .insert(row)
          .select()
          .maybeSingle();

      if (inserted == null) {
        _logger.w('createTrustedPartnerProfile: insert returned null (no row)');
      } else {
        _logger.i(
          'createTrustedPartnerProfile: trusted partner row created: $inserted',
        );
      }
    } catch (e) {
      // Log the error but do not fail the overall signup flow. The user is
      // already created in Supabase Auth; trusted partner profile can be retried.
      _logger.e('Error creating trusted partner profile: $e');
      // Re-throwing would bubble the error up to the UI; we keep it local so
      // account creation remains successful even if DB insert fails.
    }
  }

  /// Calls a server-side RPC to complete trusted partner signup in one privileged
  /// operation. The RPC `complete_trusted_partner_signup` should be implemented
  /// server-side as a SECURITY DEFINER function that upserts memberships,
  /// profiles and trusted_partners (idempotent). `params` is a plain map of values
  /// expected by the RPC (e.g. first_name, surname, business_name, category,
  /// street, suburb, city, province, contact_email, latitude, longitude).
  Future<dynamic> completeTrustedPartnerSignup(
    Map<String, dynamic> params,
  ) async {
    try {
      // The server-side RPC is defined as complete_trusted_partner_signup(payload jsonb)
      // so PostgREST expects a single argument named `payload` containing the
      // JSON payload. Wrap the provided params map under that key so the
      // request matches the function signature and avoids function-not-found
      // errors caused by mismatched parameter names/types.
      final res = await client.rpc(
        'complete_trusted_partner_signup',
        params: {'payload': params},
      );
      _logger.i('completeTrustedPartnerSignup: rpc returned: $res');
      return res;
    } on PostgrestException catch (e) {
      _logger.e('completeTrustedPartnerSignup PostgrestException: $e');
      rethrow;
    } catch (e) {
      _logger.e('completeTrustedPartnerSignup error: $e');
      rethrow;
    }
  }

  /// Calls the server-side RPC `complete_business_profile(payload jsonb)`
  /// which upserts or updates the caller's business record. Returns the RPC
  /// result (usually a JSON-like Map or string).
  Future<dynamic> completeBusinessProfile(Map<String, dynamic> params) async {
    try {
      _logger.i('completeBusinessProfile: calling rpc with payload: $params');

      // Preflight: ensure user data is available in profiles table
      // Skip users table preflight to avoid email constraint issues
      try {
        final uid = client.auth.currentUser?.id;
        final email = client.auth.currentUser?.email;
        final name = client.auth.currentUser?.userMetadata?['name'] as String?;
        final surname =
            client.auth.currentUser?.userMetadata?['surname'] as String?;
        if (uid != null && email != null) {
          // Just ensure profiles table has the user data
          final fullName = (surname != null && surname.isNotEmpty)
              ? (name != null ? '$name $surname' : surname)
              : (name ?? '');

          await client.from('profiles').upsert({
            'id': uid,
            'email': email,
            'name': fullName,
            'surname': surname ?? '',
          }).select();
          _logger.i(
            'completeBusinessProfile: profiles preflight succeeded with name: $fullName, surname: $surname',
          );
        } else {
          _logger.w(
            'completeBusinessProfile: no authenticated uid/email available for preflight',
          );
        }
      } catch (e) {
        _logger.w(
          'completeBusinessProfile: profiles preflight failed (non-fatal): $e',
        );
      }

      final res = await client.rpc(
        'complete_business_profile',
        params: {'payload': params},
      );
      _logger.i('completeBusinessProfile: rpc returned: $res');
      return res;
    } on PostgrestException catch (e) {
      _logger.e('completeBusinessProfile PostgrestException: $e');
      rethrow;
    } catch (e) {
      _logger.e('completeBusinessProfile error: $e');
      rethrow;
    }
  }

  /// Utility method to fix merchant role for existing users
  /// This can be called from debug console or during development
  Future<void> fixMerchantRole(String userId) async {
    try {
      _logger.i(
        'SupabaseService.fixMerchantRole: Setting role to merchant for user $userId',
      );
      await client.from('profiles').upsert({
        'id': userId,
        'role': 'merchant',
      }).select();
      _logger.i('Successfully set role for user $userId');
    } catch (e) {
      _logger.e('Failed to set role for user $userId: $e');
    }
  }

  /// available or fails. This is useful to ensure `public.users` and
  /// `public.profiles` exist before calling privileged RPCs.
  Future<Map<String, dynamic>> prepareUserContext() async {
    try {
      // Prefer a server-side SECURITY DEFINER RPC named
      // `prepare_user_context(payload jsonb)` which should insert missing
      // rows in a trusted context. If it exists, call it and return the
      // result.
      try {
        final rpcRes = await client.rpc('prepare_user_context');
        if (rpcRes != null) {
          _logger.i('prepareUserContext: server RPC returned: $rpcRes');
          if (rpcRes is Map<String, dynamic>) return rpcRes;
          return {'ok': true, 'result': rpcRes};
        }
      } catch (e) {
        _logger.w('prepareUserContext: server RPC not available or failed: $e');
      }

      // Fallback: perform a best-effort client upsert into `public.users`.
      final uid = client.auth.currentUser?.id;
      final email = client.auth.currentUser?.email;
      if (uid != null && email != null) {
        try {
          final upsertRow = {
            'id': uid,
            'email': email,
            'created_at': DateTime.now().toIso8601String(),
          };
          final upRes = await client.from('users').upsert(upsertRow).select();
          _logger.i('prepareUserContext: client upsert result: $upRes');
          return {'ok': true};
        } catch (e) {
          _logger.e('prepareUserContext: client upsert failed: $e');
          return {'ok': false, 'error': e.toString()};
        }
      }

      return {'ok': false, 'error': 'no_authenticated_user'};
    } catch (e) {
      return {'ok': false, 'error': e.toString()};
    }
  }

  // Debug method to check what profile data exists for current user
  Future<void> debugUserProfile() async {
    try {
      final user = client.auth.currentUser;
      if (user == null) {
        _logger.d('🔐 DEBUG: No authenticated user');
        return;
      }

      _logger.d(
        '🔐 DEBUG: Checking profile data for user: ${user.email} (${user.id})',
      );

      final response = await client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (response == null) {
        _logger.d('No profile data found for user');
        return;
      }

      _logger.d('Profile data found:');
      response.forEach((key, value) {
        _logger.d('$key = $value (${value?.runtimeType})');
      });
    } catch (e) {
      _logger.d('Error checking profile data: $e');
    }
  }

  /// Manually refresh the current session tokens
  /// This can be useful for debugging token grant issues
  Future<void> refreshSession() async {
    try {
      _logger.i('Manually refreshing session tokens');
      final response = await client.auth.refreshSession();
      _logger.i('Session refresh successful');
      _logger.d(
        'New access token: ${response.session?.accessToken != null ? "Present" : "Null"}',
      );
      _logger.d(
        'New refresh token: ${response.session?.refreshToken != null ? "Present" : "Null"}',
      );
    } catch (e) {
      _logger.e('Session refresh failed: $e');
      if (e.toString().contains('token') || e.toString().contains('grant')) {
        _logger.e(
          '🔐 SupabaseService: Token grant error during session refresh: $e',
        );
        throw Exception('Token refresh failed. You may need to sign in again.');
      }
      rethrow;
    }
  }

  /// Check if the current session is valid and tokens are not expired
  Future<bool> isSessionValid() async {
    try {
      final user = client.auth.currentUser;
      final session = client.auth.currentSession;

      if (user == null || session == null) {
        _logger.d('No active session');
        return false;
      }

      // Check if token is expired
      if (session.expiresAt != null) {
        final expiresAt = DateTime.fromMillisecondsSinceEpoch(
          session.expiresAt! * 1000,
        );
        final now = DateTime.now();
        final isExpired = now.isAfter(expiresAt);

        _logger.d('Session expires at: $expiresAt');
        _logger.d('Current time: $now');
        _logger.d('Session expired: $isExpired');

        if (isExpired) {
          _logger.i('Session has expired, attempting refresh');
          await refreshSession();
          return true; // If refresh succeeds, session is now valid
        }
      }

      _logger.d('🔐 SupabaseService: Session is valid');
      return true;
    } catch (e) {
      _logger.e('🔐 SupabaseService: Error checking session validity: $e');
      return false;
    }
  }

  /// Check network connectivity and Supabase reachability
  Future<bool> checkConnectivity() async {
    try {
      _logger.d('🔐 SupabaseService: Checking connectivity...');

      // Try to make a simple request to Supabase
      await client.from('users').select('count').limit(1).maybeSingle();
      _logger.d('🔐 SupabaseService: Connectivity check successful');
      return true;
    } catch (e) {
      _logger.e('🔐 SupabaseService: Connectivity check failed: $e');

      // Check if it's a network-related error
      if (e.toString().contains('network') ||
          e.toString().contains('connection') ||
          e.toString().contains('timeout') ||
          e.toString().contains('unreachable')) {
        _logger.w('🔐 SupabaseService: Network connectivity issue detected');
        return false;
      }

      // Check if it's a permission-related error
      if (e.toString().contains('permission') ||
          e.toString().contains('denied') ||
          e.toString().contains('forbidden')) {
        _logger.w(
          '🔐 SupabaseService: Permission issue detected - likely missing INTERNET permission in release build',
        );
        return false;
      }

      return false;
    }
  }

  // Profile management methods
  Future<Map<String, dynamic>?> getUserProfile({String? userId}) async {
    try {
      final user = client.auth.currentUser;
      final lookupId = userId ?? user?.id;
      if (lookupId == null) {
        _logger.w('🔐 SupabaseService.getUserProfile: No user ID available');
        throw Exception('User not authenticated');
      }

      _logger.d(
        '🔐 SupabaseService.getUserProfile: Fetching profile for userId=$lookupId',
      );

      final response = await client
          .from('profiles')
          .select()
          .eq('id', lookupId)
          .single();

      _logger.d(
        '🔐 SupabaseService.getUserProfile: Profile data retrieved successfully',
      );
      _logger.d('🔐 SupabaseService.getUserProfile: Retrieved data: $response');

      // Log each field individually for debugging
      _logger.d('🔐 SupabaseService.getUserProfile: Individual fields:');
      response.forEach((key, value) {
        _logger.d(
          '🔐 SupabaseService.getUserProfile: $key = $value (${value.runtimeType})',
        );
      });

      return response;
    } catch (e) {
      _logger.e(
        '🔐 SupabaseService.getUserProfile: Error fetching profile: $e',
      );

      // Check if it's a "no rows" error (profile doesn't exist)
      if (e.toString().contains(
            'Cannot coerce the result to a single JSON object',
          ) ||
          e.toString().contains('0 rows')) {
        _logger.i(
          '🔐 SupabaseService.getUserProfile: Profile does not exist yet',
        );
        return null; // This is expected for new users
      }

      // Re-throw other errors with more context
      throw Exception('Database error: ${e.toString()}');
    }
  }

  Future<bool> updateUserProfile({
    required String userId,
    required Map<String, dynamic> profileData,
  }) async {
    try {
      _logger.i(
        '🔐 SupabaseService.updateUserProfile: Updating profile for userId=$userId',
      );
      _logger.d(
        '🔐 SupabaseService.updateUserProfile: Data to update: $profileData',
      );

      // Remove null values and prepare data for update
      final cleanData = Map<String, dynamic>.from(profileData);
      cleanData.removeWhere((key, value) => value == null);
      _logger.d('🔐 SupabaseService.updateUserProfile: Clean data: $cleanData');

      await client.from('profiles').update(cleanData).eq('id', userId);

      _logger.i(
        '🔐 SupabaseService.updateUserProfile: Profile updated successfully',
      );
      return true;
    } catch (e) {
      _logger.e(
        '🔐 SupabaseService.updateUserProfile: Error updating profile: $e',
      );
      return false;
    }
  }

  // Create initial profile for user
  Future<bool> createInitialUserProfile() async {
    try {
      final user = client.auth.currentUser;
      if (user == null) {
        _logger.w(
          '🔐 SupabaseService.createInitialUserProfile: No authenticated user',
        );
        throw Exception('User not authenticated');
      }

      _logger.i(
        '🔐 SupabaseService.createInitialUserProfile: Creating initial profile for userId=${user.id}',
      );

      // Only use columns that are known to exist in the database
      final profileData = {
        'id': user.id,
        'email': user.email,
        'name': '', // Will be empty initially
        'surname': '', // Added in migration
      };

      await client.from('profiles').upsert(profileData);

      _logger.i(
        '🔐 SupabaseService.createInitialUserProfile: Initial profile created successfully',
      );
      return true;
    } catch (e) {
      _logger.e(
        '🔐 SupabaseService.createInitialUserProfile: Error creating initial profile: $e',
      );
      // Re-throw with more context
      throw Exception('Failed to create profile: ${e.toString()}');
    }
  }

  // Temporary method to check role for clydemflan@gmail.com

  /// Test method to verify trigger is working
  Future<Map<String, dynamic>> testTriggerFunctionality() async {
    try {
      // Create a test user with a valid email format that Supabase accepts
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final testEmail = 'testuser$timestamp@gmail.com';
      final response = await signUp(
        email: testEmail,
        password: 'TestPass123!',
        userMetadata: {'user_type': 'user', 'name': 'Test User'},
      );

      if (response.user == null) {
        return {'success': false, 'error': 'User creation failed'};
      }

      final userId = response.user!.id;

      // Wait a moment for trigger to execute
      await Future.delayed(const Duration(seconds: 2));

      // Check if profile was created
      final profileCheck = await client
          .from('profiles')
          .select('*')
          .eq('id', userId)
          .maybeSingle();

      // Check if membership was created
      final membershipCheck = await client
          .from('memberships')
          .select('*')
          .eq('user_id', userId)
          .maybeSingle();

      return {
        'success': true,
        'user_id': userId,
        'profile_created': profileCheck != null,
        'membership_created': membershipCheck != null,
        'profile_data': profileCheck,
        'membership_data': membershipCheck,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
