# Quick Copy-Paste Templates

## Template 1: Standard Watermark at Bottom
```dart
// Add import at top of file
import '../../widgets/creator_watermark.dart';

// In your build method, wrap body in Column
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: const Text('Your Page Title')),
    body: Column(
      children: [
        Expanded(
          child: // YOUR EXISTING CONTENT HERE
        ),
        const CreatorWatermark(), // ← Add this
      ],
    ),
  );
}
```

## Template 2: Compact Watermark (Minimal Space)
```dart
// Add import at top of file
import '../../widgets/creator_watermark.dart';

// In your build method
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: const Text('Your Page Title')),
    body: Column(
      children: [
        Expanded(
          child: // YOUR EXISTING CONTENT HERE
        ),
        const CompactWatermark(size: 24.0), // ← Very small
      ],
    ),
  );
}
```

## Template 3: With SafeArea (Recommended)
```dart
// Add import at top of file
import '../../widgets/creator_watermark.dart';

// In your build method
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: const Text('Your Page Title')),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: // YOUR EXISTING CONTENT HERE
          ),
          const CreatorWatermark(), // ← Add this
        ],
      ),
    ),
  );
}
```

## Template 4: With "Powered by" Text
```dart
// Add import at top of file
import '../../widgets/creator_watermark.dart';

// In your build method
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: const Text('Your Page Title')),
    body: Column(
      children: [
        Expanded(
          child: // YOUR EXISTING CONTENT HERE
        ),
        const CreatorWatermark(
          showText: true,  // Shows "Powered by [logo]"
          height: 35.0,    // Slightly larger
          opacity: 0.6,    // Slightly more visible
        ),
      ],
    ),
  );
}
```

## Template 5: Bottom Navigation with Watermark
```dart
// Add import at top of file
import '../../widgets/creator_watermark.dart';

@override
Widget build(BuildContext context) {
  return Scaffold(
    body: Column(
      children: [
        Expanded(child: _pages[_currentIndex]),
        const CompactWatermark(size: 20.0, opacity: 0.3),
      ],
    ),
    bottomNavigationBar: BottomNavigationBar(
      // Your navigation bar config
    ),
  );
}
```

## Template 6: Existing Column Layout
If you already have a Column in your body:

```dart
// BEFORE:
body: Column(
  children: [
    // Your existing widgets
  ],
),

// AFTER:
body: Column(
  children: [
    // Your existing widgets
    const Spacer(), // Push watermark to bottom if needed
    const CompactWatermark(),
  ],
),
```

## Template 7: Existing ListView Layout
```dart
body: ListView(
  children: [
    // Your existing list items
    
    // Add at the end
    const SizedBox(height: 16),
    const Center(child: CompactWatermark()),
    const SizedBox(height: 16),
  ],
),
```

## Quick Customization Guide

### Size Options:
- `height: 20.0` - Extra small
- `height: 24.0` - Small (default for Compact)
- `height: 30.0` - Standard (default for CreatorWatermark)
- `height: 40.0` - Large

### Opacity Options:
- `opacity: 0.2` - Very subtle
- `opacity: 0.3` - Subtle
- `opacity: 0.4` - Default for Compact
- `opacity: 0.5` - Default for Standard
- `opacity: 0.7` - More visible

### Padding Options:
```dart
CreatorWatermark(
  padding: EdgeInsets.all(4.0),           // All sides
  padding: EdgeInsets.symmetric(vertical: 8.0),  // Top & bottom
  padding: EdgeInsets.only(bottom: 16.0), // Bottom only
)
```

## Files Already Updated (Examples)

✅ **welcome_page.dart** - Standard watermark added at bottom

You can view this file to see a working example!

## Next Files to Update (Suggestions)

Common screens where watermarks look good:
- `lib/features/auth/members_home_page.dart`
- `lib/features/auth/trusted_partner_home_page.dart`
- `lib/features/auth/member_profile_page.dart`
- `lib/features/auth/business_profile_page.dart`
- `lib/features/admin/admin_home_page.dart`

Just copy one of the templates above and adapt to each screen!
