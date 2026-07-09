class Action {
  final String type;
  final Map<String, dynamic> payload;

  const Action({required this.type, this.payload = const {}});

  factory Action.fromJson(Map<String, dynamic> json) {
    return Action(
      type: json['type'] as String,
      payload: (json['payload'] as Map<String, dynamic>?) ?? const {},
    );
  }
}
