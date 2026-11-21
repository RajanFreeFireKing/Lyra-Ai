class MemoryItem {
  final String id;
  final String type;
  final String textOriginal;
  final String textEn;
  final String quote;
  final String origin;
  final bool pinned;
  final DateTime createdAt;

  const MemoryItem({
    required this.id,
    required this.type,
    required this.textOriginal,
    required this.textEn,
    required this.quote,
    required this.origin,
    this.pinned = false,
    required this.createdAt,
  });

  factory MemoryItem.fromJson(Map<String, dynamic> json) {
    return MemoryItem(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'identity',
      textOriginal: json['text_original'] as String? ?? '',
      textEn: json['text_en'] as String? ?? '',
      quote: json['quote'] as String? ?? '',
      origin: json['origin'] as String? ?? 'stated',
      pinned: (json['pinned'] as int? ?? 0) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int? ?? 0),
    );
  }
}
