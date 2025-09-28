class Note {
  final String id;
  final String uid;
  final String title;
  final String content;
  final bool isDeleted;
  final bool pinned;
  final DateTime createdAt;
  final DateTime updatedAt;

  Note({
    required this.id,
    required this.uid,
    required this.title,
    required this.content,
    required this.isDeleted,
    required this.pinned,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Note.empty(String uid) {
    final now = DateTime.now();
    return Note(
      id: '',
      uid: uid,
      title: '',
      content: '',
      isDeleted: false,
      pinned: false,
      createdAt: now,
      updatedAt: now,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'uid': uid,
        'title': title,
        'content': content,
        'isDeleted': isDeleted,
        'pinned': pinned,
        'createdAt': createdAt.toUtc(),
        'updatedAt': updatedAt.toUtc(),
      };

  factory Note.fromMap(String id, Map<String, dynamic> map) {
    final created = map['createdAt'];
    final updated = map['updatedAt'];
    DateTime toDt(dynamic v) {
      if (v is DateTime) return v;
      if (v is dynamic && v is! String && v is! int) {
        try {
          // Firestore Timestamp
          return v.toDate();
        } catch (_) {}
      }
      return DateTime.now();
    }

    return Note(
      id: id,
      uid: map['uid'] as String,
      title: (map['title'] ?? '') as String,
      content: (map['content'] ?? '') as String,
      isDeleted: (map['isDeleted'] ?? false) as bool,
      pinned: (map['pinned'] ?? false) as bool,
      createdAt: toDt(created),
      updatedAt: toDt(updated),
    );
  }

  Note copyWith({
    String? id,
    String? title,
    String? content,
    bool? isDeleted,
    bool? pinned,
    DateTime? updatedAt,
  }) {
    return Note(
      id: id ?? this.id,
      uid: uid,
      title: title ?? this.title,
      content: content ?? this.content,
      isDeleted: isDeleted ?? this.isDeleted,
      pinned: pinned ?? this.pinned,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
