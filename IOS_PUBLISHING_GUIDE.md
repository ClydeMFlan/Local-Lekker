# iOS Publishing Guide for Local Lekker

## Prerequisites
- **macOS** with Xcode installed (14.0+ recommended)
- **Apple Developer Program** membership ($99/year)
- **Bundle ID**: Use the one in your Xcode project (e.g., `com.locallekker.app`)

## Option 1: Local Build with Xcode (Recommended for First Release)

### Step 1: Configure Xcode Project
```bash
# Open the iOS project in Xcode
open ios/Runner.xcworkspace
```

In Xcode:
1. Select **Runner** target → **Signing & Capabilities**
2. **Team**: Select your Apple Developer account
3. **Bundle Identifier**: Ensure it matches your App Store listing (e.g., `com.locallekker.app`)
4. **Signing Certificate**: Xcode auto-manages or use manual provisioning profiles

### Step 2: Create App Store Connect Listing
1. Go to [App Store Connect](https://appstoreconnect.apple.com/)
2. Click **My Apps** → **+ (New App)**
3. Fill in:
   - **Platform**: iOS
   - **Name**: Local Lekker
   - **Primary Language**: English
   - **Bundle ID**: Select the one registered in your Apple Developer account
   - **SKU**: `local-lekker` (any unique identifier)
4. Complete metadata: Description, screenshots (required sizes: 6.5", 5.5"), keywords, category
5. Upload app icon (1024x1024 PNG without transparency)

### Step 3: Build & Upload IPA
```bash
# From project root
flutter build ipa --release
```

After build completes:
1. Open **Xcode** → **Window** → **Organizer**
2. Select the archive that just built
3. Click **Distribute App** → **App Store Connect** → **Upload**
4. Follow prompts (re-signing, include symbols, upload)

### Step 4: Submit for Review
1. Return to App Store Connect
2. Select your app version → **TestFlight** (builds appear here after processing, ~5-30 min)
3. Once build is processed, go to **App Store** tab
4. Select the build for this version
5. Complete all required sections (pricing, availability, age rating, review notes)
6. **Submit for Review**

---

## Option 2: CI/CD with GitHub Actions

We've created `.github/workflows/ios_unsigned.yml` that builds an unsigned IPA on macOS runners. To sign and upload automatically:

### Enable GitHub Actions Secrets
Add to your repository secrets:
- `APP_STORE_CONNECT_API_KEY_ID`
- `APP_STORE_CONNECT_API_KEY_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY_CONTENT` (base64-encoded .p8 key)
- `IOS_CERTIFICATE_P12` (base64 of your distribution certificate)
- `IOS_CERTIFICATE_PASSWORD`
- `IOS_PROVISIONING_PROFILE` (base64 of .mobileprovision)

### Update workflow to sign and upload
Replace `.github/workflows/ios_unsigned.yml` with a signed version that:
1. Installs certificates and profiles from secrets
2. Runs `flutter build ipa --release` (without `--no-codesign`)
3. Uploads to TestFlight via `altool` or Fastlane

---

## Option 3: Codemagic (Cloud macOS builds, no local Xcode needed)

Create `codemagic.yaml`:
```yaml
workflows:
  ios-release:
    name: iOS Release
    instance_type: mac_mini_m2
    max_build_duration: 60
    environment:
      flutter: stable
      xcode: latest
      groups:
        - app_store_credentials
    scripts:
      - name: Get dependencies
        script: flutter pub get
      - name: Build iOS
        script: |
          flutter build ipa --release \
            --build-name=1.0.0 \
            --build-number=$BUILD_NUMBER \
            --export-options-plist=ios/ExportOptions.plist
    artifacts:
      - build/ios/ipa/*.ipa
    publishing:
      app_store_connect:
        api_key: $APP_STORE_CONNECT_PRIVATE_KEY
        key_id: $APP_STORE_CONNECT_KEY_IDENTIFIER
        issuer_id: $APP_STORE_CONNECT_ISSUER_ID
```

Sign up at [codemagic.io](https://codemagic.io), link your repo, add App Store Connect API key in environment variables.

---

## Troubleshooting

### Missing Permissions (Camera, Photo Library)
✅ Already added to `ios/Runner/Info.plist`:
- `NSCameraUsageDescription`
- `NSPhotoLibraryUsageDescription`
- `NSPhotoLibraryAddUsageDescription`

### Icon Not Displaying
Ensure you have all required app icon sizes in `ios/Runner/Assets.xcassets/AppIcon.appiconset/`:
- 20pt, 29pt, 40pt, 60pt, 76pt, 83.5pt (various @1x, @2x, @3x)
- Use [appicon.co](https://appicon.co) to generate all sizes from a single 1024x1024 PNG

### Build Fails: Signing Issues
- Verify bundle ID in Xcode matches App Store Connect
- Ensure provisioning profile includes your test device UUIDs (for development)
- For distribution: Use App Store provisioning profile (not Ad Hoc or Development)

### TestFlight Build Processing Stuck
- Usually takes 5-30 minutes
- Check email for any compliance issues (export restrictions, encryption declarations)
- If > 1 hour, contact Apple Developer Support

---

## Quick Commands Reference

```bash
# Build unsigned IPA locally (requires manual Xcode signing after)
flutter build ipa --release --no-codesign

# Build and sign via Xcode (auto-uploads if configured)
flutter build ipa --release

# Check iOS build settings
flutter doctor -v

# Clean iOS build cache
cd ios && rm -rf Pods Podfile.lock && pod install --repo-update && cd ..
flutter clean
flutter pub get
```

---

## Next Steps After First Approval
1. **TestFlight**: Internal testing (up to 100 users, no review needed)
2. **External Testing**: Submit build for TestFlight review (faster than App Store)
3. **App Store Release**: After QA, promote build to production
4. **Updates**: Increment `version` in `pubspec.yaml` (e.g., `1.0.1+2`), rebuild, upload

---

**Current Status:**
- ✅ iOS project structure verified
- ✅ Privacy descriptions added to Info.plist
- ✅ GitHub Actions workflow created (unsigned build)
- ⚠️ Manual signing and upload required (or configure CI secrets)

For first-time publishing, **Option 1 (Xcode)** is recommended to familiarize yourself with the flow. Once comfortable, automate with GitHub Actions or Codemagic.
