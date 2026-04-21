import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  // Load environment variables
  await dotenv.load();

  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  final client = Supabase.instance.client;

  print('\n========== CHECKING MEMBERS TERMS ACCEPTANCE ==========\n');

  try {
    final members = await client
        .from('profiles')
        .select(
          'id, email, name, surname, role, member_terms_accepted, member_terms_accepted_at, subscription, verified, created_at',
        )
        .eq('role', 'member')
        .order('created_at', ascending: false);

    if (members.isEmpty) {
      print('No members found.\n');
    } else {
      print('Total Members: ${members.length}\n');
      for (var member in members) {
        print('─' * 80);
        print('Email: ${member['email']}');
        print('Name: ${member['name']} ${member['surname']}');
        print(
          'Member Terms Accepted: ${member['member_terms_accepted']} (${_statusEmoji(member['member_terms_accepted'])})',
        );
        if (member['member_terms_accepted_at'] != null) {
          print('Accepted At: ${member['member_terms_accepted_at']}');
        }
        print('Subscription: ${member['subscription']}');
        print('Verified: ${member['verified']}');
        print('Created: ${member['created_at']}');
      }
      print('─' * 80);
    }
  } catch (e) {
    print('Error fetching members: $e');
  }

  print('\n========== CHECKING TRUSTED PARTNERS TERMS ACCEPTANCE ==========\n');

  try {
    final partners = await client
        .from('profiles')
        .select(
          'id, email, name, surname, role, partner_terms_accepted, partner_terms_accepted_at, subscription, verified, is_tp_member, created_at',
        )
        .eq('role', 'trusted_partner')
        .order('created_at', ascending: false);

    if (partners.isEmpty) {
      print('No trusted partners found.\n');
    } else {
      print('Total Trusted Partners: ${partners.length}\n');
      for (var partner in partners) {
        print('─' * 80);
        print('Email: ${partner['email']}');
        print('Name: ${partner['name']} ${partner['surname']}');
        print(
          'Partner Terms Accepted: ${partner['partner_terms_accepted']} (${_statusEmoji(partner['partner_terms_accepted'])})',
        );
        if (partner['partner_terms_accepted_at'] != null) {
          print('Accepted At: ${partner['partner_terms_accepted_at']}');
        }
        print('Is TP Member: ${partner['is_tp_member']}');
        print('Subscription: ${partner['subscription']}');
        print('Verified: ${partner['verified']}');
        print('Created: ${partner['created_at']}');
      }
      print('─' * 80);
    }
  } catch (e) {
    print('Error fetching trusted partners: $e');
  }

  print('\n========== SUMMARY ==========\n');

  try {
    // Count members with and without terms accepted
    final memberStats = await client
        .from('profiles')
        .select('member_terms_accepted')
        .eq('role', 'member');
    final membersAccepted = memberStats
        .where((m) => m['member_terms_accepted'] == true)
        .length;
    final membersPending = memberStats
        .where((m) => m['member_terms_accepted'] != true)
        .length;

    print('Members:');
    print('  ✅ Accepted Terms: $membersAccepted');
    print('  ⏳ Pending Terms: $membersPending');

    // Count partners with and without terms accepted
    final partnerStats = await client
        .from('profiles')
        .select('partner_terms_accepted')
        .eq('role', 'trusted_partner');
    final partnersAccepted = partnerStats
        .where((p) => p['partner_terms_accepted'] == true)
        .length;
    final partnersPending = partnerStats
        .where((p) => p['partner_terms_accepted'] != true)
        .length;

    print('\nTrusted Partners:');
    print('  ✅ Accepted Terms: $partnersAccepted');
    print('  ⏳ Pending Terms: $partnersPending');
  } catch (e) {
    print('Error generating summary: $e');
  }

  print('\nDone!\n');
  exit(0);
}

String _statusEmoji(bool? value) {
  if (value == true) {
    return '✅ TRUE';
  } else if (value == false) {
    return '❌ FALSE';
  } else {
    return '⚠️ NULL';
  }
}
