import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/folder.dart';
import 'note_repository.dart';

class FolderRepository {
  final _db = FirebaseFirestore.instance;
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('users').doc(_uid).collection('folders');

  final _noteRepo = NoteRepository();

  Future<String> create(String name) async {
    final now = DateTime.now().toUtc();
    final ref = await _col.add({
      'uid': _uid,
      'name': name,
      'pinned': false,
      'createdAt': now,
      'updatedAt': now,
    });
    await ref.update({'id': ref.id});
    return ref.id;
  }

  Future<void> rename(String id, String name) async {
    await _col.doc(id).update({
      'name': name,
      'updatedAt': DateTime.now().toUtc(),
    });
  }

  Future<void> setPinned(String id, bool pinned) async {
    await _col.doc(id).update({
      'pinned': pinned,
      'updatedAt': DateTime.now().toUtc(),
    });
  }

  /// Obtiene una carpeta por id (o null si no existe)
  Future<FolderModel?> getById(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return FolderModel.fromFirestore(doc);
  }

  /// Solo borra el doc de la carpeta
  Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }

  /// Pasa todas las notas de la carpeta a Eliminados y borra la carpeta
  Future<void> deleteAndSoftDeleteNotes(String id) async {
    await _noteRepo.softDeleteAllInFolder(id);
    await _col.doc(id).delete();
  }

  /// Lista de carpetas (pinned primero)
  Stream<List<FolderModel>> watch() {
    return _col.orderBy('updatedAt', descending: true).snapshots().map((s) {
      final list = s.docs.map((d) => FolderModel.fromFirestore(d)).toList();
      list.sort((a, b) {
        if (a.pinned == b.pinned) return b.updatedAt.compareTo(a.updatedAt);
        return a.pinned ? -1 : 1;
      });
      return list;
    });
  }
}
