// Example: How to Integrate City-Based Deal Filtering into MembersHomePage
// This file shows the exact code snippets to add to your existing members_home_page.dart

// ============================================================================
// STEP 1: Add imports at the top of members_home_page.dart
// ============================================================================

import '../../services/location_service.dart'; // ADD THIS
import '../../models/discount.dart'; // ADD THIS (if not already imported)

// ============================================================================
// STEP 2: Add member variables to _MembersHomePageState
// ============================================================================

class _MembersHomePageState extends State<MembersHomePage> {
  // ... existing variables ...

  // ADD THESE NEW VARIABLES:
  final LocationService _locationService = LocationService();
  String? _userCurrentCity;
  List<Discount> _dealsInMyCity = [];
  bool _isLoadingCityDeals = false;
  String? _cityError;

  @override
  void initState() {
    super.initState();
    // ... existing initState code ...

    // ADD THIS LINE at the end of initState:
    _loadCityAndDeals(); // NEW: Load city-specific deals
  }

  // ... existing methods ...

  // ========================================================================
  // STEP 3: Add these new methods to load location and city deals
  // ========================================================================

  /// Load user's current city and fetch deals for that city
  Future<void> _loadCityAndDeals() async {
    if (!mounted) return;

    try {
      setState(() => _isLoadingCityDeals = true);

      // Get current city
      final city = await _locationService.getCurrentCity();

      if (city == null) {
        if (mounted) {
          setState(() {
            _cityError =
                'Location not available. Please enable location services.';
            _isLoadingCityDeals = false;
          });
        }
        return;
      }

      // Load deals for this city
      final deals = await DiscountService().getActiveDealsInCity(city);

      if (mounted) {
        setState(() {
          _userCurrentCity = city;
          _dealsInMyCity = deals;
          _isLoadingCityDeals = false;
          _cityError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cityError = 'Error loading deals: $e';
          _isLoadingCityDeals = false;
        });
      }
    }
  }

  /// Refresh location (user taps refresh button)
  Future<void> _refreshCityLocation() async {
    if (!mounted) return;

    try {
      setState(() => _isLoadingCityDeals = true);

      // Force refresh of location
      final city = await _locationService.refreshCurrentCity();

      if (city != null) {
        // Reload deals for new city
        final deals = await DiscountService().getActiveDealsInCity(city);

        if (mounted) {
          setState(() {
            _userCurrentCity = city;
            _dealsInMyCity = deals;
            _isLoadingCityDeals = false;
            _cityError = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cityError = 'Error refreshing location: $e';
          _isLoadingCityDeals = false;
        });
      }
    }
  }

  /// Show dialog to manually select a city
  void _showCitySelector() {
    const cities = [
      'East London',
      'Port Elizabeth',
      'Gqeberhia',
      'King William\'s Town',
      'Mthatha',
      'Umtata',
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Your City'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: cities.map((city) {
              return ListTile(
                leading: _userCurrentCity == city
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
                title: Text(city),
                onTap: () {
                  Navigator.pop(context);
                  _selectCity(city);
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  /// Handle city selection
  Future<void> _selectCity(String city) async {
    try {
      setState(() => _isLoadingCityDeals = true);

      final deals = await DiscountService().getActiveDealsInCity(city);

      if (mounted) {
        setState(() {
          _userCurrentCity = city;
          _dealsInMyCity = deals;
          _isLoadingCityDeals = false;
          _cityError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cityError = 'Error loading deals: $e';
          _isLoadingCityDeals = false;
        });
      }
    }
  }

  // ========================================================================
  // STEP 4: Update the build method to show city information
  // ========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Local Lekker'),
            // ADD THIS: Show current city in subtitle
            if (_userCurrentCity != null)
              Text(
                '📍 $_userCurrentCity',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[400]),
              ),
          ],
        ),
        // ADD THIS: Add action buttons for city management
        actions: [
          // Refresh location button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoadingCityDeals ? null : _refreshCityLocation,
            tooltip: 'Refresh Location',
          ),
          // Change city button
          if (_userCurrentCity != null)
            IconButton(
              icon: const Icon(Icons.location_city),
              onPressed: _showCitySelector,
              tooltip: 'Change City',
            ),
        ],
      ),
      body: _buildBody(), // Use existing or update body building
    );
  }

  // ========================================================================
  // STEP 5: Add a widget to display city deals section
  // ========================================================================

  /// Build a section showing deals available in user's current city
  Widget _buildCityDealsSection() {
    if (_cityError != null) {
      return Card(
        color: Colors.red[50],
        margin: const EdgeInsets.all(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              const Icon(Icons.location_off, color: Colors.red),
              const SizedBox(height: 8),
              Text(
                _cityError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _refreshCityLocation,
                child: const Text('Try Again'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _showCitySelector,
                child: const Text('Select City Manually'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoadingCityDeals) {
      return const Card(
        margin: EdgeInsets.all(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_dealsInMyCity.isEmpty) {
      return Card(
        margin: const EdgeInsets.all(12),
        color: Colors.amber[50],
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Icon(Icons.local_offer_outlined, color: Colors.amber),
              const SizedBox(height: 8),
              Text(
                'No deals available in $_userCurrentCity',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Check back soon!',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    }

    // Show deals list
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Text(
                '${_dealsInMyCity.length} Deals Available',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Chip(
                label: Text(_userCurrentCity ?? ''),
                avatar: const Icon(Icons.location_on, size: 16),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _dealsInMyCity.length,
          itemBuilder: (context, index) {
            final deal = _dealsInMyCity[index];
            return _buildDealTile(deal);
          },
        ),
      ],
    );
  }

  /// Build individual deal tile
  Widget _buildDealTile(Discount deal) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: deal.imageUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  deal.imageUrl!,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) {
                    return Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.image_not_supported),
                    );
                  },
                ),
              )
            : Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.local_offer),
              ),
        title: Text(deal.name),
        subtitle: Text(deal.description),
        trailing: Text(
          deal.discountDisplay,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        onTap: () {
          // Navigate to deal details or show approval dialog
          // Example: Navigator.push(context, MaterialPageRoute(
          //   builder: (_) => DealDetailsPage(deal: deal),
          // ));
        },
      ),
    );
  }

  // ========================================================================
  // STEP 6: Update your existing body building to include city deals
  // ========================================================================

  // In your existing _buildBody() or build() method, add this section
  // at the beginning or wherever makes sense in your UI hierarchy:

  // PSEUDO-CODE for where to add the city deals section:
  //
  // @override
  // Widget build(BuildContext context) {
  //   return Scaffold(
  //     appBar: _buildAppBar(), // Updated as shown above
  //     body: SingleChildScrollView(
  //       child: Column(
  //         children: [
  //           // ADD THIS: City-specific deals section
  //           _buildCityDealsSection(),
  //
  //           // ... rest of existing home page content ...
  //           _buildQRCodeSection(),
  //           _buildSubscriptionStatus(),
  //           // etc.
  //         ],
  //       ),
  //     ),
  //   );
  // }
}

// ============================================================================
// ALTERNATIVE: Use the Complete CityBasedDealsWidget
// ============================================================================

// Instead of integrating piece-by-piece, you can simply use the 
// complete widget we've created:

// import 'package:local_lekker/features/members/city_based_deals_widget.dart';
// 
// class MembersHomePage extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     // Replace entire page with the complete widget
//     return CityBasedDealsWidget();
//   }
// }

// ============================================================================
// INTEGRATION NOTES
// ============================================================================

// 1. The LocationService handles all permission requests automatically
// 2. All error states are handled gracefully with user-friendly messages
// 3. Location is cached for 5 minutes to save battery
// 4. The city can be manually selected by user if location isn't working
// 5. All code follows Local Lekker conventions
// 6. Uses Logger for debugging (check debug console for detailed logs)
// 7. The Discount model now includes the city field
// 8. All database queries are optimized with city indexes
