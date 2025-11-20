import 'package:flutter/material.dart';
import '../../domain/models/note.dart';
import 'package:proyectomovil/features/notes/infrastructure/repositories/note_repository.dart';

class DeletedNoteDetailScreen extends StatelessWidget {
  const DeletedNoteDetailScreen({super.key});

  String _format(DateTime d) {
    String two(int x) => x.toString().padLeft(2, '0');
    return "${two(d.day)}/${two(d.month)}/${d.year}";
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

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back "Eliminados"
                Padding(
                  padding: const EdgeInsets.only(left: 16, top: 16),
                  child: GestureDetector(
                    onTap: () => Navigator.pushReplacementNamed(context, '/deleted'),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.arrow_back_ios_new_rounded,
                            color: Color(0xFFFFCC00), size: 20),
                        SizedBox(width: 4),
                        Text(
                          'Eliminados',
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

                const SizedBox(height: 24),

                // Título real
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

                // Contenido real
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

                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }
}
