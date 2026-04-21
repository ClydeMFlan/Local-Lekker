# City-Specific Deals - Quick Reference Guide

## Quick Start

### 1. Get User's Current City
```dart
import 'package:local_lekker/services/location_service.dart';

final locationService = LocationService();
final city = await locationService.getCurrentCity();
print('You are in: $city'); // Output: You are in: East London
```

### 2. Get Deals in That City
```dart
import 'package:local_lekker/services/discount_service.dart';

final discountService = DiscountService();
final dealsInCity = await discountService.getActiveDealsInCity(city!);
print('Found ${dealsInCity.length} deals'); // Found 15 deals
```

### 3. Display Deals to User
```dart
ListView.builder(
  itemCount: dealsInCity.length,
  itemBuilder: (context, index) {
    final deal = dealsInCity[index];
    return ListTile(
      title: Text(deal.name),
      subtitle: Text('📍 ${deal.city}'),
      trailing: Text(deal.discountDisplay),
    );
  },
)
```

## LocationService API

### Methods

#### `getCurrentCity() → Future<String?>`
Gets the user's current city with automatic 5-minute caching.
- **Returns:** City name or `null` if unable to determine
- **Caches:** Yes (5 minutes)
- **Permissions:** Requests automatically

```dart
final city = await LocationService().getCurrentCity();
if (city != null) {
  print('Current city: $city');
} else {
  print('Unable to determine city');
}
```

#### `getCurrentPosition() → Future<({double? latitude, double? longitude})>`
Gets raw coordinates for manual processing.

```dart
final pos = await LocationService().getCurrentPosition();
print('${pos.latitude}, ${pos.longitude}');
```

#### `getCityForCoordinates(double lat, double lng) → Future<String?>`
Reverse geocodes specific coordinates to city name.

```dart
final city = await LocationService().getCityForCoordinates(-33.3157, 26.5225);
// Output: Port Elizabeth
```

#### `requestLocationPermission() → Future<bool>`
Explicitly request location permission from user.

```dart
final granted = await LocationService().requestLocationPermission();
if (!granted) {
  print('User denied location permission');
}
```

#### `refreshCurrentCity() → Future<String?>`
Force refresh cached location (ignores cache).

```dart
// Cache will be ignored, fresh location will be fetched
final city = await LocationService().refreshCurrentCity();
```

#### `clearCache() → void`
Clear the cached location data.

```dart
LocationService().clearCache();
```

#### `isLocationServiceEnabled() → Future<bool>`
Check if device has location services enabled.

```dart
if (await LocationService().isLocationServiceEnabled()) {
  // Can use location
} else {
  // Suggest user enable location services
}
```

#### `openLocationSettings() → Future<bool>`
Open device location settings screen (Android/iOS).

```dart
await LocationService().openLocationSettings();
// User redirected to device settings
```

## DiscountService City Methods

### Methods

#### `getActiveDealsInCity(String city) → Future<List<Discount>>`
Get all active deals in a specific city.

```dart
final deals = await DiscountService().getActiveDealsInCity('East London');
// Returns: [Discount, Discount, ...]
```

#### `getAllActiveDeals({String? cityFilter}) → Future<List<Discount>>`
Get all active deals, optionally filtered by city.

```dart
// Get all active deals globally
final allDeals = await DiscountService().getAllActiveDeals();

// Get all active deals with client-side filtering
final cityDeals = await DiscountService().getAllActiveDeals(
  cityFilter: 'Port Elizabeth'
);
```

#### `getNearbyDeals(String currentCity, [List<String>? nearbyAreas]) → Future<List<Discount>>`
Get deals in current city and nearby areas.

```dart
final deals = await DiscountService().getNearbyDeals(
  'East London',
  ['Gqeberhia', 'King William\'s Town'] // Optional nearby areas
);
```

#### `createDiscount({..., String? city}) → Future<Discount>`
Create a new deal with city association.

```dart
final discount = await DiscountService().createDiscount(
  trustedPartnerId: 'partner123',
  name: 'Weekend Special',
  description: 'Get 20% off coffee',
  itemName: 'Cappuccino',
  itemPrice: 45.0,
  percentage: 20,
  city: 'East London', // NEW: Specify city
);
```

## Discount Model

### New Field
- **`city: String?`** - City where deal is available

```dart
final deal = Discount(...);
print('Deal available in: ${deal.city}'); // Output: East London
```

## Common Patterns

### Pattern 1: Show Location-Based Deals in Home Page
```dart
class _MembersHomePageState extends State<MembersHomePage> {
  String? _currentCity;
  List<Discount> _deals = [];

  @override
  void initState() {
    super.initState();
    _loadCityAndDeals();
  }

  Future<void> _loadCityAndDeals() async {
    final city = await LocationService().getCurrentCity();
    if (city != null) {
      final deals = await DiscountService().getActiveDealsInCity(city);
      setState(() {
        _currentCity = city;
        _deals = deals;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Deals in $_currentCity')),
      body: ListView.builder(
        itemCount: _deals.length,
        itemBuilder: (context, index) {
          return DealTile(deal: _deals[index]);
        },
      ),
    );
  }
}
```

### Pattern 2: Handle Location Permission Errors
```dart
try {
  final city = await LocationService().getCurrentCity();
  if (city == null) {
    // Show fallback UI
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Location Not Available'),
        content: const Text('Please enable location services'),
        actions: [
          TextButton(
            onPressed: () async {
              await LocationService().openLocationSettings();
            },
            child: const Text('Enable Location'),
          ),
        ],
      ),
    );
  }
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Error: $e')),
  );
}
```

### Pattern 3: Manual City Selection Fallback
```dart
Future<String?> _selectCity() async {
  const cities = ['East London', 'Port Elizabeth', 'Gqeberhia'];
  
  return showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Select Your City'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: cities.map((city) {
          return ListTile(
            title: Text(city),
            onTap: () => Navigator.pop(context, city),
          );
        }).toList(),
      ),
    ),
  );
}
```

### Pattern 4: Refresh Deals When User Moves
```dart
// Simple timer-based refresh every 5 minutes
Timer.periodic(const Duration(minutes: 5), (_) async {
  final city = await LocationService().refreshCurrentCity();
  if (city != null && mounted) {
    final deals = await DiscountService().getActiveDealsInCity(city);
    setState(() => _deals = deals);
  }
});
```

## Database Queries

### Check Deals by City
```sql
SELECT id, name, city 
FROM trusted_partner_discounts 
WHERE city = 'East London' AND is_active = true;
```

### Update Deal City
```sql
UPDATE trusted_partner_discounts 
SET city = 'Port Elizabeth' 
WHERE id = 'deal_id';
```

### Bulk Update Cities from Business
```sql
UPDATE trusted_partner_discounts tpd
SET city = b.city
FROM businesses b
WHERE tpd.business_id = b.id AND tpd.city IS NULL;
```

### City Statistics
```sql
SELECT city, COUNT(*) as deal_count
FROM trusted_partner_discounts
WHERE is_active = true
GROUP BY city
ORDER BY deal_count DESC;
```

## Troubleshooting

### Location Permission Not Granted
**Problem:** `getCurrentCity()` returns `null`

**Solution:**
```dart
final hasPermission = await LocationService().requestLocationPermission();
if (!hasPermission) {
  await LocationService().openLocationSettings();
}
```

### Reverse Geocoding Returns Unknown
**Problem:** City shows as "Unknown"

**Solution:**
- May occur in remote areas without mapped coordinates
- Implement fallback manual city selection
- Check if coordinates are valid

### Performance Issues
**Problem:** App is slow getting location

**Solution:**
- Use cached result: `getCurrentCity()` caches for 5 minutes
- Don't call repeatedly in loops
- Use `getNearbyDeals()` instead of multiple queries

## Integration Checklist

- [ ] Run database migration: `add_city_filtering_for_deals.sql`
- [ ] Add location permissions to Android `AndroidManifest.xml`
- [ ] Add location descriptions to iOS `Info.plist`
- [ ] Import `LocationService` in home page
- [ ] Import `DiscountService` in home page
- [ ] Call `getCurrentCity()` on init
- [ ] Call `getActiveDealsInCity()` to get filtered deals
- [ ] Display city in app bar or header
- [ ] Add refresh button for location
- [ ] Test on both Android and iOS devices
- [ ] Test with location services disabled
- [ ] Test with permission denied

## Notes

- All methods return `null` gracefully if unavailable
- Logging uses `Logger` package (check debug console)
- City filtering is case-sensitive (use title case)
- Cache is automatic - don't over-call API
- Permissions are persistent once granted
