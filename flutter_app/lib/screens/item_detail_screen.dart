import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/item_model.dart';
import '../providers/auth_provider.dart';
import '../providers/items_provider.dart';
import '../services/claim_security_service.dart';
import '../utils/theme.dart';
import 'chat_screen.dart';
import 'item_chats_screen.dart';
import 'matches_screen.dart';

class ItemDetailScreen extends StatefulWidget {
  final ItemModel item;
  const ItemDetailScreen({super.key, required this.item});

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  ClaimSecurityProfile? _claimProfile;
  bool _loaded = false;

  ItemModel get item => widget.item;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile =
        await context.read<ItemsProvider>().getClaimProfile(item.id);
    if (!mounted) return;
    setState(() {
      _claimProfile = profile;
      _loaded = true;
    });
  }

  Future<void> _showClaimPass() async {
    final profile = _claimProfile;
    if (profile == null) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text('Claim Pass'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceMuted,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(Icons.qr_code_2_rounded,
                      size: 56, color: AppTheme.primary),
                  const SizedBox(height: 12),
                  const Text('Claim Code'),
                  const SizedBox(height: 8),
                  Text(
                    profile.claimCode,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            if (profile.hasQuestions) ...[
              const SizedBox(height: 12),
              Text(
                  '${profile.questions.length} hidden proof question(s) active.'),
            ],
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _verifyClaim() async {
    final profile = _claimProfile;
    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Secure claim is not set up for this item yet.')),
      );
      return;
    }

    final codeController = TextEditingController();
    final answerControllers =
        List.generate(profile.questions.length, (_) => TextEditingController());

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Secure Claim Check',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              TextField(
                controller: codeController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Claim Code',
                  hintText: 'LF-XXXXXX',
                  prefixIcon: Icon(Icons.qr_code_rounded),
                ),
              ),
              for (var i = 0; i < profile.questions.length; i++) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: answerControllers[i],
                  decoration: InputDecoration(
                    labelText: 'Question ${i + 1}',
                    hintText: profile.questions[i].prompt,
                    prefixIcon: const Icon(Icons.shield_outlined),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final result =
                        await context.read<ItemsProvider>().verifyClaim(
                              profile: profile,
                              claimCode: codeController.text,
                              responses:
                                  answerControllers.map((c) => c.text).toList(),
                            );
                    if (!ctx.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result.message),
                        backgroundColor:
                            result.success ? AppTheme.success : AppTheme.danger,
                      ),
                    );
                    if (result.success) {
                      await context.read<ItemsProvider>().claimItem(item.id);
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx, true);

                      if (!mounted) return;
                      await showDialog<void>(
                        context: context,
                        builder: (dCtx) => AlertDialog(
                          backgroundColor: AppTheme.cardBg,
                          title: Row(
                            children: const [
                              Icon(Icons.verified, color: AppTheme.success, size: 28),
                              SizedBox(width: 8),
                              Text('Ownership Proved!'),
                            ],
                          ),
                          content: const Text(
                            'You have successfully proven ownership of this item. '
                            'You can now message the finder to coordinate the return.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dCtx),
                              child: const Text('Close'),
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(dCtx);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChatScreen(
                                      itemId: item.id,
                                      itemTitle: item.title,
                                      otherUserId: item.userId,
                                      otherUserName: item.userName,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.chat_rounded),
                              label: const Text('Message Finder'),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.verified_rounded),
                  label: const Text('Verify Ownership'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    codeController.dispose();
    for (final controller in answerControllers) {
      controller.dispose();
    }

    if (ok == true && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsProvider = context.watch<ItemsProvider>();
    final auth = context.watch<AuthProvider>();
    final isOwner = item.userId == auth.userId;
    final imageUrl = itemsProvider.getImageUrl(item.imageFileId);
    final color = item.isLost ? AppTheme.lostColor : AppTheme.foundColor;
    final date = DateFormat('MMM dd, yyyy - hh:mm a').format(item.createdAt);

    return Scaffold(
      appBar: AppBar(title: Text(item.title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: AppTheme.panelGradient,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.network(
                imageUrl,
                height: 240,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 240,
                  color: AppTheme.surfaceMuted,
                  child: const Icon(Icons.image, size: 64),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _Badge(label: item.type.toUpperCase(), color: color),
              const SizedBox(width: 8),
              _Badge(
                label: item.status.toUpperCase(),
                color: item.isOpen ? AppTheme.success : AppTheme.textHint,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(item.title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text('$date by ${item.userName}',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: AppTheme.panelGradient,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Description',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(item.description,
                    style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ),
          if (item.aiCaption != null && item.aiCaption!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
              ),
              child: Text(item.aiCaption!),
            ),
          ],
          if (item.location != null && item.location!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.location_on,
                    size: 18, color: AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(item.location!)),
              ],
            ),
          ],
          if (item.isFound) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardBgSoft.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Secure Claim',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  if (!_loaded)
                    const CircularProgressIndicator()
                  else if (_claimProfile == null)
                    Text(
                        'This item was posted before secure claim was enabled.',
                        style: Theme.of(context).textTheme.bodyMedium)
                  else ...[
                    Text('Claim Code: ${_claimProfile!.claimCode}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(
                      _claimProfile!.hasQuestions
                          ? '${_claimProfile!.questions.length} hidden ownership question(s) configured.'
                          : 'No hidden ownership questions were added.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isOwner ? _showClaimPass : _verifyClaim,
                        icon: Icon(isOwner
                            ? Icons.qr_code_2_rounded
                            : Icons.verified_rounded),
                        label: Text(
                            isOwner ? 'Open Claim Pass' : 'Start Secure Claim'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (item.isOpen && isOwner) ...[
            ElevatedButton.icon(
              onPressed: () async {
                final matches = await itemsProvider.findMatchesForItem(item);
                if (!mounted) return;
                if (matches.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => MatchesScreen(reportedItem: item)),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No matches found yet')),
                  );
                }
              },
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Find Matches with AI'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ItemChatsScreen(item: item)),
                );
              },
              icon: const Icon(Icons.chat_rounded),
              label: const Text('View Chats'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                await itemsProvider.claimItem(item.id);
                if (mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Mark as Claimed'),
            ),
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}
