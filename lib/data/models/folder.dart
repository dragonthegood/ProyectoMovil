import 'package:cloud_firestore/cloud_firestore.dart';

class FolderModel {
  final String id;
  final String uid;
  final String name;
  final bool pinned;
  final DateTime createdAt;
  final DateTime updatedAt;

  FolderModel({
    required this.id,
    required this.uid,
    required this.name,
    this.pinned = false,
    required this.createdAt,
    required this.updatedAt,
  });

  FolderModel copyWith({
    String? id,
    String? uid,
    String? name,
    bool? pinned,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FolderModel(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      name: name ?? this.name,
      pinned: pinned ?? this.pinned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'uid': uid,
        'name': name,
        'pinned': pinned,
        'createdAt': createdAt.toUtc(),
        'updatedAt': updatedAt.toUtc(),
      };

  factory FolderModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data()!;
    return FolderModel(
      id: (m['id'] as String?) ?? doc.id,
      uid: m['uid'] as String,
      name: (m['name'] as String?) ?? '',
      pinned: (m['pinned'] as bool?) ?? false,
      createdAt: (m['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.now().toUtc(),
      updatedAt: (m['updatedAt'] as Timestamp?)?.toDate() ??
          DateTime.now().toUtc(),
    );
  }
}
