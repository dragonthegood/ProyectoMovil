import 'package:flutter/material.dart';
import 'package:proyectomovil/features/notes/domain/models/note.dart';
import 'package:proyectomovil/features/notes/infrastructure/repositories/note_repository.dart';
import 'package:proyectomovil/features/notes/application/voice_assistant.dart';
import 'package:proyectomovil/core/infrastructure/local/preferences_service.dart';
import 'package:proyectomovil/features/notes/application/share_helper.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final _repo = NoteRepository();
  final _scroll = ScrollController();

  // 🔎 Estado de búsqueda
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  bool _editMode = false;

  @override
  void initState() {
    super.initState();
    // Cargar última búsqueda guardada (opcional)
    final last = PreferencesService().lastSearchQuery ?? '';
    _query = last;
    _searchCtrl.text = last;
   
  }

  @override
  void dispose() {
    _scroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) {
    String two(int x) => x.toString().padLeft(2, '0');
    return "${two(d.day)}/${two(d.month)}/${d.year}";
  }

  bool _matches(Note n, String q) {
    if (q.isEmpty) return true;
    final qq = q.toLowerCase().trim();
    return n.title.toLowerCase().contains(qq) ||
        n.content.toLowerCase().contains(qq);
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

            // 🔎 Buscador ACTIVO (filtra en vivo)
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
                child: TextField(
                  controller: _searchCtrl,
                  enabled: true,
                  decoration: InputDecoration(
                    hintText: 'Buscar',
                    hintStyle: const TextStyle(
                      fontFamily: 'SFProDisplay',
                      fontSize: 16,
                    ),
                    border: InputBorder.none,
                    icon: const Icon(Icons.search),
                    // Limpia rápidamente la búsqueda
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Limpiar',
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setState(() {
                                _query = '';
                                _searchCtrl.clear();
                              });
                              PreferencesService().setLastSearchQuery(null);
                            },
                          ),
                  ),
                  onChanged: (v) {
                    setState(() => _query = v);
                    // Guardar/limpiar preferencia según contenido
                    PreferencesService().setLastSearchQuery(
                      v.trim().isEmpty ? null : v,
                    );
                  },
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
                  // solo raíz (notas sin carpeta)
                  stream: _repo.watchByFolder(folderId: null),
                  builder: (context, snap) {
                    final notes = snap.data ?? const <Note>[];

                    // Aplica filtro por búsqueda
                    final filtered =
                        notes.where((n) => _matches(n, _query)).toList()
                          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

                    if (filtered.isEmpty) {
                      return Center(
                        child: Text(
                          _query.isEmpty
                              ? 'Sin notas'
                              : 'Sin resultados para "$_query".',
                          style: const TextStyle(
                            fontFamily: 'SFProDisplay',
                            color: Color(0xFF999999),
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
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) {
                          final n = filtered[i];
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
                                    // NUEVO: compartir
                                    IconButton(
                                      tooltip: 'Compartir nota',
                                      icon: const Icon(
                                        Icons.share_outlined,
                                        color: Colors.blueGrey,
                                      ),
                                      onPressed: () async {
                                        await ShareHelper.shareNote(n);
                                      },
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
