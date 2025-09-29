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

  // dentro de NoteRepository
  Future<void> restoreToRoot(String noteId) async {
    final ref = _col.doc(noteId); // ajusta si tu colección se llama distinto
    // 1er intento: folderId = null
    try {
      await ref.update({
        'isDeleted': false,
        'folderId': null, // quita la carpeta
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    } catch (_) {
      // 2º intento: si tu esquema no permite null, usar string vacía
      await ref.update({
        'isDeleted': false,
        'folderId': '', // quita la carpeta (como vacío)
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // ------------------ NOTAS ------------------

  Future<String> create(Note note) async {
    final data = note.copyWith(updatedAt: DateTime.now().toUtc());
    final ref = await _col.add(data.toMap());
    await ref.update({'id': ref.id});
    return ref.id;
  }

  Future<void> update(Note note) async {
    await _col
        .doc(note.id)
        .update(note.copyWith(updatedAt: DateTime.now().toUtc()).toMap());
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
      (s) => s.docs.map((d) => Note.fromFirestore(d)).toList(),
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
        .map((s) => s.docs.map((d) => Note.fromFirestore(d)).toList());
  }

  // Nota por id
  Stream<Note?> watchNote(String id) {
    return _col.doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Note.fromFirestore(doc);
    });
  }

  /// Busca una nota cuyo título contenga [query]
  Future<Note?> findByTitleContains(
    String query, {
    bool includeDeleted = false,
  }) async {
    final q = query.trim().toLowerCase();
    Query<Map<String, dynamic>> ref = _col
        .orderBy('updatedAt', descending: true)
        .limit(50);
    if (!includeDeleted) {
      ref = ref.where('isDeleted', isEqualTo: false);
    }
    final snap = await ref.get();
    for (final d in snap.docs) {
      final n = Note.fromFirestore(d);
      if ((includeDeleted || !n.isDeleted) &&
          n.title.toLowerCase().contains(q)) {
        return n;
      }
    }
    return null;
  }

  // Fijar / quitar pin de una nota
  Future<void> setPinned(String id, bool pinned) async {
    await _col.doc(id).update({
      'pinned': pinned,
      'updatedAt': DateTime.now().toUtc(),
    });
  }

  // ------------------ ADJUNTOS ------------------

  // Subida con espera del TaskSnapshot y reintentos para el downloadURL
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

    final task = ref.putData(data, SettableMetadata(contentType: contentType));

    // Espera a que finalice la subida
    final snap = await task.whenComplete(() {});

    // Reintentos para el URL (propagación eventual de Storage)
    String? url;
    var attempt = 0;
    while (attempt < 5) {
      try {
        url = await snap.ref.getDownloadURL();
        break;
      } catch (_) {
        await Future.delayed(Duration(milliseconds: 150 * (attempt + 1)));
        attempt++;
      }
    }
    url ??= await ref.getDownloadURL();
    return url;
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

  // Sube imagen y devuelve su URL público de descarga
  Future<String> addImageAttachment({
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

    return url;
  }

  // Sube archivo y devuelve su URL
  Future<String> addFileAttachment({
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

    return url;
  }

  // Dentro de NoteRepository
  Future<void> createFolder(String name) async {
    final data = {
      'name': name,
      'createdAt': DateTime.now(),
      'updatedAt': DateTime.now(),
    };

    // Guardar la carpeta en la colección de Firestore
    final ref = await _db
        .collection('users')
        .doc(_uid)
        .collection('folders')
        .add(data);

    // Guardar el id generado
    await ref.update({'id': ref.id});
  }

  // Añade texto al final del contenido de la nota y actualiza la fecha
  Future<void> appendToContent(String noteId, String text) async {
    final doc = await _col.doc(noteId).get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final oldContent = (data['content'] as String?) ?? '';
    final newContent = oldContent.isEmpty ? text : '$oldContent\n$text';

    await _col.doc(noteId).update({
      'content': newContent,
      'updatedAt': DateTime.now().toUtc(),
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

  // --------- Carpetas ----------

  /// Crear nota directamente dentro de una carpeta
  Future<String> createInFolder(String? folderId) async {
    final id = _col.doc().id;
    final now = DateTime.now().toUtc();
    final note = Note(
      id: id,
      uid: _uid,
      title: '',
      content: '',
      isDeleted: false,
      pinned: false,
      folderId: folderId,
      createdAt: now,
      updatedAt: now,
    );
    await _col.doc(id).set(note.toMap());
    return id;
  }

  /// Stream de notas por carpeta (null => sin carpeta)
  Stream<List<Note>> watchByFolder({
    String? folderId,
    bool includeDeleted = false,
  }) {
    Query<Map<String, dynamic>> q = _col;
    if (folderId == null) {
      q = q.where('folderId', isNull: true);
    } else {
      q = q.where('folderId', isEqualTo: folderId);
    }
    if (!includeDeleted) {
      q = q.where('isDeleted', isEqualTo: false);
    }
    return q
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Note.fromFirestore(d)).toList());
  }

  // Conteo de notas por carpeta (excluye eliminadas por defecto)
  Stream<int> countByFolder(String folderId, {bool includeDeleted = false}) {
    Query<Map<String, dynamic>> q = _col.where('folderId', isEqualTo: folderId);
    if (!includeDeleted) {
      q = q.where('isDeleted', isEqualTo: false);
    }
    return q.snapshots().map((s) => s.size);
  }

  // Pasa TODAS las notas de una carpeta a 'Eliminados' (soft delete)
  Future<void> softDeleteAllInFolder(String folderId) async {
    final q = await _col.where('folderId', isEqualTo: folderId).get();
    final batch = _db.batch();
    final now = DateTime.now().toUtc();
    for (final d in q.docs) {
      batch.update(d.reference, {'isDeleted': true, 'updatedAt': now});
    }
    await batch.commit();
  }

  // Notas "raíz" (sin carpeta)
  Stream<List<Note>> watchRootNotes({bool includeDeleted = false}) {
    return watchByFolder(folderId: null, includeDeleted: includeDeleted);
  }
}
