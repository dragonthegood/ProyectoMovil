import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../data/models/note.dart';
import '../data/models/folder.dart';                  // <-- importa el modelo
import '../data/repositories/note_repository.dart';
import '../data/repositories/folder_repository.dart'; // <-- repositorio de carpetas

class NoteDetailScreen extends StatelessWidget {
  const NoteDetailScreen({super.key});

  String _format(DateTime d) {
    String two(int x) => x.toString().padLeft(2, '0');
    return "${two(d.day)}/${two(d.month)}/${d.year}";
  }

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
  Widget build(BuildContext context) {
    final noteId = ModalRoute.of(context)?.settings.arguments as String?;
    final repo = NoteRepository();

    if (noteId == null) {
      return const Scaffold(
        body: Center(child: Text('No se recibió el ID de la nota')),
      );
    }

    Future<void> _pickImage(String id) async {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp'],
        allowMultiple: false,
        withData: true,
      );
      if (res == null) return;
      final f = res.files.first;
      if (f.size > 100 * 1024 * 1024) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('La imagen supera 100 MB')),
          );
        }
        return;
      }
      if (f.bytes == null) return;
      await repo.addImageAttachment(
        noteId: id,
        name: f.name,
        bytes: f.bytes!,
        mimeType: _guessImageMime(f.extension),
        size: f.size,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Imagen agregada a la nota')),
        );
      }
    }

    Future<void> _pickFile(String id) async {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: true,
      );
      if (res == null) return;
      final f = res.files.first;
      if (f.size > 100 * 1024 * 1024) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('El archivo supera 100 MB')),
          );
        }
        return;
      }
      if (f.bytes == null) return;
      await repo.addFileAttachment(
        noteId: id,
        name: f.name,
        bytes: f.bytes!,
        mimeType: _guessFileMime(f.extension),
        size: f.size,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Archivo adjuntado a la nota')),
        );
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: StreamBuilder<Note?>(
          stream: repo.watchNote(noteId),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final note = snap.data;
            if (note == null) {
              return const Center(child: Text('Nota no encontrada'));
            }

            final inFolder =
                note.folderId != null && note.folderId!.trim().isNotEmpty;

            // Pedimos el nombre de la carpeta (solo si aplica)
            final Future<FolderModel?> folderFuture = inFolder
                ? FolderRepository().getById(note.folderId!)
                : Future.value(null);

            return FutureBuilder<FolderModel?>(
              future: folderFuture,
              builder: (context, folderSnap) {
                final folderName =
                    inFolder ? (folderSnap.data?.name ?? 'Carpeta') : 'Notas';

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back dinámico (carpeta o notas)
                    Padding(
                      padding: const EdgeInsets.only(left: 16, top: 16),
                      child: GestureDetector(
                        onTap: () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          } else {
                            // Fallback de deep-link: volvemos a la carpeta o a Notas
                            if (inFolder) {
                              Navigator.pushReplacementNamed(
                                context,
                                '/folder-notes',
                                arguments: {
                                  'id': note.folderId,
                                  'name': folderName,
                                },
                              );
                            } else {
                              Navigator.pushReplacementNamed(
                                  context, '/notes');
                            }
                          }
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Color(0xFFFFCC00),
                              size: 20,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              folderName, // <-- etiqueta dinámica
                              style: const TextStyle(
                                color: Color(0xFFFFCC00),
                                fontSize: 16,
                                fontFamily: 'SFProDisplay',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Título
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        note.title.isEmpty ? '(Sin título)' : note.title,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'SFProDisplay',
                          color: Color(0xFF000000),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Fecha
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        _format(note.updatedAt),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF8C8C8C),
                          fontFamily: 'SFProDisplay',
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Contenido
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SingleChildScrollView(
                          child: Text(
                            note.content,
                            style: const TextStyle(
                              fontSize: 16,
                              fontFamily: 'SFProDisplay',
                              color: Color(0xFF404040),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Barra inferior (funcional)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          GestureDetector(
                            onTap: () => _pickFile(note.id),
                            child: const Icon(
                              Icons.attachment,
                              color: Color(0xFFFFCC00),
                              size: 28,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _pickImage(note.id),
                            child: const Icon(
                              Icons.image_outlined,
                              color: Color(0xFFFFCC00),
                              size: 28,
                            ),
                          ),
                          GestureDetector(
                            onTap: () async {
                              final result = await Navigator.pushNamed(
                                context,
                                '/edit-note',
                                arguments: note.id,
                              );
                              if (result == true && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Cambios guardados'),
                                  ),
                                );
                              }
                            },
                            child: const Icon(
                              Icons.edit,
                              color: Color(0xFFFFCC00),
                              size: 28,
                            ),
                          ),
                          const Icon(
                            Icons.save_rounded,
                            color: Color(0xFFFFCC00),
                            size: 28,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
