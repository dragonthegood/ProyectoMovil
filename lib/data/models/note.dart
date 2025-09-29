import 'package:cloud_firestore/cloud_firestore.dart';

class Note {
  final String id;
  final String uid;
  final String title;
  final String content;
  final bool isDeleted;
  final bool pinned;
  final String? folderId;
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
    this.folderId,
  });

  // -------- Helpers --------
  static DateTime _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return DateTime.now().toUtc();
  }

  static DateTime _now() => DateTime.now().toUtc();

  // -------- Factory VACÍO (lo que te falta) --------
  /// Crea una nota vacía para el [uid]. Útil para `Note.empty(uid).copyWith(...)`.
  /// Puedes pasar [folderId] si la nota nace dentro de una carpeta.
  factory Note.empty(String uid, {String? folderId}) => Note(
        id: '',                 // se completará luego (repo guarda ref.id)
        uid: uid,
        title: '',
        content: '',
        isDeleted: false,
        pinned: false,
        folderId: folderId,
        createdAt: _now(),
        updatedAt: _now(),
      );

  // -------- Factories desde Firestore --------
  factory Note.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Note(
      id: doc.id,
      uid: data['uid'] ?? '',
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      isDeleted: data['isDeleted'] ?? false,
      pinned: data['pinned'] ?? false,
      folderId: data['folderId'],
      createdAt: _toDate(data['createdAt']),
      updatedAt: _toDate(data['updatedAt']),
    );
  }

  factory Note.fromMap(Map<String, dynamic> map) => Note(
        id: map['id'] ?? '',
        uid: map['uid'] ?? '',
        title: map['title'] ?? '',
        content: map['content'] ?? '',
        isDeleted: map['isDeleted'] ?? false,
        pinned: map['pinned'] ?? false,
        folderId: map['folderId'],
        createdAt: _toDate(map['createdAt']),
        updatedAt: _toDate(map['updatedAt']),
      );

  // -------- Copy/Map --------
  Note copyWith({
    String? id,
    String? uid,
    String? title,
    String? content,
    bool? isDeleted,
    bool? pinned,
    String? folderId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Note(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      title: title ?? this.title,
      content: content ?? this.content,
      isDeleted: isDeleted ?? this.isDeleted,
      pinned: pinned ?? this.pinned,
      folderId: folderId ?? this.folderId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'uid': uid,
        'title': title,
        'content': content,
        'isDeleted': isDeleted,
        'pinned': pinned,
        'folderId': folderId,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };
}
