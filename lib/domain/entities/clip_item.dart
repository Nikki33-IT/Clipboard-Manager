enum ClipContentType { text, multilineText, link, email, image, html, rtf, file }

class ClipItem {
  final String id;
  final String content;
  final ClipContentType type;
  final DateTime copiedAt;
  DateTime? lastUsedAt;
  int useCount;
  bool isPinned;
  final bool isSecret;

  ClipItem({
    required this.id,
    required this.content,
    required this.type,
    required this.copiedAt,
    this.lastUsedAt,
    this.useCount = 0,
    this.isPinned = false,
    this.isSecret = false,
  });

  ClipItem copyWith({
    DateTime? lastUsedAt,
    int? useCount,
    bool? isPinned,
  }) {
    return ClipItem(
      id: id,
      content: content,
      type: type,
      copiedAt: copiedAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      useCount: useCount ?? this.useCount,
      isPinned: isPinned ?? this.isPinned,
      isSecret: isSecret,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'content': content,
        'type': type.name,
        'copiedAt': copiedAt.toIso8601String(),
        'lastUsedAt': lastUsedAt?.toIso8601String(),
        'useCount': useCount,
        'isPinned': isPinned ? 1 : 0,
        'isSecret': isSecret ? 1 : 0,
      };

  factory ClipItem.fromMap(Map<String, dynamic> map) => ClipItem(
        id: map['id'] as String,
        content: map['content'] as String,
        type: ClipContentType.values.firstWhere(
          (t) => t.name == map['type'],
          orElse: () => ClipContentType.text,
        ),
        copiedAt: DateTime.parse(map['copiedAt'] as String),
        lastUsedAt: map['lastUsedAt'] != null
            ? DateTime.parse(map['lastUsedAt'] as String)
            : null,
        useCount: map['useCount'] as int? ?? 0,
        isPinned: (map['isPinned'] as int? ?? 0) == 1,
        isSecret: (map['isSecret'] as int? ?? 0) == 1,
      );
}
