import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/models/note.dart';
import '../data/repositories/note_repository.dart';

class NewNoteScreen extends StatefulWidget {
  const NewNoteScreen({super.key});

  @override
  State<NewNoteScreen> createState() => _NewNoteScreenState();
}

class _NewNoteScreenState extends State<NewNoteScreen> {
  final _title = TextEditingController();
  final _content = TextEditingController();
  final _repo = NoteRepository();

  bool _saved = false;
  String? _noteId;
  String? _folderId; // <-- carpeta destino (si viene)
  static const int _maxSize = 100 * 1024 * 1024;

  // ---- Helpers MIME
  String _guessImageMime(String? ext) {
    switch ((ext ?? '').toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/png';
    }
  }

  String _guessFileMime(String? ext) {
    switch ((ext ?? '').toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'txt':
        return 'text/plain';
      case 'csv':
        return 'text/csv';
      case 'json':
        return 'application/json';
      case 'xml':
        return 'application/xml';
      case 'zip':
        return 'application/zip';
      case 'rar':
        return 'application/vnd.rar';
      case 'mp3':
        return 'audio/mpeg';
      case 'mp4':
        return 'video/mp4';
      default:
        return 'application/octet-stream';
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Acepta folderId y opcionalmente title/content
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _folderId = args['folderId'] as String?;
      final t = args['title'] as String?;
      final c = args['content'] as String?;
      if (t != null) _title.text = t;
      if (c != null) _content.text = c;
    }
  }

  Future<String> _ensureNoteId() async {
    if (_noteId != null) return _noteId!;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final id = await _repo.create(
      Note.empty(uid, folderId: _folderId).copyWith(
        title: _title.text.trim(),
        content: _content.text.trim(),
      ),
    );
    setState(() => _noteId = id);
    return id;
  }

  Future<void> _autoSaveIfNeeded() async {
    final t = _title.text.trim();
    final c = _content.text.trim();
    if (_saved) return;
    if (t.isEmpty && c.isEmpty) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    if (_noteId == null) {
      _noteId = await _repo.create(
        Note.empty(uid, folderId: _folderId).copyWith(title: t, content: c),
      );
    } else {
      // ✅ conservamos folderId al actualizar
      await _repo.update(
        Note.empty(uid, folderId: _folderId)
            .copyWith(id: _noteId!, title: t, content: c),
      );
    }
  }

  Future<void> _save() async {
    final t = _title.text.trim();
    final c = _content.text.trim();

    if (t.isEmpty && c.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe un título o contenido')),
      );
      return;
    }

    final uid = FirebaseAuth.instance.currentUser!.uid;

    if (_noteId == null) {
      _noteId = await _repo.create(
        Note.empty(uid, folderId: _folderId).copyWith(title: t, content: c),
      );
    } else {
      // ✅ conservamos folderId al actualizar
      await _repo.update(
        Note.empty(uid, folderId: _folderId)
            .copyWith(id: _noteId!, title: t, content: c),
      );
    }

    _saved = true;
    if (!mounted) return;

    // Si viene de carpeta, volvemos a la carpeta; si no, a Notas
    if (_folderId != null && _folderId!.isNotEmpty) {
      Navigator.pop(context); // volver a la carpeta; se refresca por stream
    } else {
      Navigator.pushReplacementNamed(
        context,
        '/notes',
        arguments: {'showSaved': true},
      );
    }
  }

  Future<void> _pickImage() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp'],
      allowMultiple: false,
      withData: true,
    );
    if (res == null) return;
    final f = res.files.first;
    final bytes = f.bytes;
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo leer la imagen')),
      );
      return;
    }
    if (f.size > _maxSize) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La imagen supera 100 MB')),
      );
      return;
    }
    final id = await _ensureNoteId();
    await _repo.addImageAttachment(
      noteId: id,
      name: f.name,
      bytes: bytes,
      mimeType: _guessImageMime(f.extension),
      size: f.size,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Imagen agregada a la nota')),
    );
  }

  Future<void> _pickFile() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      withData: true,
    );
    if (res == null) return;
    final f = res.files.first;
    final bytes = f.bytes;
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo leer el archivo')),
      );
      return;
    }
    if (f.size > _maxSize) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El archivo supera 100 MB')),
      );
      return;
    }
    final id = await _ensureNoteId();
    await _repo.addFileAttachment(
      noteId: id,
      name: f.name,
      bytes: bytes,
      mimeType: _guessFileMime(f.extension),
      size: f.size,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Archivo adjuntado a la nota')),
    );
  }

  // --- abre el lienzo de dibujo
  Future<void> _openDraw() async {
    final id = await _ensureNoteId(); // necesitamos un id para guardar el PNG
    final ok = await Navigator.pushNamed(
      context,
      '/draw',
      arguments: {'noteId': id},
    );
    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dibujo agregado')),
      );
    }
  }

  @override
  void dispose() {
    _autoSaveIfNeeded();
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back (a carpeta o a Notas)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 16),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.arrow_back_ios_new_rounded,
                        color: Color(0xFFFFCC00), size: 20),
                    SizedBox(width: 4),
                    Text(
                      'Volver',
                      style: TextStyle(
                        color: Color(0xFFFFCC00),
                        fontSize: 16,
                        fontFamily: 'SFProDisplay',
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Título
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _title,
                decoration: const InputDecoration(
                  hintText: 'Título',
                  border: InputBorder.none,
                ),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'SFProDisplay',
                  color: Color(0xFF000000),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Contenido
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _content,
                  decoration: const InputDecoration(
                    hintText: 'Contenido...',
                    border: InputBorder.none,
                  ),
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  style: const TextStyle(
                    fontSize: 14,
                    fontFamily: 'SFProDisplay',
                    color: Color(0xFF404040),
                  ),
                ),
              ),
            ),

            // Barra inferior
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GestureDetector(
                      onTap: _pickFile,
                      child: const Icon(Icons.attachment,
                          color: Color(0xFFFFCC00), size: 28),
                    ),
                    GestureDetector(
                      onTap: _pickImage,
                      child: const Icon(Icons.image_outlined,
                          color: Color(0xFFFFCC00), size: 28),
                    ),
                    // 🖊️ Abrir lienzo de dibujo
                    GestureDetector(
                      onTap: _openDraw,
                      child: const Icon(Icons.edit,
                          color: Color(0xFFFFCC00), size: 28),
                    ),
                    GestureDetector(
                      onTap: _save,
                      child: const Icon(Icons.save_rounded,
                          color: Color(0xFFFFCC00), size: 28),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
