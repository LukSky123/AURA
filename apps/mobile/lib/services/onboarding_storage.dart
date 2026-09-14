import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain.dart';

class OnboardingStorage {
  static const String keyCompleted = 'has_completed_onboarding';
  static const String keyContacts = 'saved_emergency_contacts';

  static Future<bool> hasCompletedOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyCompleted) ?? false;
  }

  static Future<void> setCompletedOnboarding(bool completed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyCompleted, completed);
  }

  static Future<void> saveContacts(List<TrustedContact> contacts) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = contacts.map((c) => {
      'id': c.id,
      'name': c.name,
      'phone': c.phone,
    }).toList();
    await prefs.setString(keyContacts, jsonEncode(jsonList));
  }

  static Future<List<TrustedContact>> loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(keyContacts);
    if (str == null || str.isEmpty) {
      return const [
        TrustedContact(id: 'c1', name: 'Mum', phone: '+2348011112222'),
        TrustedContact(id: 'c2', name: 'Brother', phone: '+2348033334444'),
      ];
    }
    try {
      final decoded = jsonDecode(str) as List;
      return decoded.map((item) {
        final m = item as Map<String, dynamic>;
        return TrustedContact(
          id: m['id'] as String? ?? '',
          name: m['name'] as String? ?? '',
          phone: m['phone'] as String? ?? '',
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyCompleted);
  }
}
