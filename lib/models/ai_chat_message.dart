class AiChatMessage {
  const AiChatMessage({
    required this.role,
    required this.content,
  });

  final String role;
  final String content;

  bool get isUser => role == 'user';

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
      };
}
