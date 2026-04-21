# City-Specific Deal Filtering Implementation

## Overview
Local Lekker now supports city-specific deal filtering. Members will see deals only in the area they are currently in (East London, Port Elizabeth, etc.). The app uses live geolocation to detect the user's current city and filters available deals accordingly.

## Architecture

### Components Added

#### 1. LocationService (`lib/services/location_service.dart`)
A singleton service that handles all geolocation and city detection operations.

**Key Methods:**
- `getCurrentCity()` - Gets the user's current city with 5-minute caching
- `getCurrentPosition()` - Returns latitude/longitude coordinates
- `getCityForCoordinates(lat, lng)` - Reverse geocodes coordinates to city name
- `requestLocationPermission()` - Handles location permission requests
- `refreshCurrentCity()` - Forces a fresh location lookup
- `isLocationServiceEnabled()` - Checks if device has location services enabled
- `openLocationSettings()` - Opens device location settings

**Features:**
- Automatic caching to reduce API calls (5-minute default)
- Graceful error handling
- Comprehensive logging with Logger
- Support for both Android and iOS

#### 2. Enhanced Discount Model (`lib/models/discount.dart`)
Added `city` field to the Discount class to store which city a deal is available in.

#### 3. City-Filtering Methods in DiscountService (`lib/services/discount_service.dart`)

**New Methods:**

- **`getActiveDealsInCity(String city)`** - Returns deals active in a specific city
  ```dart
  final deals = await DiscountService().getActiveDealsInCity('East London');
  ```

- **`getAllActiveDeals({String? cityFilter})`** - Gets all active deals with optional city filtering
  ```dart
  // Get all deals
  final allDeals = await DiscountService().getAllActiveDeals();
  
  // Get deals in specific city
  final cityDeals = await DiscountService().getAllActiveDeals(cityFilter: 'Port Elizabeth');
  ```

- **`getNearbyDeals(String currentCity, [List<String>? nearbyAreas])`** - Gets deals in current city and nearby areas
  ```dart
  final deals = await DiscountService().getNearbyDeals(
    'East London',
    ['Gqeberhia', 'King William\'s Town'] // nearby areas
  );
  ```

#### 4. Database Schema Updates (`add_city_filtering_for_deals.sql`)
- Added `city` column to `trusted_partner_discounts` table
- Added `city` column to `businesses` table
- Created indexes on city columns for performance
- Updated RLS policies to support city-based filtering

## Implementation Steps

### 1. Database Migration
Run the migration SQL file in your Supabase console:
```sql
-- Execute: add_city_filtering_for_deals.sql
```

This will:
- Add `city` column to both tables
- Create performance indexes
- Update RLS policies

### 2. Install Dependencies
The `geolocator` and `geocoding` packages have already been added to `pubspec.yaml`:
```bash
flutter pub get
```

### 3. Add Permissions (Android & iOS)

#### Android (`android/app/src/main/AndroidManifest.xml`)
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

#### iOS (`ios/Runner/Info.plist`)
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Local Lekker needs your location to show you deals from businesses in your area</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Local Lekker needs your location to show you deals from businesses in your area</string>
```

### 4. Integration in UI

#### Example: Update MembersHomePage to Show City-Filtered Deals

```dart
import '../../services/location_service.dart';
import '../../services/discount_service.dart';

class _MembersHomePageState extends State<MembersHomePage> {
  final LocationService _locationService = LocationService();
  final DiscountService _discountService = DiscountService();
  
  String? _currentCity;
  List<Discount> _dealsInMyCity = [];
  bool _isLoadingLocation = true;

  @override
  void initState() {
    super.initState();
    _loadLocationAndDeals();
  }

  Future<void> _loadLocationAndDeals() async {
    try {
      // Get user's current city
      final city = await _locationService.getCurrentCity();
      
      if (city != null && mounted) {
        setState(() {
          _currentCity = city;
        });
        
        // Load deals for this city
        final deals = await _discountService.getActiveDealsInCity(city);
        
        if (mounted) {
          setState(() {
            _dealsInMyCity = deals;
            _isLoadingLocation = false;
          });
        }
      }
    } catch (e) {
      _logger.e('Error loading location: $e');
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _currentCity != null 
          ? Text('Deals in $_currentCity')
          : const Text('Local Lekker'),
        actions: [
          // Add refresh button to update location
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLocationAndDeals,
          ),
        ],
      ),
      body: _isLoadingLocation
        ? const Center(child: CircularProgressIndicator())
        : _dealsInMyCity.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('No deals available in $_currentCity'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadLocationAndDeals,
                    child: const Text('Refresh Location'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _dealsInMyCity.length,
              itemBuilder: (context, index) {
                final deal = _dealsInMyCity[index];
                return DealTile(deal: deal);
              },
            ),
    );
  }
}
```

## Usage Patterns

### Pattern 1: Get Deals in Current Location
```dart
final locationService = LocationService();
final discountService = DiscountService();

// Get user's city
final city = await locationService.getCurrentCity();

// Get deals in that city
final deals = await discountService.getActiveDealsInCity(city!);
```

### Pattern 2: Show Current Location to User
```dart
final city = await locationService.getCurrentCity();
print('🏙️ You are in: $city');
```

### Pattern 3: Get Nearby Deals (Current City + Adjacent Areas)
```dart
final deals = await discountService.getNearbyDeals(
  'East London',
  ['Gqeberhia', 'King William\'s Town']
);
```

### Pattern 4: Trusted Partner Creating a Deal
When a trusted partner creates a deal, specify the city:
```dart
await discountService.createDiscount(
  trustedPartnerId: partnerId,
  name: 'Weekend Special',
  description: 'Get 20% off',
  itemName: 'Coffee',
  itemPrice: 45.0,
  percentage: 20,
  city: 'East London', // City-specific!
);
```

## Key Features

### Automatic Caching
- Location is cached for 5 minutes by default
- Reduces battery drain and API calls
- Use `refreshCurrentCity()` to force update

### Permission Handling
- Automatically requests location permission on first access
- Gracefully handles permission denial
- Provides fallback UI when permissions denied

### Error Resilience
- Handles network errors in reverse geocoding
- Falls back gracefully if location unavailable
- Comprehensive logging for debugging

### Privacy & Security
- Uses on-device geocoding (no data sent to external services)
- Location data not stored permanently
- User must grant permission explicitly

## Testing

### Test Location Filtering
```dart
// In your test code
final locationService = LocationService();
final discountService = DiscountService();

// Mock a city (in test environment)
final deals = await discountService.getActiveDealsInCity('Test City');

// Verify filtering works
expect(deals.every((d) => d.city == 'Test City'), true);
```

### Debug Location Service
```dart
// Check if location services enabled
final enabled = await LocationService().isLocationServiceEnabled();
print('Location services enabled: $enabled');

// Get raw coordinates
final pos = await LocationService().getCurrentPosition();
print('Position: ${pos.latitude}, ${pos.longitude}');
```

## Troubleshooting

### Location Not Working

1. **Check Permissions**
   - iOS: Verify `Info.plist` has location descriptions
   - Android: Verify `AndroidManifest.xml` has permissions

2. **Check Location Services**
   ```dart
   final enabled = await LocationService().isLocationServiceEnabled();
   if (!enabled) {
     // Suggest user enable location services
     await LocationService().openLocationSettings();
   }
   ```

3. **Reverse Geocoding Fails**
   - May return "Unknown" city if coordinates don't map
   - Consider adding fallback UI

### Performance Issues

- Location caching is automatic (5 minutes)
- Adjust cache duration in `LocationService._cacheDurationMinutes`
- Use `getNearbyDeals()` instead of multiple `getActiveDealsInCity()` calls

## Database Maintenance

### Query Deals by City
```sql
SELECT id, name, city, is_active 
FROM trusted_partner_discounts 
WHERE city = 'East London' AND is_active = true;
```

### Update Deals City
```sql
UPDATE trusted_partner_discounts 
SET city = 'New City' 
WHERE trusted_partner_id = 'partner_id';
```

### Check City Coverage
```sql
SELECT DISTINCT city, COUNT(*) as deal_count
FROM trusted_partner_discounts
WHERE is_active = true
GROUP BY city
ORDER BY deal_count DESC;
```

## Future Enhancements

1. **Radius-Based Search** - Find deals within X km radius
2. **City Suggestions** - Autocomplete city names
3. **Multi-City Subscriptions** - Members can follow multiple cities
4. **Notifications** - Notify when new deals appear in user's city
5. **Search & Filter UI** - UI to manually select different cities
6. **Location History** - Track where member visited/worked
7. **Travel Mode** - Show deals from visited cities recently

## Notes

- The `city` field is nullable for backward compatibility
- Existing deals without a city will still be visible (not filtered)
- Consider bulk updating existing deals with city information
- Test thoroughly in both Android and iOS before release
