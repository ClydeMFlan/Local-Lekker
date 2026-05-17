import 'package:flutter/material.dart';
import 'admin_overview_screen.dart';
import 'admin_members_screen.dart';
import 'admin_partners_screen.dart';
import 'admin_promotions_screen.dart';
import 'admin_settings_screen.dart';
import 'admin_support_inbox_screen.dart';
import 'widgets/admin_promo_key_dialog.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _currentIndex = 0;

  static const _titles = [
    'Admin Dashboard',
    'Manage Members',
    'Manage Partners',
    'Promotions',
    'Support',
    'Settings',
  ];

  static const _screens = <Widget>[
    AdminOverviewScreen(),
    AdminMembersScreen(),
    AdminPartnersScreen(),
    AdminPromotionsScreen(),
    AdminSupportInboxScreen(),
    AdminSettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        centerTitle: false,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.vpn_key, color: Colors.orange),
            tooltip: 'Generate Promo Key',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const AdminPromoKeyDialog(),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Members',
          ),
          NavigationDestination(
            icon: Icon(Icons.store_outlined),
            selectedIcon: Icon(Icons.store),
            label: 'Partners',
          ),
          NavigationDestination(
            icon: Icon(Icons.campaign_outlined),
            selectedIcon: Icon(Icons.campaign),
            label: 'Promos',
          ),
          NavigationDestination(
            icon: Icon(Icons.support_agent_outlined),
            selectedIcon: Icon(Icons.support_agent),
            label: 'Support',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
