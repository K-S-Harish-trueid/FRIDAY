class ConversationSummary {
  final String id;
  final String title;
  final DateTime updatedAt;

  const ConversationSummary({
    required this.id,
    required this.title,
    required this.updatedAt,
  });

  factory ConversationSummary.fromJson(Map<String, dynamic> json) {
    return ConversationSummary(
      id: json['id'] as String,
      title: json['title'] as String,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
