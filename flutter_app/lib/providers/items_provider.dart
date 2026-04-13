import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/item_model.dart';
import '../models/match_result.dart';
import '../services/database_service.dart';
import '../services/storage_service.dart';
import '../services/ai_service.dart';
import '../services/claim_security_service.dart';
import '../utils/config.dart';

class ItemsProvider extends ChangeNotifier {
  final _db = DatabaseService();
  final _storage = StorageService();
  final _ai = AIService();
  final _claimSecurity = ClaimSecurityService();

  List<ItemModel> _allItems = [];
  List<ItemModel> _myItems = [];
  List<MatchResult> _matches = [];
  bool _isLoading = false;
  bool _isProcessing = false;
  String? _error;

  List<ItemModel> get allItems => _allItems;
  List<ItemModel> get lostItems => _allItems.where((i) => i.isLost).toList();
  List<ItemModel> get foundItems => _allItems.where((i) => i.isFound).toList();
  List<ItemModel> get myItems => _myItems;
  List<MatchResult> get matches => _matches;
  bool get isLoading => _isLoading;
  bool get isProcessing => _isProcessing;
  String? get error => _error;

  Future<void> fetchItems() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _allItems = await _db.getItems();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchMyItems() async {
    try {
      _myItems = await _db.getMyItems();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<ItemModel?> reportItem({
    required String type,
    required String title,
    required String description,
    required Uint8List imageBytes,
    required String fileName,
    List<ClaimQuestion> claimQuestions = const [],
    String? location,
    double? latitude,
    double? longitude,
    String? collegeId,
  }) async {
    _isProcessing = true;
    _error = null;
    notifyListeners();

    try {
      // Step 1: Upload image to Supabase Storage
      final fileId = await _storage.uploadImage(
        fileBytes: imageBytes,
        fileName: fileName,
      );

      // Step 2: Send to AI server for captioning + embedding
      String aiCaption = '';
      List<double> embedding = [];
      try {
        debugPrint('[AI] Sending image to AI server at ${AppConfig.aiServerUrl}...');
        final aiResult = await _ai.processItem(
          imageBytes: imageBytes,
          fileName: fileName,
          itemType: type,
          userDescription: description,
        );
        aiCaption = aiResult['caption'] as String;
        embedding = aiResult['embedding'] as List<double>;
        debugPrint('[AI] SUCCESS — caption: $aiCaption, embedding length: ${embedding.length}');
      } catch (e) {
        debugPrint('[AI] FAILED — server may be offline: $e');
        debugPrint('[AI] Make sure python main.py is running and the URL ${AppConfig.aiServerUrl} is reachable from your device.');
      }

      // Step 3: Save to database
      final item = await _db.createItem(
        type: type,
        title: title,
        description: description,
        imageFileId: fileId,
        location: location,
        latitude: latitude,
        longitude: longitude,
        collegeId: collegeId,
        embedding: embedding.isNotEmpty ? embedding : null,
        aiCaption: aiCaption.isNotEmpty ? aiCaption : null,
      );

      if (item.isFound) {
        await _claimSecurity.createProfile(
          itemId: item.id,
          title: item.title,
          ownerName: item.userName,
          questions: claimQuestions,
        );
      }

      // Step 4: Find matches
      if (embedding.isNotEmpty) {
        await _findMatches(item, embedding);
      } else {
        final oppositeType = item.isLost ? 'found' : 'lost';
        final candidates = await _db.getCandidateItems(oppositeType);
        _matches = _fallbackMatches(item, candidates);
      }

      await fetchItems();
      await fetchMyItems();

      _isProcessing = false;
      notifyListeners();
      return item;
    } catch (e) {
      _error = e.toString();
      _isProcessing = false;
      notifyListeners();
      return null;
    }
  }

  Future<void> _findMatches(ItemModel newItem, List<double> embedding) async {
    try {
      final oppositeType = newItem.isLost ? 'found' : 'lost';
      final candidates = await _db.getCandidateItems(oppositeType);
      debugPrint('[MATCH] Found ${candidates.length} $oppositeType candidates in DB');
      if (candidates.isEmpty) {
        debugPrint('[MATCH] No opposite-type candidates exist yet — nothing to match against.');
        return;
      }

      // Count how many candidates have valid AI embeddings
      final withEmbeddings = candidates.where((c) => c.embedding != null && c.embedding!.isNotEmpty).length;
      debugPrint('[MATCH] $withEmbeddings/${candidates.length} candidates have AI embeddings');

      if (withEmbeddings > 0) {
        _matches = await _ai.bulkMatch(
          queryEmbedding: embedding,
          candidates: candidates,
        );
        debugPrint('[MATCH] AI bulk match returned ${_matches.length} results');
      }

      if (_matches.isEmpty) {
        debugPrint('[MATCH] AI found nothing — trying text-based fallback...');
        _matches = _fallbackMatches(newItem, candidates);
        debugPrint('[MATCH] Fallback returned ${_matches.length} results');
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[MATCH] AI matching failed: $e — falling back to text match');
      final oppositeType = newItem.isLost ? 'found' : 'lost';
      final candidates = await _db.getCandidateItems(oppositeType);
      _matches = _fallbackMatches(newItem, candidates);
      notifyListeners();
    }
  }

  Future<List<MatchResult>> findMatchesForItem(ItemModel item) async {
    final oppositeType = item.isLost ? 'found' : 'lost';
    final candidates = await _db.getCandidateItems(oppositeType);
    if (item.embedding == null || item.embedding!.isEmpty) {
      final fallback = _fallbackMatches(item, candidates);
      _matches = fallback;
      notifyListeners();
      return fallback;
    }
    try {
      final results = await _ai.bulkMatch(
        queryEmbedding: item.embedding!,
        candidates: candidates,
      );
      _matches =
          results.isNotEmpty ? results : _fallbackMatches(item, candidates);
      notifyListeners();
      return _matches;
    } catch (e) {
      debugPrint('Match search failed: $e');
      final fallback = _fallbackMatches(item, candidates);
      _matches = fallback;
      notifyListeners();
      return fallback;
    }
  }

  Future<void> claimItem(String itemId) async {
    await _db.updateItemStatus(itemId, 'claimed');
    await fetchItems();
    await fetchMyItems();
  }

  Future<void> markReturned(String itemId) async {
    await _db.updateItemStatus(itemId, 'returned');
    await fetchItems();
    await fetchMyItems();
  }

  Future<ClaimSecurityProfile?> getClaimProfile(String itemId) {
    return _claimSecurity.getProfile(itemId);
  }

  Future<ClaimVerificationResult> verifyClaim({
    required ClaimSecurityProfile profile,
    required String claimCode,
    required List<String> responses,
  }) {
    return _claimSecurity.verifyClaim(
      profile: profile,
      claimCode: claimCode,
      responses: responses,
    );
  }

  Future<void> deleteItem(ItemModel item) async {
    try {
      await _storage.deleteFile(item.imageFileId);
    } catch (_) {}
    await _db.deleteItem(item.id);
    await fetchItems();
    await fetchMyItems();
  }

  String getImageUrl(String fileId) => _storage.getImageUrl(fileId);

  void clearMatches() {
    _matches = [];
    notifyListeners();
  }

  List<MatchResult> _fallbackMatches(
      ItemModel query, List<ItemModel> candidates) {
    final scored = <MatchResult>[];
    for (final candidate in candidates) {
      if (candidate.id == query.id) continue;
      final similarity = _fallbackSimilarity(query, candidate);
      if (similarity >= 0.45) {
        scored.add(MatchResult(
            item: candidate, similarity: similarity, isMatch: true));
      }
    }
    scored.sort((a, b) => b.similarity.compareTo(a.similarity));
    return scored.take(10).toList();
  }

  double _fallbackSimilarity(ItemModel a, ItemModel b) {
    final titleScore = _tokenOverlap(a.title, b.title);
    final descriptionScore = _tokenOverlap(a.description, b.description);
    final captionScore = _tokenOverlap(a.aiCaption ?? '', b.aiCaption ?? '');
    final locationScore = _tokenOverlap(a.location ?? '', b.location ?? '');

    var score = (titleScore * 0.45) +
        (descriptionScore * 0.3) +
        (captionScore * 0.15) +
        (locationScore * 0.1);

    if (_normalize(a.title) == _normalize(b.title) &&
        a.title.trim().isNotEmpty) {
      score += 0.2;
    }

    return score.clamp(0.0, 0.99);
  }

  double _tokenOverlap(String left, String right) {
    final a = _tokens(left);
    final b = _tokens(right);
    if (a.isEmpty || b.isEmpty) return 0;
    final intersection = a.intersection(b).length.toDouble();
    final union = a.union(b).length.toDouble();
    return union == 0 ? 0 : intersection / union;
  }

  Set<String> _tokens(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .split(RegExp(r'\s+'))
        .where((token) => token.length > 2)
        .toSet();
  }

  String _normalize(String text) {
    return text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '').trim();
  }
}
