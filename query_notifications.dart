import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  await Supabase.initialize(
    url: 'https://qdrotavcmmevhgveodcp.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFkcm90YXZjbW1ldmhndmVvZGNwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc1MjAxMzUsImV4cCI6MjA3MzA5NjEzNX0.dbEFbk8StiMbldSjvlMrFs8X3mCpNpGG3wdgxXg8mqo',
  );

  final supabase = Supabase.instance.client;

  // Query pending deal authorizations
  final pendingDeals = await supabase
      .from('deal_authorizations')
      .select('''
        id, business_id, user_id, deal_id, status, created_at, quantity, total_amount, discount_amount, final_amount, payment_method, payment_status, receipt_image_url, processed_at, remarketing_id, is_weight_based, weight_kg, weight_price_per_kg, item_price, deal_data
      ''')
      .eq('status', 'pending');

  print('Pending Deal Authorizations: ${pendingDeals.length}');
  for (var deal in pendingDeals) {
    print(deal);
  }

  // Query notifications for deal requests
  final dealRequestNotifications = await supabase
      .from('notifications')
      .select('''
        id, user_id, type, title, message, data, created_at, read_at
      ''')
      .eq('type', 'deal_request');

  print('\nDeal Request Notifications: ${dealRequestNotifications.length}');
  for (var notif in dealRequestNotifications) {
    print(notif);
  }

  // Query pending deals with their notifications
  final pendingWithNotifications = await supabase
      .from('deal_authorizations')
      .select('''
        id, business_id, user_id, deal_id, status, created_at, quantity, total_amount, discount_amount, final_amount, payment_method, payment_status, receipt_image_url, processed_at, remarketing_id, is_weight_based, weight_kg, weight_price_per_kg, item_price, deal_data,
        notifications!inner(id, user_id, type, title, message, data, created_at, read_at)
      ''')
      .eq('status', 'pending')
      .eq('notifications.type', 'deal_request');

  print(
    '\nPending Deals with Notifications: ${pendingWithNotifications.length}',
  );
  for (var item in pendingWithNotifications) {
    print(item);
  }

  // Check for pending deals without notifications
  final allPending = await supabase
      .from('deal_authorizations')
      .select('id, status, created_at')
      .eq('status', 'pending');

  final allNotifications = await supabase
      .from('notifications')
      .select('data')
      .eq('type', 'deal_request');

  final notificationDealIds = allNotifications
      .map((n) => n['data']['deal_authorization_id'])
      .toSet();

  final pendingWithoutNotifications = allPending
      .where((deal) => !notificationDealIds.contains(deal['id']))
      .toList();

  print(
    '\nPending Deals without Notifications: ${pendingWithoutNotifications.length}',
  );
  for (var deal in pendingWithoutNotifications) {
    print(deal);
  }
}
