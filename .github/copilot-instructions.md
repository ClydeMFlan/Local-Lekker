# Local Lekker - AI Agent Instructions

## Project Overview
Local Lekker is a Flutter mobile app for **smart receipt scanning and local business payments** with instant discounts. It's a **subscription-based platform** connecting members with local businesses through QR code payments and OCR-powered receipt processing.

## Architecture & Key Flows

### Core Architecture Pattern
- **Singleton services** (`_instance` pattern) - All services (SupabaseService, SubscriptionService, QrCodeService, etc.) use singleton pattern with factory constructors
- **Feature-based organization** - `lib/features/` divided by user roles: `auth/`, `admin/`, `business/`, `payments/`, `chat/`
- **Role-based navigation** - Three roles drive app flow: `member`, `trusted_partner`, `admin`

### Authentication & Role Management
```dart
// Role determination happens in SupabaseService.getUserRole()
// Checks: profiles.role -> memberships.role -> admin_dashboard -> defaults to 'member'
final role = await SupabaseService.instance.getUserRole(userId: userId);
```

**Critical**: Never hardcode role strings. Use role checks consistently:
- Members: Regular users with subscriptions and QR codes
- Trusted Partners: Businesses that accept payments and scan receipts
- Admin: Platform management via `admin_dashboard` table

### Payment & Subscription Flow
1. **Signup** → `PaymentRequiredScreen` → `PaymentOptionsScreen` (Paystack integration)
2. **Payment success** → `SubscriptionService.createInitialSubscription()` creates:
   - Entry in `subscriptions` table (30-day period)
   - QR code in `user_qr_codes` table via `QrCodeService`
3. **Renewal**: Auto-renew (Paystack) or manual payment with countdown timer
4. **Offline handling**: `PaymentStatusService` uses `SharedPreferences` for pending payments

### Receipt Processing Pipeline
```dart
// Receipt scanning uses BusinessBillService + ReceiptParserService
// Flow: Camera → Image → ML Kit OCR → Template matching → Supabase storage
ReceiptData data = await ReceiptParserService().parseReceipt(imageBytes, template);
```

**Templates**: `ReceiptTemplate` enum supports: generic, thermal, woolworths, pickNPay, spar, checkers, businessBill

### Database & Security (Supabase)
- **RLS (Row Level Security)** enabled on all tables - policies in `unified_schema_rls_policies.sql`
- **Key tables**: `profiles`, `subscriptions`, `user_qr_codes`, `businesses`, `deal_authorizations`, `processed_bills`, `trusted_partner_discounts`, `notifications`
- **Storage buckets**: `business-bills`, `receipt-images` with RLS policies
- **Foreign keys**: Use `add_foreign_keys.sql` pattern for relationships

## Development Conventions

### Logging Pattern
Always use Logger (not print) with semantic levels:
```dart
import 'package:logger/logger.dart';

final Logger _logger = Logger();
_logger.i('Info message');  // Info
_logger.w('Warning');       // Warning
_logger.e('Error: $e');     // Error
_logger.d('Debug detail');  // Debug
```

### Navigation Pattern
Use `Navigator.pushReplacement` for role-based flows, avoid back button traps:
```dart
Navigator.pushReplacement(
  context,
  MaterialPageRoute(builder: (context) => MembersHomePage()),
);
```

For deep links: `DeepLinkService` handles auth callbacks from Supabase (`auth/callback`)

### Error Handling Pattern
```dart
try {
  // Supabase operation
} catch (e) {
  if (e.toString().contains('over_email_send_rate_limit')) {
    throw Exception('Too many attempts. Please wait...');
  }
  if (e.toString().contains('token') || e.toString().contains('grant')) {
    throw Exception('Authentication failed. Please try again...');
  }
  rethrow;
}
```

### State Management
- Primarily **StatefulWidget** with local state
- Use `setState()` for UI updates after async operations
- No external state management (Redux/Bloc) - keep it simple

## Critical Integration Points

### Environment Variables (.env)
```env
SUPABASE_URL=https://qdrotavcmmevhgveodcp.supabase.co
SUPABASE_ANON_KEY=...
PAYSTACK_PUBLIC_KEY=pk_live_...
PAYSTACK_SECRET_KEY=sk_live_...
PAYSTACK_SANDBOX=false  # Production mode
```

**Never commit real credentials** - use `.env.template` for examples

### QR Code Security
- `QrCodeService.buildSecureQrCode()` includes screenshot protection
- QR codes expire after 30 days (tracked in `user_qr_codes.expires_at`)
- Security warning dialog on first QR view

### ML Kit Integration
- **Text recognition**: `google_mlkit_text_recognition` for OCR
- **Image labeling**: `google_mlkit_image_labeling` for receipt classification
- **Permissions**: Camera + storage via `permission_handler`

## Build & Deploy

### Development
```bash
flutter pub get
flutter run  # Debug mode
```

### Production Build
```bash
./build_production.sh  # Runs tests, analysis, builds APK + AAB
# Outputs:
# - build/app/outputs/flutter-apk/app-release.apk
# - build/app/outputs/bundle/release/app-release.aab
```

### Testing
```bash
flutter test              # Unit tests
flutter analyze           # Static analysis
```

Tests in `test/` - primarily widget tests and flow validation

## Database Migrations

SQL files in root are **migration scripts**, not application code:
- `unified_schema_rls_policies.sql` - Complete schema with RLS
- `check_*.sql` - Diagnostic queries
- `add_*.sql` - Incremental changes
- `fix_*.sql` - Production hotfixes

**Always test RLS policies** with role-specific queries before deploying.

## Common Pitfalls

1. **Role checks**: Always use `getUserRole()`, never assume role from session
2. **QR code regeneration**: Only on subscription renewal, not on every view
3. **Payment status**: Check both Supabase (`subscriptions`) AND SharedPreferences (pending)
4. **Supabase client**: Use `SupabaseService.instance.client`, never create new instances
5. **Image uploads**: Use `business-bills` bucket for bills, `receipt-images` for user receipts
6. **Deep links**: Must handle both initial launch and runtime in `DeepLinkService`

## Key Files to Reference

- **Main entry**: `lib/main.dart` - App initialization sequence
- **Auth flow**: `lib/features/auth/welcome_page.dart` - Entry point for unauthenticated users
- **Service layer**: `lib/services/supabase_service.dart` - 1331 lines, core data operations
- **Receipt parsing**: `lib/services/receipt_parser_service.dart` - OCR + template logic
- **Subscription logic**: `lib/services/subscription_service.dart` - QR + payment lifecycle
- **Schema reference**: `unified_schema_rls_policies.sql` - Complete database structure

## When Making Changes

1. **Adding features**: Follow role-based structure in `lib/features/{role}/`
2. **New services**: Use singleton pattern, add to `lib/services/`
3. **Database changes**: Write SQL migration + RLS policies, test with all roles
4. **UI changes**: Maintain consistent Material Design theme from `lib/core/theme/`
5. **Payment flows**: Always update both Supabase tables AND SharedPreferences cache
