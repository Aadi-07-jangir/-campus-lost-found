import 'item_model.dart';

/// Represents a potential match between a lost and found item.
class MatchResult {
  final ItemModel item;
  final double similarity;
  final bool isMatch;

  MatchResult({
    required this.item,
    required this.similarity,
    this.isMatch = false,
  });

  int get percentMatch => (similarity * 100).round();
}
