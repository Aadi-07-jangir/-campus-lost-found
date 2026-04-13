import 'dart:math';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/item_model.dart';
import '../models/match_result.dart';
import '../utils/config.dart';

class AIService {
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();

  final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConfig.aiServerUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 60),
  ));

  Future<bool> isHealthy() async {
    try {
      final res = await _dio.get('/health');
      return res.data['status'] == 'healthy';
    } catch (_) {
      return false;
    }
  }

  Future<String> generateCaption(Uint8List imageBytes, String fileName) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(imageBytes, filename: fileName),
    });
    final res = await _dio.post('/caption', data: formData);
    return res.data['caption'] as String;
  }

  Future<Map<String, dynamic>> embedImage(Uint8List imageBytes, String fileName) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(imageBytes, filename: fileName),
    });
    final res = await _dio.post('/embed', data: formData);
    return {
      'embedding': (res.data['embedding'] as List).map((e) => (e as num).toDouble()).toList(),
      'caption': res.data['caption'] as String,
    };
  }

  Future<Map<String, dynamic>> processItem({
    required Uint8List imageBytes,
    required String fileName,
    required String itemType,
    String? userDescription,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(imageBytes, filename: fileName),
      'item_type': itemType,
      if (userDescription != null) 'user_description': userDescription,
    });
    final res = await _dio.post('/process-item', data: formData);
    return {
      'caption': res.data['caption'] as String,
      'embedding': (res.data['embedding'] as List).map((e) => (e as num).toDouble()).toList(),
    };
  }

  // ─── LOCAL Cosine Similarity (no server needed) ─────────────────
  /// Computes cosine similarity between two embedding vectors locally.
  /// Returns a value between -1.0 and 1.0 (1.0 = identical).
  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) return 0.0;
    double dot = 0.0, normA = 0.0, normB = 0.0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    final denom = sqrt(normA) * sqrt(normB);
    if (denom == 0) return 0.0;
    return dot / denom;
  }

  /// Match a query embedding against all candidates LOCALLY in Dart.
  /// No server call needed — this is instant and reliable.
  Future<List<MatchResult>> bulkMatch({
    required List<double> queryEmbedding,
    required List<ItemModel> candidates,
    double? threshold,
  }) async {
    final th = threshold ?? AppConfig.matchThreshold;
    final valid = candidates.where((c) => c.embedding != null && c.embedding!.isNotEmpty).toList();

    debugPrint('[AI-LOCAL] Running local bulk match: ${valid.length} candidates with embeddings, threshold=$th');

    if (valid.isEmpty) {
      debugPrint('[AI-LOCAL] No candidates have embeddings — skipping match.');
      return [];
    }

    final results = <MatchResult>[];
    for (final candidate in valid) {
      final sim = _cosineSimilarity(queryEmbedding, candidate.embedding!);
      debugPrint('[AI-LOCAL] Candidate ${candidate.id} "${candidate.title}": similarity=${sim.toStringAsFixed(4)}');
      if (sim >= th) {
        results.add(MatchResult(
          item: candidate,
          similarity: sim,
          isMatch: true,
        ));
      }
    }

    results.sort((a, b) => b.similarity.compareTo(a.similarity));
    debugPrint('[AI-LOCAL] Found ${results.length} matches above threshold $th');
    return results;
  }

  Future<List<double>> embedText(String text) async {
    final res = await _dio.post('/embed-text', data: {'text': text});
    return (res.data['embedding'] as List).map((e) => (e as num).toDouble()).toList();
  }
}

