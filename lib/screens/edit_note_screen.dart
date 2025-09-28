import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../data/models/note.dart';
import '../data/repositories/note_repository.dart';

class EditNoteScreen extends StatefulWidget {
  const EditNoteScreen({super.key});

  @override
  State<EditNoteScreen> createState() => _EditNoteScreenState();
}

class _EditNoteScreenState extends State<EditNoteScreen> {
  final _title = TextEditingController();
  final _content = TextEditingController();
  final _repo = NoteRepository();

  Note? _original;
  bool _saved = false;
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
  void dispose() {
    if (!_saved && _original != null) {
      final t = _title.text.trim();
      final c = _content.text.trim();
      if (t != _original!.title || c != _original!.content) {
        _repo.update(_original!.copyWith(title: t, content: c));
      }
    }
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_original == null) return;
    final t = _title.text.trim();
    final c = _content.text.trim();
    await _repo.update(_original!.copyWith(title: t, content: c));
    _saved = true;
    if (!mounted) return;
    Navigator.pop(context, true);
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
    if (f.size > _maxSize) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La imagen supera 100 MB')),
        );
      }
      return;
    }
    if (f.bytes == null || _original == null) return;
    await _repo.addImageAttachment(
      noteId: _original!.id,
      name: f.name,
      bytes: f.bytes!,
      mimeType: _guessImageMime(f.extension),
      size: f.size,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Imagen agregada a la nota')),
      );
    }
  }

  Future<void> _pickFile() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      withData: true,
    );
    if (res == null) return;
    final f = res.files.first;
    if (f.size > _maxSize) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El archivo supera 100 MB')),
        );
      }
      return;
    }
    if (f.bytes == null || _original == null) return;
    await _repo.addFileAttachment(
      noteId: _original!.id,
      name: f.name,
      bytes: f.bytes!,
      mimeType: _guessFileMime(f.extension),
      size: f.size,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Archivo adjuntado a la nota')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final noteId = ModalRoute.of(context)?.settings.arguments as String?;
    if (noteId == null) {
      return const Scaffold(
        body: Center(child: Text('No se recibió el ID de la nota')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: StreamBuilder<Note?>(
          stream: _repo.watchNote(noteId),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final note = snap.data;
            if (note == null) {
              return const Center(child: Text('Nota no encontrada'));
            }
            if (_original == null) {
              _original = note;
              _title.text = note.title;
              _content.text = note.content;
            }

            // === MISMO DISEÑO que "Nueva nota" ===
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                          'Notas',
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
                        fontSize: 16,
                        fontFamily: 'SFProDisplay',
                        color: Color(0xFF404040),
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
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
                      const Icon(Icons.edit,
                          color: Color(0xFFFFCC00), size: 28),
                      GestureDetector(
                        onTap: _save,
                        child: const Icon(Icons.save_rounded,
                            color: Color(0xFFFFCC00), size: 28),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
