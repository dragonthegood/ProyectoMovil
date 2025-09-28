import 'package:flutter/material.dart';
import '../data/models/note.dart';
import '../data/repositories/note_repository.dart';
import '../assistant/voice_assistant.dart';

class DeletedScreen extends StatefulWidget {
  const DeletedScreen({super.key});

  @override
  State<DeletedScreen> createState() => _DeletedScreenState();
}

class _DeletedScreenState extends State<DeletedScreen> {
  bool _editMode = false;
  final _repo = NoteRepository();

  String _format(DateTime d) {
    String two(int x) => x.toString().padLeft(2, '0');
    return "${two(d.day)}/${two(d.month)}/${d.year}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Column(
          children: [
            // Header (igual)
            Container(
              color: const Color(0xFFF2F2F7),
              child: SafeArea(
                bottom: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/', // ruta de tu pantalla de inicio
                        (route) => false,
                      ),
                      child: Row(
                        children: const [
                          Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Color(0xFFFFCC00),
                            size: 20,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Inicio',
                            style: TextStyle(
                              fontFamily: 'SFProDisplay',
                              fontSize: 18,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFFFFCC00),
                            ),
                          ),
                        ],
                      ),
                    ),

                    _editMode
                        ? GestureDetector(
                            onTap: () => setState(() => _editMode = false),
                            child: const Text(
                              'Listo',
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFFFFCC00),
                                fontFamily: 'SFProDisplay',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(
                              Icons.menu,
                              color: Color(0xFFFFCC00),
                            ),
                            onPressed: () => setState(() => _editMode = true),
                          ),
                  ],
                ),
              ),
            ),

            Expanded(
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        const Text(
                          'Eliminados',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'SFProDisplay',
                            color: Color(0xFF000000),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Aviso de 30 días (altura corregida, mismo look)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12, // <- en vez de height fijo
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              SizedBox(width: 12),
                              Icon(
                                Icons.delete_outline,
                                color: Color(0xFFFF3B30),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Las notas estarán disponibles aquí por 30 días.\n'
                                  'Después, se eliminarán de forma permanente.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF8C8C8C),
                                    fontFamily: 'SFProDisplay',
                                    height: 1.35, // <- line-height correcto
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Lista de eliminadas (igual, ahora ordenada por fecha desc)
                        Expanded(
                          child: StreamBuilder<List<Note>>(
                            stream: _repo.watchNotes(includeDeleted: true),
                            builder: (context, snap) {
                              if (snap.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              final all = snap.data ?? const <Note>[];
                              final deleted =
                                  all.where((n) => n.isDeleted).toList()..sort(
                                    (a, b) =>
                                        b.updatedAt.compareTo(a.updatedAt),
                                  );

                              if (deleted.isEmpty) {
                                return const Center(
                                  child: Text(
                                    'No hay notas eliminadas.',
                                    style: TextStyle(
                                      fontFamily: 'SFProDisplay',
                                      color: Color(0xFF8C8C8C),
                                    ),
                                  ),
                                );
                              }
                              return ListView.separated(
                                itemCount: deleted.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (ctx, i) {
                                  final n = deleted[i];
                                  return DeletedNoteItem(
                                    title: n.title.isEmpty
                                        ? '(Sin título)'
                                        : n.title,
                                    date: _format(n.updatedAt),
                                    number: (n.content.trim().isEmpty)
                                        ? ''
                                        : (n.content.length > 20
                                              ? "${n.content.substring(0, 20)}..."
                                              : n.content),
                                    editMode: _editMode,
                                    onTap: () {
                                      if (!_editMode) {
                                        Navigator.pushNamed(
                                          context,
                                          '/deleted-detail', // <- muestra contenido
                                          arguments: n.id,
                                        );
                                      }
                                    },
                                    onRestore: () => _repo.restore(n.id),
                                    onHardDelete: () => _repo.hardDelete(n.id),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  // FAB izquierda -> VOZ (reemplaza crear carpeta)
                  Positioned(
                    bottom: 20,
                    left: 20,
                    child: FloatingActionButton(
                      elevation: 0,
                      backgroundColor: const Color(0xFFF2F2F7),
                      heroTag: 'voice',
                      onPressed: () async {
                        await VoiceAssistant.I.openOverlay(context);
                      },

                      child: const Icon(
                        Icons.mic_none, // ícono representativo de voz
                        color: Color(0xFFFFCC00),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DeletedNoteItem extends StatelessWidget {
  final String title;
  final String date;
  final String number;
  final bool editMode;
  final VoidCallback? onTap;
  final VoidCallback? onRestore;
  final VoidCallback? onHardDelete;

  const DeletedNoteItem({
    super.key,
    required this.title,
    required this.date,
    required this.number,
    required this.editMode,
    this.onTap,
    this.onRestore,
    this.onHardDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Contenido principal
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'SFProDisplay',
                        color: Color(0xFF404040),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$date $number',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF999999),
                        fontFamily: 'SFProDisplay',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (editMode)
              Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.restore,
                      color: Colors.black54,
                      size: 20,
                    ),
                    onPressed: onRestore,
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_forever,
                      color: Color(0xFFFF3B30),
                      size: 20,
                    ),
                    onPressed: onHardDelete,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
