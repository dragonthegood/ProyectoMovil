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
  final _repo = NoteRepository();
  final _scroll = ScrollController();
  bool _editMode = false;

  String _fmtDate(DateTime d) {
    String two(int x) => x.toString().padLeft(2, '0');
    return "${two(d.day)}/${two(d.month)}/${d.year}";
  }

  @override
  void dispose() {
    _scroll.dispose();
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
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
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
                            color: Color(0xFFFFCC00),
                            fontSize: 16,
                            fontFamily: 'SFProDisplay',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() => _editMode = !_editMode),
                    child: Text(
                      _editMode ? 'Listo' : '',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'SFProDisplay',
                        color: Color(0xFFFFCC00),
                      ),
                    ),
                  ),
                  if (!_editMode)
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.menu),
                      color: const Color(0xFFFFCC00),
                      onPressed: () => setState(() => _editMode = true),
                    ),
                ],
              ),
            ),

            // Título + buscador
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Notas',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'SFProDisplay',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E5EA),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.centerLeft,
                child: const TextField(
                  enabled: false,
                  decoration: InputDecoration(
                    hintText: 'Buscar',
                    hintStyle: TextStyle(
                      fontFamily: 'SFProDisplay',
                      fontSize: 16,
                    ),
                    border: InputBorder.none,
                    icon: Icon(Icons.search),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Últimos 30 días',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 16,
                  fontFamily: 'SFProDisplay',
                ),
              ),
            ),
            const SizedBox(height: 12),

            // LISTA con Scrollbar
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: StreamBuilder<List<Note>>(
                  // solo raíz
                  stream: _repo.watchByFolder(folderId: null),
                  builder: (context, snap) {
                    final notes = snap.data ?? const <Note>[];
                    if (notes.isEmpty) {
                      return const Center(child: Text('Sin notas'));
                    }
                    return Scrollbar(
                      controller: _scroll,
                      interactive: true,
                      child: ListView.separated(
                        controller: _scroll,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 8),
                        itemCount: notes.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) {
                          final n = notes[i];
                          return Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            child: ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              title: Text(
                                n.title.isEmpty ? '(Sin título)' : n.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontFamily: 'SFProDisplay',
                                ),
                              ),
                              subtitle: Text(
                                _fmtDate(n.updatedAt),
                                style: const TextStyle(
                                  color: Color(0xFF8C8C8C),
                                  fontFamily: 'SFProDisplay',
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_editMode) ...[
                                    IconButton(
                                      tooltip: n.pinned
                                          ? 'Quitar anclado'
                                          : 'Anclar',
                                      icon: Icon(
                                        n.pinned
                                            ? Icons.push_pin
                                            : Icons.push_pin_outlined,
                                        color: const Color(0xFF8C8C8C),
                                      ),
                                      onPressed: () =>
                                          _repo.setPinned(n.id, !n.pinned),
                                    ),
                                    IconButton(
                                      tooltip: 'Eliminar',
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed: () => _repo.softDelete(n.id),
                                    ),
                                  ] else
                                    const Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 14,
                                      color: Color(0xFF8C8C8C),
                                    ),
                                ],
                              ),
                              onTap: _editMode
                                  ? null
                                  : () {
                                      Navigator.pushNamed(
                                        context,
                                        '/edit-note',
                                        arguments: n.id,
                                      );
                                    },
                            ),
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
                      stream: _repo.watchByFolder(folderId: null),
                      builder: (context, snap) {
                        final total = (snap.data ?? const <Note>[]).length;
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
                            '$total notas',
                            style: const TextStyle(
                              fontFamily: 'SFProDisplay',
                              color: Color(0xFF8C8C8C),
                            ),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/new-note');
                      },
                      icon: const Icon(
                        Icons.note_add_outlined,
                        color: Color(0xFFFFCC00),
                      ),
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
