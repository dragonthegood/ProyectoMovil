import 'package:flutter/material.dart';
import '../data/models/note.dart';
import '../data/repositories/note_repository.dart';
import '../assistant/voice_assistant.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _editMode = false;
  final _repo = NoteRepository();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(top: 36),
                          child: Text(
                            'Inicio',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'SFProDisplay',
                            ),
                          ),
                        ),
                      ),
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
                  const SizedBox(height: 12),

                  // Buscador (mismo look)
                  GestureDetector(
                    onTap: _editMode
                        ? null
                        : () => Navigator.pushNamed(context, '/search'),
                    child: AbsorbPointer(
                      absorbing: _editMode,
                      child: Opacity(
                        opacity: _editMode ? 0.4 : 1.0,
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
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Número de carpetas (siguen siendo 2)
                  const Text(
                    '2',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'SFProDisplay',
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Contadores dinámicos
                  Expanded(
                    child: StreamBuilder<List<Note>>(
                      stream: _repo.watchNotes(includeDeleted: true),
                      builder: (context, snap) {
                        final all = snap.data ?? const <Note>[];
                        final notesCount = all
                            .where((n) => !n.isDeleted)
                            .length;
                        final deletedCount = all
                            .where((n) => n.isDeleted)
                            .length;

                        return ListView(
                          children: [
                            FolderTile(
                              icon: Icons.folder_outlined,
                              label: 'Notas',
                              count: notesCount,
                              isTop: true,
                              isBottom: false,
                              isDisabled: _editMode,
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: 0.78,
                                child: const Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: Color(0xFFE5E5EA),
                                ),
                              ),
                            ),
                            FolderTile(
                              icon: Icons.delete_outline,
                              label: 'Eliminados',
                              count: deletedCount,
                              isTop: false,
                              isBottom: true,
                              isDisabled: _editMode,
                            ),
                          ],
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

            // FAB derecha -> crear nota (igual que antes)
            Positioned(
              bottom: 20,
              right: 20,
              child: FloatingActionButton(
                elevation: 0,
                backgroundColor: const Color(0xFFF2F2F7),
                heroTag: 'note',
                onPressed: () => Navigator.pushNamed(context, '/new-note'),
                child: const Icon(
                  Icons.note_add_outlined,
                  color: Color(0xFFFFCC00),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* =======================  TILE ========================= */

class FolderTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final bool isTop;
  final bool isBottom;
  final bool isDisabled;

  const FolderTile({
    super.key,
    required this.icon,
    required this.label,
    required this.count,
    this.isTop = false,
    this.isBottom = false,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    BorderRadius borderRadius = BorderRadius.zero;
    if (isTop && isBottom) {
      borderRadius = BorderRadius.circular(12);
    } else if (isTop) {
      borderRadius = const BorderRadius.vertical(top: Radius.circular(12));
    } else if (isBottom) {
      borderRadius = const BorderRadius.vertical(bottom: Radius.circular(12));
    }

    return Column(
      children: [
        Opacity(
          opacity: isDisabled ? 0.4 : 1.0,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: borderRadius,
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: Icon(icon, color: const Color(0xFFFFCC00)),
              title: Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'SFProDisplay',
                  color: Color(0xFF404040),
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$count',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontFamily: 'SFProDisplay',
                      color: Color(0xFF8C8C8C),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: Color(0xFF8C8C8C),
                  ),
                ],
              ),
              onTap: isDisabled
                  ? null
                  : () {
                      if (label == 'Notas') {
                        Navigator.pushNamed(context, '/notes');
                      }
                      if (label == 'Eliminados') {
                        Navigator.pushNamed(context, '/deleted');
                      }
                    },
            ),
          ),
        ),
        if (!isBottom)
          Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.78,
              child: const Divider(
                height: 1,
                thickness: 1,
                color: Color(0xFFE5E5EA),
              ),
            ),
          ),
      ],
    );
  }
}
