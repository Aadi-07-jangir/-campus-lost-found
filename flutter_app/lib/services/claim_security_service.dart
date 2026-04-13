import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

class ClaimQuestion {
  final String prompt;
  final String answer;

  const ClaimQuestion({
    required this.prompt,
    required this.answer,
  });

  Map<String, dynamic> toMap() {
    return {
      'prompt': prompt,
      'answer': answer,
    };
  }

  factory ClaimQuestion.fromMap(Map<String, dynamic> map) {
    return ClaimQuestion(
      prompt: map['prompt']?.toString() ?? '',
      answer: map['answer']?.toString() ?? '',
    );
  }
}

class ClaimSecurityProfile {
  final String itemId;
  final String claimCode;
  final String qrPayload;
  final List<ClaimQuestion> questions;

  const ClaimSecurityProfile({
    required this.itemId,
    required this.claimCode,
    required this.qrPayload,
    required this.questions,
  });

  bool get hasQuestions => questions.isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'claimCode': claimCode,
      'qrPayload': qrPayload,
      'questions': questions.map((q) => q.toMap()).toList(),
    };
  }

  factory ClaimSecurityProfile.fromMap(Map<String, dynamic> map) {
    final rawQuestions = map['questions'];
    return ClaimSecurityProfile(
      itemId: map['itemId']?.toString() ?? '',
      claimCode: map['claimCode']?.toString() ?? '',
      qrPayload: map['qrPayload']?.toString() ?? '',
      questions: rawQuestions is List
          ? rawQuestions
              .whereType<Map>()
              .map((question) => ClaimQuestion.fromMap(
                    Map<String, dynamic>.from(question),
                  ))
              .where((question) =>
                  question.prompt.trim().isNotEmpty &&
                  question.answer.trim().isNotEmpty)
              .toList()
          : const [],
    );
  }
}

class ClaimVerificationResult {
  final bool success;
  final int matchedAnswers;
  final int totalQuestions;
  final String message;

  const ClaimVerificationResult({
    required this.success,
    required this.matchedAnswers,
    required this.totalQuestions,
    required this.message,
  });
}

class ClaimSecurityService {
  ClaimSecurityService._internal();

  static final ClaimSecurityService _instance =
      ClaimSecurityService._internal();

  factory ClaimSecurityService() => _instance;

  static const String _prefix = 'claim_security_profile_';

  Future<ClaimSecurityProfile> createProfile({
    required String itemId,
    required String title,
    required String ownerName,
    List<ClaimQuestion> questions = const [],
  }) async {
    final claimCode = _generateClaimCode(title: title, ownerName: ownerName);
    final profile = ClaimSecurityProfile(
      itemId: itemId,
      claimCode: claimCode,
      qrPayload: 'campus-lost-found://claim/$itemId/$claimCode',
      questions: questions
          .where(
              (q) => q.prompt.trim().isNotEmpty && q.answer.trim().isNotEmpty)
          .toList(),
    );
    await saveProfile(profile);
    return profile;
  }

  Future<void> saveProfile(ClaimSecurityProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_prefix${profile.itemId}',
      jsonEncode(profile.toMap()),
    );
  }

  Future<ClaimSecurityProfile?> getProfile(String itemId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$itemId');
    if (raw == null || raw.isEmpty) return null;

    try {
      return ClaimSecurityProfile.fromMap(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  Future<ClaimVerificationResult> verifyClaim({
    required ClaimSecurityProfile profile,
    required String claimCode,
    required List<String> responses,
  }) async {
    final normalizedCode = claimCode.trim().toUpperCase();
    if (normalizedCode != profile.claimCode.toUpperCase()) {
      return const ClaimVerificationResult(
        success: false,
        matchedAnswers: 0,
        totalQuestions: 0,
        message: 'Claim code does not match this item.',
      );
    }

    if (profile.questions.isEmpty) {
      return const ClaimVerificationResult(
        success: true,
        matchedAnswers: 0,
        totalQuestions: 0,
        message: 'Claim code verified. The item is ready to be marked claimed.',
      );
    }

    var matches = 0;
    for (var i = 0; i < profile.questions.length; i++) {
      final expected = _normalize(profile.questions[i].answer);
      final actual = i < responses.length ? _normalize(responses[i]) : '';
      if (actual.isNotEmpty &&
          (actual == expected ||
              actual.contains(expected) ||
              expected.contains(actual))) {
        matches++;
      }
    }

    final success = matches == profile.questions.length;
    return ClaimVerificationResult(
      success: success,
      matchedAnswers: matches,
      totalQuestions: profile.questions.length,
      message: success
          ? 'Proof of ownership verified successfully.'
          : 'Ownership answers did not fully match. Please try again.',
    );
  }

  String _generateClaimCode({
    required String title,
    required String ownerName,
  }) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final seed =
        '${title.trim()}|${ownerName.trim()}|${DateTime.now().microsecondsSinceEpoch}';
    final random = Random(seed.hashCode);
    final buffer = StringBuffer('LF-');
    for (var i = 0; i < 6; i++) {
      buffer.write(chars[random.nextInt(chars.length)]);
    }
    return buffer.toString();
  }

  String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
  }
}
