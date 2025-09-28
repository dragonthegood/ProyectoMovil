import 'package:flutter/material.dart';
import '../data/models/note.dart';
import '../data/repositories/note_repository.dart';
import '../assistant/voice_assistant.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  bool _editMode = false;
  final _repo = NoteRepository();

  // Para mostrar "Nota guardada" al volver desde NewNoteScreen
  bool _routeSnackShown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (!_routeSnackShown && args != null && args['showSaved'] == true) {
      _routeSnackShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Nota guardada')));
      });
    }
  }

  String _format(DateTime d) {
    String two(int x) => x.toString().padLeft(2, '0');
    return "${two(d.day)}/${two(d.month)}/${d.year}";
  }

  @override
  Widget build(BuildContext context) {
    // === Mantenemos el MISMO layout y estilo ===
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Column(
          children: [
            // Header con back + menú (idéntico)
            Container(
              color: const Color(0xFFF2F2F7),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () =>
                            Navigator.pushReplacementNamed(context, '/'),
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
            ),
            Expanded(
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Notas',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'SFProDisplay',
                            color: Color(0xFF000000),
                          ),
                        ),
                        const SizedBox(height: 20),
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(context, '/search'),
                          child: Container(
                            height: 36,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5E5EA),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: const [
                                Icon(Icons.search, color: Colors.grey),
                                SizedBox(width: 8),
                                Text(
                                  'Buscar',
                                  style: TextStyle(
                                    fontFamily: 'SFProDisplay',
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Últimos 30 días',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'SFProDisplay',
                            color: Color(0xFF000000),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // === Firestore SIN cambiar el estilo ===
                        // Filtramos !isDeleted y ORDENAMOS: ancladas primero, luego por fecha desc.
                        Expanded(
                          child: StreamBuilder<List<Note>>(
                            stream: _repo.watchNotes(includeDeleted: true),
                            builder: (context, snap) {
                              if (snap.hasError) {
                                return Center(
                                  child: Text(
                                    'Error: ${snap.error}',
                                    style: const TextStyle(
                                      fontFamily: 'SFProDisplay',
                                      color: Color(0xFF8C8C8C),
                                    ),
                                  ),
                                );
                              }
                              if (snap.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              final all = snap.data ?? const <Note>[];
                              final notes =
                                  all.where((n) => !n.isDeleted).toList()
                                    ..sort((a, b) {
                                      if (a.pinned != b.pinned) {
                                        // true antes que false
                                        return a.pinned ? -1 : 1;
                                      }
                                      // dentro del grupo, más recientes primero
                                      return b.updatedAt.compareTo(a.updatedAt);
                                    });

                              if (notes.isEmpty) {
                                return const Center(
                                  child: Text(
                                    'Aún no tienes notas.',
                                    style: TextStyle(
                                      fontFamily: 'SFProDisplay',
                                      color: Color(0xFF8C8C8C),
                                    ),
                                  ),
                                );
                              }

                              return ListView.separated(
                                itemCount: notes.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (ctx, i) {
                                  final n = notes[i];
                                  final date = _format(n.updatedAt);
                                  final preview = (n.content).trim();
                                  final short = preview.length > 30
                                      ? "${preview.substring(0, 30)}..."
                                      : preview;
                                  return NoteCard(
                                    title: n.title.isEmpty
                                        ? '(Sin título)'
                                        : n.title,
                                    date: date,
                                    preview: short,
                                    editMode: _editMode,
                                    pinned: n.pinned, // <--- NUEVO
                                    onPin: () => _repo.update(
                                      n.copyWith(pinned: !n.pinned),
                                    ),
                                    onDelete: () => _repo.softDelete(n.id),
                                    onTap: () {
                                      if (!_editMode) {
                                        Navigator.pushNamed(
                                          context,
                                          '/note-detail',
                                          arguments: n.id,
                                        );
                                      }
                                    },
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
                  // Contador inferior (mismo diseño), ahora filtrado
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      width: 100,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E5EA),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: StreamBuilder<List<Note>>(
                        stream: _repo.watchNotes(includeDeleted: true),
                        builder: (context, snap) {
                          final count = (snap.data ?? const <Note>[])
                              .where((n) => !n.isDeleted)
                              .length;
                          return Center(
                            child: Text(
                              '$count notas',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF8C8C8C),
                                fontFamily: 'SFProDisplay',
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFF2F2F7),
        elevation: 0,
        onPressed: () => Navigator.pushNamed(context, '/new-note'),
        child: const Icon(Icons.note_add_outlined, color: Color(0xFFFFCC00)),
      ),
    );
  }
}

class NoteCard extends StatelessWidget {
  final String title;
  final String date;
  final String preview;
  final bool editMode;
  final bool pinned; // <--- NUEVO
  final VoidCallback? onTap;
  final VoidCallback? onPin;
  final VoidCallback? onDelete;

  const NoteCard({
    super.key,
    required this.title,
    required this.date,
    required this.preview,
    required this.editMode,
    required this.pinned, // <--- NUEVO
    this.onTap,
    this.onPin,
    this.onDelete,
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
            Expanded(
              child: Container(
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
                      '$date $preview',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF8C8C8C),
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
                    // cambia visualmente: llenado si está anclada
                    icon: Icon(
                      pinned ? Icons.push_pin : Icons.push_pin_outlined,
                      color: Colors.black54,
                      size: 20,
                    ),
                    onPressed: onPin,
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(
                      Icons.delete,
                      color: Color(0xFFFF3B30),
                      size: 20,
                    ),
                    onPressed: onDelete,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
