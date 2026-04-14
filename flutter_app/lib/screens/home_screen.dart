import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat_contact_model.dart';
import '../models/item_model.dart';
import '../providers/auth_provider.dart';
import '../providers/items_provider.dart';
import '../services/database_service.dart';
import '../utils/categories.dart';
import '../utils/theme.dart';
import '../widgets/item_card.dart';
import 'chat_screen.dart';
import 'item_detail_screen.dart';
import 'login_screen.dart';
import 'report_item_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  String _filter = 'all';
  String _searchQuery = '';
  String? _categoryFilter;
  int _unreadCount = 0;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ItemsProvider>().fetchItems();
      context.read<ItemsProvider>().fetchMyItems();
      _loadUnreadCount();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUnreadCount() async {
    // Count unread messages across all items
    try {
      final itemsProvider = context.read<ItemsProvider>();
      final myItems = itemsProvider.myItems;
      int total = 0;
      final db = DatabaseService();
      for (final item in myItems) {
        final contacts = await db.getItemChatContacts(item.id);
        for (final contact in contacts) {
          total += contact.unreadCount;
        }
      }
      if (mounted) setState(() => _unreadCount = total);
    } catch (_) {}
  }

  List<ItemModel> _getFilteredItems(ItemsProvider provider) {
    // Step 1: Type filter (all / lost / found)
    List<ItemModel> items = _filter == 'all'
        ? provider.allItems
        : _filter == 'lost'
            ? provider.lostItems
            : provider.foundItems;

    // Step 2: Category filter
    if (_categoryFilter != null) {
      items = items.where((item) {
        final cat = ItemCategory.detect(item.title, item.description);
        return cat.name == _categoryFilter;
      }).toList();
    }

    // Step 3: Search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      items = items.where((item) {
        return item.title.toLowerCase().contains(query) ||
            item.description.toLowerCase().contains(query) ||
            (item.location?.toLowerCase().contains(query) ?? false) ||
            item.userName.toLowerCase().contains(query);
      }).toList();
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final itemsProvider = context.watch<ItemsProvider>();
    final auth = context.watch<AuthProvider>();
    final items = _getFilteredItems(itemsProvider);

    return Scaffold(
      body: _tab == 3
          ? _ProfileTab(auth: auth, itemsProvider: itemsProvider)
          : Container(
              decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
              child: SafeArea(
                child: Column(
                  children: [
                    // ─── Top Header with Notification Bell ───
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: _TopBox(
                        name: auth.userName.split(' ').first,
                        allItems: itemsProvider.allItems,
                        lostCount: itemsProvider.lostItems.length,
                        foundCount: itemsProvider.foundItems.length,
                        filter: _filter,
                        unreadCount: _unreadCount,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ─── Search Bar ───
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (v) => setState(() => _searchQuery = v),
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search items, locations, people...',
                            hintStyle: const TextStyle(
                              color: AppTheme.textHint,
                              fontSize: 14,
                            ),
                            prefixIcon: const Icon(Icons.search_rounded,
                                color: AppTheme.primary, size: 22),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                    icon: const Icon(Icons.close_rounded,
                                        color: AppTheme.textHint, size: 20),
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ─── Type Filter Chips (All / Lost / Found) ───
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          _FilterChip(
                            label: 'All',
                            active: _filter == 'all',
                            onTap: () => setState(() => _filter = 'all'),
                          ),
                          const SizedBox(width: 10),
                          _FilterChip(
                            label: 'Lost',
                            active: _filter == 'lost',
                            onTap: () => setState(() => _filter = 'lost'),
                          ),
                          const SizedBox(width: 10),
                          _FilterChip(
                            label: 'Found',
                            active: _filter == 'found',
                            onTap: () => setState(() => _filter = 'found'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ─── Category Scroll Chips ───
                    SizedBox(
                      height: 38,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          _CatChip(
                            label: 'All',
                            icon: Icons.apps_rounded,
                            color: AppTheme.primary,
                            active: _categoryFilter == null,
                            onTap: () =>
                                setState(() => _categoryFilter = null),
                          ),
                          ...ItemCategory.all.map((cat) => Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: _CatChip(
                                  label: cat.name,
                                  icon: cat.icon,
                                  color: cat.color,
                                  active: _categoryFilter == cat.name,
                                  onTap: () => setState(
                                      () => _categoryFilter = cat.name),
                                ),
                              )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ─── Items List ───
                    Expanded(
                      child: itemsProvider.isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : items.isEmpty
                              ? _EmptyState(
                                  hasSearch: _searchQuery.isNotEmpty ||
                                      _categoryFilter != null)
                              : RefreshIndicator(
                                  onRefresh: () async {
                                    await itemsProvider.fetchItems();
                                    await _loadUnreadCount();
                                  },
                                  child: ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 6, 16, 110),
                                    itemCount: items.length,
                                    itemBuilder: (context, index) {
                                      final item = items[index];
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 12),
                                        child: ItemCard(
                                          item: item,
                                          imageUrl: itemsProvider
                                              .getImageUrl(item.imageFileId),
                                          onTap: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  ItemDetailScreen(item: item),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                    ),
                  ],
                ),
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: _tab == 3
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ReportItemScreen()),
                );
                if (result == true) {
                  itemsProvider.fetchItems();
                  itemsProvider.fetchMyItems();
                  _loadUnreadCount();
                }
              },
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Report'),
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (index) => setState(() {
          _tab = index;
          if (index == 0) _filter = 'all';
          if (index == 1) _filter = 'lost';
          if (index == 2) _filter = 'found';
        }),
        items: [
          const BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded), label: 'Feed'),
          const BottomNavigationBarItem(
              icon: Icon(Icons.search_off_rounded), label: 'Lost'),
          const BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined), label: 'Found'),
          BottomNavigationBarItem(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.person_outline_rounded),
                if (_unreadCount > 0)
                  Positioned(
                    right: -6,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppTheme.danger,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        _unreadCount > 9 ? '9+' : '$_unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// ─── Top Header / Stats Dashboard ──────────────────────────────────
class _TopBox extends StatelessWidget {
  final String name;
  final List<ItemModel> allItems;
  final int lostCount;
  final int foundCount;
  final String filter;
  final int unreadCount;

  const _TopBox({
    required this.name,
    required this.allItems,
    required this.lostCount,
    required this.foundCount,
    required this.filter,
    required this.unreadCount,
  });

  @override
  Widget build(BuildContext context) {
    final claimed = allItems.where((i) => i.status == 'claimed' || i.status == 'returned').length;
    final recoveryRate = allItems.isEmpty ? 0 : ((claimed / allItems.length) * 100).round();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppTheme.panelGradient,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hello, $name',
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 6),
                    Text(
                      'AI-Powered Campus Recovery Dashboard',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              // Notification Bell
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: AppTheme.accentGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.notifications_rounded,
                        color: Colors.white, size: 24),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: AppTheme.danger,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.surface, width: 2),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        child: Text(
                          unreadCount > 9 ? '9+' : '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          // ─── Stats Row ───
          Row(
            children: [
              _StatMini(
                  icon: Icons.article_rounded,
                  label: 'Total',
                  value: '${allItems.length}',
                  color: AppTheme.primary),
              const SizedBox(width: 8),
              _StatMini(
                  icon: Icons.search_off_rounded,
                  label: 'Lost',
                  value: '$lostCount',
                  color: AppTheme.lostColor),
              const SizedBox(width: 8),
              _StatMini(
                  icon: Icons.handshake_rounded,
                  label: 'Found',
                  value: '$foundCount',
                  color: AppTheme.foundColor),
              const SizedBox(width: 8),
              _StatMini(
                  icon: Icons.trending_up_rounded,
                  label: 'Recovery',
                  value: '$recoveryRate%',
                  color: AppTheme.success),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatMini extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatMini({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.18)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color.withOpacity(0.7),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Category Chip ──────────────────────────────────────────────
class _CatChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  const _CatChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.18) : AppTheme.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? color : AppTheme.border,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: active ? color : AppTheme.textHint),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: active ? color : AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Existing widgets (unchanged) ───────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: active ? AppTheme.primary : AppTheme.cardBg,
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: active ? AppTheme.primary : AppTheme.border),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? Colors.white : AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasSearch;
  const _EmptyState({this.hasSearch = false});

  @override
  Widget build(BuildContext context) {
    return Center(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
          gradient: AppTheme.panelGradient,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppTheme.border),
          ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: AppTheme.surfaceMuted,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                  hasSearch ? Icons.search_off_rounded : Icons.inbox_outlined,
                  color: AppTheme.primary,
                  size: 30),
            ),
            const SizedBox(height: 16),
            Text(hasSearch ? 'No results found' : 'No items yet',
                style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
              hasSearch
                  ? 'Try a different search term or filter.'
                  : 'Report a lost or found item to start this command center.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTab extends StatefulWidget {
  final AuthProvider auth;
  final ItemsProvider itemsProvider;

  const _ProfileTab({
    required this.auth,
    required this.itemsProvider,
  });

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  final _db = DatabaseService();
  List<_ChatEntry> _chatEntries = [];
  bool _loadingChats = true;

  @override
  void initState() {
    super.initState();
    _loadAllChats();
  }

  Future<void> _loadAllChats() async {
    try {
      final myItems = widget.itemsProvider.myItems;
      final entries = <_ChatEntry>[];
      for (final item in myItems) {
        final contacts = await _db.getItemChatContacts(item.id);
        for (final contact in contacts) {
          entries.add(_ChatEntry(
            item: item,
            contact: contact,
          ));
        }
      }
      // Sort by most recent message
      entries.sort((a, b) =>
          b.contact.lastMessageAt.compareTo(a.contact.lastMessageAt));
      if (mounted) {
        setState(() {
          _chatEntries = entries;
          _loadingChats = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingChats = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myItems = widget.itemsProvider.myItems;
    final lost = myItems.where((item) => item.isLost).length;
    final found = myItems.where((item) => item.isFound).length;
    final claimed = myItems
        .where(
            (item) => item.status == 'claimed' || item.status == 'returned')
        .length;
    final totalUnread =
        _chatEntries.fold<int>(0, (sum, e) => sum + e.contact.unreadCount);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadAllChats,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Text('Profile',
                        style: Theme.of(context).textTheme.headlineMedium),
                    const Spacer(),
                    IconButton(
                      onPressed: () async {
                        await widget.auth.logout();
                        if (!context.mounted) return;
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                              builder: (_) => const LoginScreen()),
                          (_) => false,
                        );
                      },
                      icon: const Icon(Icons.logout_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppTheme.panelGradient,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 34,
                        backgroundColor: AppTheme.surfaceMuted,
                        child: Text(
                          widget.auth.userName.isNotEmpty
                              ? widget.auth.userName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(widget.auth.userName,
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(widget.auth.userEmail,
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                        child: _StatCard(
                            label: 'Posts',
                            value: '${myItems.length}',
                            color: AppTheme.primary)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _StatCard(
                            label: 'Lost',
                            value: '$lost',
                            color: AppTheme.lostColor)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _StatCard(
                            label: 'Found',
                            value: '$found',
                            color: AppTheme.foundColor)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _StatCard(
                            label: 'Claimed',
                            value: '$claimed',
                            color: AppTheme.success)),
                  ],
                ),

                // ─── Messages Section ───
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: AppTheme.panelGradient,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.chat_rounded,
                                color: AppTheme.primary, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Messages',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge),
                                const SizedBox(height: 2),
                                Text(
                                  '${_chatEntries.length} conversation${_chatEntries.length == 1 ? '' : 's'}${totalUnread > 0 ? ' · $totalUnread unread' : ''}',
                                  style:
                                      Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          if (totalUnread > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.danger,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '$totalUnread',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (_loadingChats)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child:
                              Center(child: CircularProgressIndicator()),
                        )
                      else if (_chatEntries.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text(
                              'No messages yet',
                              style:
                                  Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        )
                      else ...[
                        const SizedBox(height: 14),
                        ...List.generate(
                          _chatEntries.length,
                          (i) {
                            final entry = _chatEntries[i];
                            return Padding(
                              padding: EdgeInsets.only(
                                  top: i == 0 ? 0 : 10),
                              child: InkWell(
                                borderRadius:
                                    BorderRadius.circular(16),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChatScreen(
                                        itemId: entry.item.id,
                                        itemTitle:
                                            entry.item.title,
                                        otherUserId: entry
                                            .contact.otherUserId,
                                        otherUserName: entry
                                            .contact
                                            .otherUserName,
                                      ),
                                    ),
                                  ).then((_) => _loadAllChats());
                                },
                                child: Container(
                                  padding:
                                      const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceMuted
                                        .withOpacity(0.5),
                                    borderRadius:
                                        BorderRadius.circular(16),
                                    border: Border.all(
                                        color: entry.contact
                                                    .unreadCount >
                                                0
                                            ? AppTheme.primary
                                                .withOpacity(0.4)
                                            : AppTheme.border),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor:
                                            AppTheme.primary
                                                .withOpacity(
                                                    0.14),
                                        child: Text(
                                          entry.contact
                                                  .otherUserName
                                                  .isNotEmpty
                                              ? entry.contact
                                                  .otherUserName[
                                                      0]
                                                  .toUpperCase()
                                              : '?',
                                          style:
                                              const TextStyle(
                                            color:
                                                AppTheme.primary,
                                            fontWeight:
                                                FontWeight.w800,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment
                                                  .start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    entry.contact
                                                        .otherUserName,
                                                    style:
                                                        const TextStyle(
                                                      color: AppTheme
                                                          .textPrimary,
                                                      fontWeight:
                                                          FontWeight
                                                              .w700,
                                                      fontSize:
                                                          14,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow
                                                            .ellipsis,
                                                  ),
                                                ),
                                                Text(
                                                  _timeAgo(entry
                                                      .contact
                                                      .lastMessageAt),
                                                  style:
                                                      const TextStyle(
                                                    color: AppTheme
                                                        .textHint,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(
                                                height: 4),
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal:
                                                          6,
                                                      vertical:
                                                          2),
                                                  decoration:
                                                      BoxDecoration(
                                                    color: (entry.item.isLost
                                                            ? AppTheme
                                                                .lostColor
                                                            : AppTheme
                                                                .foundColor)
                                                        .withOpacity(
                                                            0.14),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                  ),
                                                  child: Text(
                                                    entry.item
                                                        .title,
                                                    style:
                                                        TextStyle(
                                                      color: entry.item.isLost
                                                          ? AppTheme
                                                              .lostColor
                                                          : AppTheme
                                                              .foundColor,
                                                      fontSize:
                                                          10,
                                                      fontWeight:
                                                          FontWeight
                                                              .w700,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow
                                                            .ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(
                                                    width: 6),
                                                Expanded(
                                                  child: Text(
                                                    entry.contact
                                                        .lastMessage,
                                                    style:
                                                        const TextStyle(
                                                      color: AppTheme
                                                          .textSecondary,
                                                      fontSize:
                                                          12,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow
                                                            .ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (entry.contact
                                              .unreadCount >
                                          0)
                                        Container(
                                          margin:
                                              const EdgeInsets
                                                  .only(
                                                  left: 8),
                                          padding:
                                              const EdgeInsets
                                                  .all(8),
                                          decoration:
                                              const BoxDecoration(
                                            color:
                                                AppTheme.primary,
                                            shape:
                                                BoxShape.circle,
                                          ),
                                          child: Text(
                                            '${entry.contact.unreadCount}',
                                            style:
                                                const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight:
                                                  FontWeight
                                                      .w800,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    this.color = AppTheme.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.7),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper to group a chat contact with its parent item.
class _ChatEntry {
  final ItemModel item;
  final ChatContactModel contact;
  const _ChatEntry({required this.item, required this.contact});
}

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return '${dt.day}/${dt.month}';
}
