import 'package:flutter/material.dart';
import 'theme.dart';

/// Auto-detected item categories based on title & description keywords.
/// No database changes required — purely client-side intelligence.
class ItemCategory {
  final String name;
  final IconData icon;
  final Color color;
  final List<String> keywords;

  const ItemCategory({
    required this.name,
    required this.icon,
    required this.color,
    required this.keywords,
  });

  static const List<ItemCategory> all = [
    ItemCategory(
      name: 'Phone',
      icon: Icons.phone_android_rounded,
      color: Color(0xFF42A5F5),
      keywords: ['phone', 'iphone', 'samsung', 'mobile', 'pixel', 'oneplus', 'redmi', 'realme', 'oppo', 'vivo', 'smartphone', 'android', 'cellphone'],
    ),
    ItemCategory(
      name: 'Laptop',
      icon: Icons.laptop_mac_rounded,
      color: Color(0xFF66BB6A),
      keywords: ['laptop', 'macbook', 'notebook', 'chromebook', 'dell', 'hp', 'lenovo', 'thinkpad', 'asus', 'acer', 'computer'],
    ),
    ItemCategory(
      name: 'Wallet',
      icon: Icons.account_balance_wallet_rounded,
      color: Color(0xFFFF7043),
      keywords: ['wallet', 'purse', 'billfold', 'money', 'cash', 'cards', 'card holder'],
    ),
    ItemCategory(
      name: 'Keys',
      icon: Icons.key_rounded,
      color: Color(0xFFFFCA28),
      keywords: ['key', 'keys', 'keychain', 'car key', 'bike key', 'room key', 'locker'],
    ),
    ItemCategory(
      name: 'ID Card',
      icon: Icons.badge_rounded,
      color: Color(0xFFAB47BC),
      keywords: ['id', 'card', 'identity', 'badge', 'student id', 'aadhar', 'pan', 'driving license', 'passport', 'college id'],
    ),
    ItemCategory(
      name: 'Bag',
      icon: Icons.backpack_rounded,
      color: Color(0xFF26C6DA),
      keywords: ['bag', 'backpack', 'handbag', 'suitcase', 'briefcase', 'tote', 'pouch', 'sling'],
    ),
    ItemCategory(
      name: 'Headphones',
      icon: Icons.headphones_rounded,
      color: Color(0xFFEC407A),
      keywords: ['headphone', 'earphone', 'airpod', 'earbud', 'earbuds', 'headset', 'buds', 'speaker', 'bluetooth'],
    ),
    ItemCategory(
      name: 'Watch',
      icon: Icons.watch_rounded,
      color: Color(0xFF8D6E63),
      keywords: ['watch', 'smartwatch', 'band', 'apple watch', 'fitbit', 'wristwatch'],
    ),
    ItemCategory(
      name: 'Glasses',
      icon: Icons.visibility_rounded,
      color: Color(0xFF78909C),
      keywords: ['glasses', 'spectacles', 'sunglasses', 'shades', 'specs', 'eyewear'],
    ),
    ItemCategory(
      name: 'Other',
      icon: Icons.category_rounded,
      color: AppTheme.textSecondary,
      keywords: [],
    ),
  ];

  /// Detect category from title + description using keyword matching.
  static ItemCategory detect(String title, String description) {
    final text = '${title.toLowerCase()} ${description.toLowerCase()}';
    for (final cat in all) {
      if (cat.keywords.isEmpty) continue; // skip "Other"
      for (final keyword in cat.keywords) {
        if (text.contains(keyword)) return cat;
      }
    }
    return all.last; // "Other"
  }
}
