# Play Store Publishing Checklist - Local Lekker

## 📦 Build Status
- ⏳ Building AAB: `flutter build appbundle --release`
- 📍 Output location: `build/app/outputs/bundle/release/app-release.aab`

## ✅ Pre-Publishing Checklist

### 1. App Signing
- [ ] **Upload key configured** - Check `android/key.properties` exists
- [ ] **Keystore file secure** - Located at path specified in `key.properties`
- [ ] **Play App Signing enabled** - Google manages signing in production

### 2. App Information
- **Package Name**: Check `android/app/build.gradle` → `applicationId`
- **Version**: `1.0.0+1` (from pubspec.yaml)
  - Version name: `1.0.0`
  - Version code: `1`

### 3. Required Assets for Play Store Listing
- [ ] **App Icon** - 512x512 PNG (high-res icon)
- [ ] **Feature Graphic** - 1024x500 PNG
- [ ] **Screenshots** - At least 2 per device type:
  - Phone: 16:9 or 9:16 aspect ratio
  - 7-inch tablet (optional)
  - 10-inch tablet (optional)
- [ ] **Privacy Policy URL** - Required for apps with user data
- [ ] **App description** (short & full)
- [ ] **App category** - Finance/Business

### 4. Google Play Console Steps

#### Create App (First Time Only)
1. Go to [Google Play Console](https://play.google.com/console)
2. Click **Create App**
3. Fill in:
   - App name: **Local Lekker**
   - Default language: English (United States)
   - App type: App
   - Free/Paid: Free (with in-app purchases/subscriptions)
4. Accept declarations

#### Complete Store Listing
1. **Main Store Listing** → Set up
   - App name: Local Lekker
   - Short description (80 chars max)
   - Full description (4000 chars max)
   - Upload graphics (icon, feature graphic, screenshots)
   - Categorization: Finance or Business
   - Contact details (email, privacy policy, website)

2. **Content Rating**
   - Fill out questionnaire
   - Select: Business/Finance app with payment features

3. **App Content**
   - Privacy policy URL
   - Ads declaration (None, assuming no ads)
   - Target audience and content
   - Data safety form (critical!)

4. **Pricing & Distribution**
   - Countries: South Africa (or worldwide)
   - Pricing: Free
   - Contains ads: No
   - In-app purchases: Yes (subscriptions)

#### Upload Release

1. **Production Track** (or Internal/Closed Testing first)
2. Click **Create new release**
3. Upload `app-release.aab`
4. Add release notes:
   ```
   Initial release of Local Lekker
   - Smart receipt scanning with OCR
   - QR code payments at local businesses
   - Instant member discounts
   - Subscription-based membership
   ```
5. Review and roll out

### 5. Data Safety Section (CRITICAL)
Google requires detailed privacy disclosures:

**Data collected**:
- [ ] Email addresses (account creation)
- [ ] Phone numbers (authentication)
- [ ] Payment information (Paystack integration)
- [ ] Location data (business discovery)
- [ ] Files and docs (receipt scanning)

**Data usage**:
- [ ] Account management
- [ ] App functionality
- [ ] Fraud prevention

**Data sharing**:
- [ ] Payment processor (Paystack)
- [ ] Analytics (if any)

**Security practices**:
- [ ] Data encrypted in transit
- [ ] Data encrypted at rest (Supabase)
- [ ] Users can request deletion

### 6. Testing Recommendations
**Before production release:**
- [ ] Internal testing track (max 100 testers)
- [ ] Closed testing track (invite beta testers)
- [ ] Test on multiple devices
- [ ] Test payment flows end-to-end
- [ ] Verify Paystack production mode enabled

## 🚀 Build Commands

### Build AAB (Play Store)
```bash
flutter build appbundle --release
```

### Build APK (Direct distribution/testing)
```bash
flutter build apk --release
```

### Using build script (runs tests + builds both)
```bash
bash build_production.sh
```

## 📱 After Upload

### Monitor Pre-Launch Report
- Google automatically tests on ~20 devices
- Check for crashes, UI issues
- Review device compatibility

### Release Rollout Options
1. **Internal Testing** - Quick upload, no review (up to 100 testers)
2. **Closed Testing** - Invite specific testers, no review
3. **Open Testing** - Public beta, minimal review
4. **Production** - Full release, full review (24-48 hours)

### Post-Release Monitoring
- [ ] Crashlytics/Firebase setup (recommended)
- [ ] Monitor Play Console crash reports
- [ ] Track user reviews
- [ ] Monitor subscription metrics

## 🔑 Important Files

- **Keystore**: Keep secure backup! Cannot republish without it
- **AAB file**: `build/app/outputs/bundle/release/app-release.aab`
- **key.properties**: Never commit to Git (in .gitignore)

## 📋 Supabase Production Checklist
- [ ] Verify SUPABASE_URL is production
- [ ] Verify SUPABASE_ANON_KEY is production
- [ ] PAYSTACK_SANDBOX=false in .env
- [ ] All RLS policies enabled
- [ ] Database backups configured

## 🎯 Quick Upload Steps (After Build Completes)

1. Wait for build to complete
2. Locate AAB: `build/app/outputs/bundle/release/app-release.aab`
3. Go to Play Console → Your App → Production
4. Create new release
5. Upload `app-release.aab`
6. Add release notes
7. Review → Roll out to production
8. Wait 24-48 hours for review

## ⚠️ Common Issues

**Issue**: "App not signed properly"
- **Fix**: Check `android/key.properties` and keystore path

**Issue**: "Version code conflict"
- **Fix**: Increment version code in `pubspec.yaml` (e.g., `1.0.0+2`)

**Issue**: "Missing privacy policy"
- **Fix**: Host privacy policy and add URL in store listing

**Issue**: "Permissions need justification"
- **Fix**: Add permission usage in app content section

## 📞 Support Resources

- [Play Console Help](https://support.google.com/googleplay/android-developer)
- [App Bundle Format](https://developer.android.com/guide/app-bundle)
- [Flutter Build Docs](https://docs.flutter.dev/deployment/android)
