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
  final _scroll = ScrollController();

  String _format(DateTime d) {
    String two(int x) => x.toString().padLeft(2, '0');
    return "${two(d.day)}/${two(d.month)}/${d.year}";
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  // ========= NUEVO: restaurar siempre a "Notas" (sin carpeta) =========
  // DeletedScreen: dentro de _DeletedScreenState
  Future<void> _restoreToRoot(Note n) async {
    try {
      // 1) Restablecer la nota (pone isDeleted = false en el backend)
      await _repo.restore(n.id);

      // 2) Traer la versión fresca de la nota para no pisar "isDeleted"
      final all = await _repo.watchNotes(includeDeleted: true).first;
      final fresh = all.firstWhere(
        (x) => x.id == n.id,
        orElse: () => n, // fallback, por si acaso
      );

      // 3) Quitarle la carpeta (sin tocar isDeleted)
      await _repo.update(
        fresh.copyWith(folderId: null),
      ); // o '' si tu backend prefiere vacío

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Nota "${fresh.title.isEmpty ? "(Sin título)" : fresh.title}" restaurada a Notas',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo restaurar la nota')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
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

            // Título + aviso
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Eliminados',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'SFProDisplay',
                  color: Color(0xFF000000),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
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
                    Icon(Icons.delete_outline, color: Color(0xFFFF3B30)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Las notas estarán disponibles aquí por 30 días.\n'
                        'Después, se eliminarán de forma permanente.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF8C8C8C),
                          fontFamily: 'SFProDisplay',
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // LISTA con Scrollbar
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: StreamBuilder<List<Note>>(
                  stream: _repo.watchNotes(includeDeleted: true),
                  builder: (context, snap) {
                    final all = snap.data ?? const <Note>[];
                    final deleted = all.where((n) => n.isDeleted).toList()
                      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

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

                    return Scrollbar(
                      controller: _scroll,
                      interactive: true,
                      child: ListView.separated(
                        controller: _scroll,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 8),
                        itemCount: deleted.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (ctx, i) {
                          final n = deleted[i];
                          final snippet = n.content.trim().isEmpty
                              ? ''
                              : (n.content.length > 60
                                    ? '${n.content.substring(0, 60)}...'
                                    : n.content);
                          return _DeletedNoteItem(
                            title: n.title.isEmpty ? '(Sin título)' : n.title,
                            date: _format(n.updatedAt),
                            subtitle: snippet,
                            editMode: _editMode,
                            onTap: () {
                              if (!_editMode) {
                                Navigator.pushNamed(
                                  context,
                                  '/edit-note',
                                  arguments: n.id,
                                );
                              }
                            },
                            // ===== CAMBIO CLAVE: restaurar a "Notas"
                            onRestore: () async {
                              await _repo.restoreToRoot(n.id);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Nota "${n.title.isEmpty ? "(Sin título)" : n.title}" restaurada a Notas',
                                  ),
                                ),
                              );
                            },
                            onHardDelete: () => _repo.hardDelete(n.id),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ),

            // BARRA INFERIOR
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () async {
                        await VoiceAssistant.I.openOverlay(context);
                      },
                      icon: const Icon(
                        Icons.mic_none,
                        color: Color(0xFFFFCC00),
                      ),
                    ),
                    StreamBuilder<List<Note>>(
                      stream: _repo.watchNotes(includeDeleted: true),
                      builder: (context, snap) {
                        final deleted = (snap.data ?? const <Note>[])
                            .where((n) => n.isDeleted)
                            .length;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5E5EA),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$deleted notas',
                            style: const TextStyle(
                              fontFamily: 'SFProDisplay',
                              color: Color(0xFF8C8C8C),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 48),
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

class _DeletedNoteItem extends StatelessWidget {
  final String title;
  final String date;
  final String subtitle;
  final bool editMode;
  final VoidCallback? onTap;
  final VoidCallback? onRestore;
  final VoidCallback? onHardDelete;

  const _DeletedNoteItem({
    super.key,
    required this.title,
    required this.date,
    required this.subtitle,
    required this.editMode,
    this.onTap,
    this.onRestore,
    this.onHardDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onTap: onTap,
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            fontFamily: 'SFProDisplay',
            color: Color(0xFF404040),
          ),
        ),
        subtitle: Text(
          '$date ${subtitle.isEmpty ? '' : ' $subtitle'}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF999999),
            fontFamily: 'SFProDisplay',
          ),
        ),
        trailing: editMode
            ? Row(
                mainAxisSize: MainAxisSize.min,
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
              )
            : const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Color(0xFF8C8C8C),
              ),
      ),
    );
  }
}
