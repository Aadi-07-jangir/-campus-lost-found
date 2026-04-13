import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/item_model.dart';
import '../providers/items_provider.dart';
import '../utils/theme.dart';
import 'item_detail_screen.dart';
import 'chat_screen.dart';

class MatchesScreen extends StatelessWidget {
  final ItemModel reportedItem;
  const MatchesScreen({super.key, required this.reportedItem});

  @override
  Widget build(BuildContext context) {
    final items$ = context.watch<ItemsProvider>();
    final matches = items$.matches;

    return Scaffold(
      appBar: AppBar(title: const Text('AI Matches Found!')),
      body: matches.isEmpty
        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.search_off, size: 64, color: AppTheme.textHint), const SizedBox(height: 16),
            Text('No matches found', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 8),
            Text("We'll notify you when a match appears", style: Theme.of(context).textTheme.bodyMedium)]))
        : Column(children: [
            // Header
            Container(margin: const EdgeInsets.all(20), padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(gradient: LinearGradient(colors: [AppTheme.primary.withOpacity(0.1), AppTheme.secondary.withOpacity(0.1)]), borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.auto_awesome, color: AppTheme.primary)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${matches.length} Potential Match${matches.length > 1 ? "es" : ""}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('AI found these matching items', style: Theme.of(context).textTheme.bodyMedium)])),
              ])),
            // Match list
            Expanded(child: ListView.builder(padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), itemCount: matches.length,
              itemBuilder: (ctx, i) {
                final m = matches[i];
                final pct = m.percentMatch;
                final color = pct >= 90 ? AppTheme.success : pct >= 80 ? AppTheme.warning : AppTheme.primary;
                return Card(margin: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    children: [
                      InkWell(borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ItemDetailScreen(item: m.item))),
                        child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
                          ClipRRect(borderRadius: BorderRadius.circular(12),
                            child: Image.network(items$.getImageUrl(m.item.imageFileId), width: 80, height: 80, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(width: 80, height: 80, color: Colors.grey.shade200, child: const Icon(Icons.image)))),
                          const SizedBox(width: 14),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(m.item.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                            const SizedBox(height: 4),
                            Text(m.item.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium),
                            if (m.item.location != null && m.item.location!.isNotEmpty) ...[const SizedBox(height: 4),
                              Row(children: [Icon(Icons.location_on, size: 14, color: AppTheme.textHint), const SizedBox(width: 4),
                                Expanded(child: Text(m.item.location!, style: const TextStyle(fontSize: 12, color: AppTheme.textHint), overflow: TextOverflow.ellipsis))])],
                          ])),
                          const SizedBox(width: 12),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                            child: Column(children: [Text('$pct%', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 18)),
                              Text('match', style: TextStyle(color: color, fontSize: 11))])),
                        ]))),
                      // Contact button
                      Container(
                        decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: Colors.grey.shade200)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChatScreen(
                                        itemId: m.item.id,
                                        itemTitle: m.item.title,
                                        otherUserId: m.item.userId,
                                        otherUserName: m.item.userName,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.chat_rounded, size: 18),
                                label: const Text('Chat Now'),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppTheme.primary,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            Container(width: 1, height: 30, color: Colors.grey.shade200),
                            Expanded(
                              child: TextButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ItemDetailScreen(item: m.item),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.info_outline, size: 18),
                                label: const Text('Details'),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppTheme.textSecondary,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ));
              })),
          ]),
    );
  }
}