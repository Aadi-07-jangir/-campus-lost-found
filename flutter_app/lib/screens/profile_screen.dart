import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/items_provider.dart';
import '../utils/theme.dart';
import 'login_screen.dart';
import 'item_detail_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override void initState() { super.initState(); WidgetsBinding.instance.addPostFrameCallback((_) => context.read<ItemsProvider>().fetchMyItems()); }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final items$ = context.watch<ItemsProvider>();
    final myItems = items$.myItems;
    final lost = myItems.where((i) => i.isLost).length;
    final found = myItems.where((i) => i.isFound).length;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Text('Profile', style: Theme.of(context).textTheme.headlineMedium),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.logout_rounded), onPressed: () async {
                      await auth.logout();
                      if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
                    }),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg.withOpacity(0.82),
                    borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          gradient: AppTheme.accentGradient,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: CircleAvatar(
                          radius: 42,
                          backgroundColor: AppTheme.surfaceSoft,
                          child: Text(
                            auth.userName.isNotEmpty ? auth.userName[0].toUpperCase() : '?',
                            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(auth.userName, style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
                      const SizedBox(height: 6),
                      Text(auth.userEmail, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  _Stat('Total', '${myItems.length}', AppTheme.primary),
                  const SizedBox(width: 12), _Stat('Lost', '$lost', AppTheme.lostColor),
                  const SizedBox(width: 12), _Stat('Found', '$found', AppTheme.foundColor),
                ]),
                const SizedBox(height: 22),
                Align(alignment: Alignment.centerLeft, child: Text('My Reports', style: Theme.of(context).textTheme.titleLarge)),
                const SizedBox(height: 12),
                if (myItems.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBg.withOpacity(0.72),
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Text('No items reported yet', style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
                  )
                else
                  ...myItems.map((item) => Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ItemDetailScreen(item: item))),
                      leading: ClipRRect(borderRadius: BorderRadius.circular(10),
                        child: Image.network(items$.getImageUrl(item.imageFileId), width: 54, height: 54, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(width: 54, height: 54, color: AppTheme.surfaceMuted, child: const Icon(Icons.image, size: 24, color: AppTheme.textHint)))),
                      title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      subtitle: Text('${item.type.toUpperCase()} • ${item.status}', style: TextStyle(color: item.isLost ? AppTheme.lostColor : AppTheme.foundColor, fontSize: 12, fontWeight: FontWeight.w700)),
                      trailing: const Icon(Icons.chevron_right, color: AppTheme.textHint),
                    ),
                  )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label; final String value; final Color color;
  const _Stat(this.label, this.value, this.color);
  @override Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 18),
    decoration: BoxDecoration(
      color: color.withOpacity(0.10),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withOpacity(0.20)),
    ),
    child: Column(children: [
      Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color)),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
    ]),
  ));
}
