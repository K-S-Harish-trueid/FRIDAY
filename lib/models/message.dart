class Message {
  final String id;
  final String role;
  final String content;
  final bool isCommand;
  final DateTime timestamp;

  Message({
    String? id,
    required this.role,
    required this.content,
    this.isCommand = false,
    DateTime? timestamp,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        timestamp = timestamp ?? DateTime.now();
}
