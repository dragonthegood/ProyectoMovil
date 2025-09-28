import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/note.dart';

class NoteRepository {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('users').doc(_uid).collection('notes');

  // ------------------ NOTAS ------------------

  Future<String> create(Note note) async {
    final data = note.copyWith(updatedAt: DateTime.now());
    final ref = await _col.add(data.toMap());
    await ref.update({'id': ref.id});
    return ref.id;
  }

  Future<void> update(Note note) async {
    await _col
        .doc(note.id)
        .update(note.copyWith(updatedAt: DateTime.now()).toMap());
  }

  Future<void> softDelete(String id) async {
    await _col.doc(id).update({
      'isDeleted': true,
      'updatedAt': DateTime.now().toUtc(),
    });
  }

  Future<void> restore(String id) async {
    await _col.doc(id).update({
      'isDeleted': false,
      'updatedAt': DateTime.now().toUtc(),
    });
  }

  Future<void> hardDelete(String id) async {
    await _col.doc(id).delete();
  }

  Stream<List<Note>> watchNotes({bool includeDeleted = false}) {
    Query<Map<String, dynamic>> q = _col.orderBy('updatedAt', descending: true);
    if (!includeDeleted) {
      q = q.where('isDeleted', isEqualTo: false);
    }
    return q.snapshots().map(
      (s) => s.docs.map((d) => Note.fromMap(d.id, d.data())).toList(),
    );
  }

  Stream<List<Note>> search(String query) {
    if (query.trim().isEmpty) return watchNotes();
    final start = query;
    final end = '$query\uf8ff';
    return _col
        .where('isDeleted', isEqualTo: false)
        .orderBy('title')
        .startAt([start])
        .endAt([end])
        .snapshots()
        .map((s) => s.docs.map((d) => Note.fromMap(d.id, d.data())).toList());
  }

  // Nota por id
  Stream<Note?> watchNote(String id) {
    return _col.doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Note.fromMap(doc.id, doc.data()!);
    });
  }

  /// Busca una nota cuyo título contenga [query] (case-insensitive).
  Future<Note?> findByTitleContains(
    String query, {
    bool includeDeleted = false,
  }) async {
    final q = query.trim().toLowerCase();
    // Traemos un puñado y filtramos en cliente para evitar necesitar índice.
    var ref = _col.orderBy('updatedAt', descending: true).limit(50);
    if (!includeDeleted) {
      ref =
          ref.where('isDeleted', isEqualTo: false)
              as Query<Map<String, dynamic>>;
    }
    final snap = await ref.get();
    for (final d in snap.docs) {
      final n = Note.fromMap(d.id, d.data());
      if ((includeDeleted || !n.isDeleted) &&
          n.title.toLowerCase().contains(q)) {
        return n;
      }
    }
    return null;
  }

  // ------------------ ADJUNTOS ------------------

  Future<String> _uploadBytes({
    required String noteId,
    required String pathInNote,
    required Uint8List data,
    required String contentType,
  }) async {
    final ref = _storage
        .ref()
        .child('users')
        .child(_uid)
        .child('notes')
        .child(noteId)
        .child(pathInNote);
    await ref.putData(data, SettableMetadata(contentType: contentType));
    return await ref.getDownloadURL();
  }

  Future<void> _addAttachmentMeta(
    String noteId,
    Map<String, dynamic> meta,
  ) async {
    await _col.doc(noteId).collection('attachments').add({
      ...meta,
      'createdAt': DateTime.now().toUtc(),
    });
  }

  Future<void> addImageAttachment({
    required String noteId,
    required String name,
    required Uint8List bytes,
    required String mimeType,
    int? size,
  }) async {
    final ext = name.split('.').last.toLowerCase();
    final filename = '${DateTime.now().millisecondsSinceEpoch}.$ext';
    final url = await _uploadBytes(
      noteId: noteId,
      pathInNote: 'images/$filename',
      data: bytes,
      contentType: mimeType,
    );
    await _addAttachmentMeta(noteId, {
      'type': 'image',
      'name': name,
      'size': size ?? bytes.length,
      'mime': mimeType,
      'url': url,
    });
  }

  Future<void> addFileAttachment({
    required String noteId,
    required String name,
    required Uint8List bytes,
    required String mimeType,
    int? size,
  }) async {
    final ext = name.split('.').last.toLowerCase();
    final filename = '${DateTime.now().millisecondsSinceEpoch}.$ext';
    final url = await _uploadBytes(
      noteId: noteId,
      pathInNote: 'files/$filename',
      data: bytes,
      contentType: mimeType,
    );
    await _addAttachmentMeta(noteId, {
      'type': 'file',
      'name': name,
      'size': size ?? bytes.length,
      'mime': mimeType,
      'url': url,
    });
  }

  Stream<List<Map<String, dynamic>>> watchAttachments(String noteId) {
    return _col
        .doc(noteId)
        .collection('attachments')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => d.data()).toList());
  }
}
