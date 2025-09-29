import 'package:flutter/material.dart';
import '../data/models/note.dart';
import '../data/repositories/note_repository.dart';
import '../assistant/voice_assistant.dart';
import '../data/models/folder.dart';
import '../data/repositories/folder_repository.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _editMode = false;
  final _repo = NoteRepository();
  final _folderRepo = FolderRepository();

  // ===== NUEVO: manejar args entrantes desde el asistente (una sola vez) =====
  bool _handledRouteArgs = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_handledRouteArgs) return;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _handleExternalActions(args);
    }
    _handledRouteArgs = true;
  }

  Future<void> _handleExternalActions(Map args) async {
    // 1) Eliminar carpeta por nombre (disparado por el asistente de voz)
    final deleteByName = (args['deleteFolderByName'] as String?)?.trim();
    if (deleteByName != null && deleteByName.isNotEmpty) {
      await _deleteFolderByName(deleteByName);
    }

    // Puedes agregar aquí otros casos si los usas:
    // - Renombrar: {'folderRenamedFrom': 'Trabajo', 'folderRenamedTo': 'Clientes'}
    // - Mover nota: {'folder': 'Mercado', 'movedNote': 'Compras'}
  }

  String _norm(String s) => s.toLowerCase().trim();

  Future<void> _deleteFolderByName(String name) async {
    final folder = await _findFolderByName(name);
    if (folder == null) {
      _showSnack('No encontré la carpeta "$name".');
      return;
    }
    await _deleteFolderAndTrashNotes(folder);
  }

  // Busca con el stream existente (sin modificar el repositorio)
  Future<FolderModel?> _findFolderByName(String name) async {
    try {
      final all = await _folderRepo.watch().first; // snapshot actual
      FolderModel? target;
      for (final f in all) {
        // por si el nombre pudiera venir nulo:
        final fname = (f.name ?? '').toString();
        if (_norm(fname) == _norm(name)) {
          target = f;
          break;
        }
      }
      return target; // puede ser null si no se encontró
    } catch (_) {
      return null;
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _deleteFolderAndTrashNotes(FolderModel f) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar carpeta'),
        content: Text(
          '¿Seguro que deseas eliminar la carpeta "${f.name}"?\n\n'
          'Todas sus notas se moverán a la sección "Eliminados".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _folderRepo.deleteAndSoftDeleteNotes(f.id);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Carpeta "${f.name}" eliminada')));
  }

  Future<void> _renameFolder(FolderModel f) async {
    final ctrl = TextEditingController(text: f.name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Renombrar carpeta'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Nombre'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    final name = ctrl.text.trim();
    if (ok == true && name.isNotEmpty) {
      await _folderRepo.rename(f.id, name);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Carpeta renombrada')));
    }
  }

  Future<void> _togglePin(FolderModel f) async {
    await _folderRepo.setPinned(f.id, !f.pinned);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(f.pinned ? 'Carpeta desfijada' : 'Carpeta fijada'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Safe area inferior (gestures / notch)
    final safeBottom = MediaQuery.of(context).padding.bottom;

    // === NUEVO: Reserva de espacio para que el último ítem no quede tapado ===
    const fabSize = 56.0; // tamaño estándar del FAB
    const gap = 28.0; // separación vertical visual respecto al borde
    final reservedBottom =
        safeBottom + fabSize + gap + 24.0; // 24 extra por sombra/holgura

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Stack(
          children: [
            // === SCROLL ÚNICO ===
            CustomScrollView(
              slivers: [
                // PADDING LATERAL para todo el contenido
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 10),

                      // Header
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
                            onPressed: () =>
                                setState(() => _editMode = !_editMode),
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

                      // Buscador (tappable)
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
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

                      // Cantidad de carpetas
                      StreamBuilder<List<FolderModel>>(
                        stream: _folderRepo.watch(),
                        builder: (context, snapF) {
                          final n =
                              (snapF.data ?? const <FolderModel>[]).length;
                          return Text(
                            '$n',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'SFProDisplay',
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),

                      // Grupo Notas/Eliminados (con counts)
                      StreamBuilder<List<Note>>(
                        stream: _repo.watchNotes(includeDeleted: true),
                        builder: (context, snap) {
                          final all = snap.data ?? const <Note>[];
                          final notesCount = all
                              .where(
                                (n) =>
                                    !n.isDeleted &&
                                    (n.folderId == null || n.folderId!.isEmpty),
                              )
                              .length;
                          final deletedCount = all
                              .where((n) => n.isDeleted)
                              .length;

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                FolderTile(
                                  icon: Icons.folder_outlined,
                                  label: 'Notas',
                                  count: notesCount,
                                  isTop: true,
                                  isBottom: false,
                                  isDisabled: _editMode,
                                ),
                                const Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: Color(0xFFE5E5EA),
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
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 16),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          'Carpetas',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ]),
                  ),
                ),

                // Grupo de carpetas (stream) como sliver
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 0,
                  ),
                  sliver: StreamBuilder<List<FolderModel>>(
                    stream: _folderRepo.watch(),
                    builder: (context, snapF) {
                      final folders = snapF.data ?? const <FolderModel>[];
                      if (folders.isEmpty) {
                        return const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Text('No hay carpetas aún'),
                          ),
                        );
                      }

                      return SliverToBoxAdapter(
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              for (int i = 0; i < folders.length; i++) ...[
                                _FolderRow(
                                  folder: folders[i],
                                  isFirst: i == 0,
                                  isLast: i == folders.length - 1,
                                  editMode: _editMode,
                                  onOpen: () {
                                    Navigator.pushNamed(
                                      context,
                                      '/folder-notes',
                                      arguments: {
                                        'id': folders[i].id,
                                        'name': folders[i].name,
                                      },
                                    );
                                  },
                                  onTogglePin: () => _togglePin(folders[i]),
                                  onRename: () => _renameFolder(folders[i]),
                                  onDelete: () =>
                                      _deleteFolderAndTrashNotes(folders[i]),
                                ),
                                if (i != folders.length - 1)
                                  const Divider(
                                    height: 1,
                                    thickness: 1,
                                    color: Color(0xFFE5E5EA),
                                  ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // === NUEVO: Espacio final proporcional a los FABs + safe area
                SliverToBoxAdapter(child: SizedBox(height: reservedBottom)),
              ],
            ),

            // === FAB izquierda -> VOZ
            Positioned(
              bottom: gap + safeBottom,
              left: 20,
              child: FloatingActionButton(
                elevation: 0,
                backgroundColor: const Color(0xFFF2F2F7),
                heroTag: 'voice',
                onPressed: () async {
                  await VoiceAssistant.I.openOverlay(context);
                },
                child: const Icon(Icons.mic_none, color: Color(0xFFFFCC00)),
              ),
            ),

            // === FAB centro -> crear carpeta
            Positioned(
              bottom:
                  (gap - 4) + safeBottom, // un pelín más bajo para el central
              left: 0,
              right: 0,
              child: Center(
                child: FloatingActionButton(
                  elevation: 0,
                  backgroundColor: const Color(0xFFF2F2F7),
                  heroTag: 'folder',
                  onPressed: () async {
                    final created = await Navigator.pushNamed(
                      context,
                      '/new-folder',
                    );
                    if (created == true && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Carpeta creada')),
                      );
                    }
                  },
                  child: const Icon(
                    Icons.create_new_folder_outlined,
                    color: Color(0xFFFFCC00),
                  ),
                ),
              ),
            ),

            // === FAB derecha -> crear nota
            Positioned(
              bottom: gap + safeBottom,
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

/* =======================  TILE FIJO ========================= */

class FolderTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final int? count; // permite nulo
  final bool isTop;
  final bool isBottom;
  final bool isDisabled;
  final VoidCallback? onTap;

  const FolderTile({
    super.key,
    required this.icon,
    required this.label,
    this.count,
    this.isTop = false,
    this.isBottom = false,
    this.isDisabled = false,
    this.onTap,
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

    return ClipRRect(
      borderRadius: borderRadius,
      child: Opacity(
        opacity: isDisabled ? 0.4 : 1.0,
        child: ListTile(
          tileColor: Colors.white,
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
              if (count != null)
                Text(
                  '$count',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontFamily: 'SFProDisplay',
                    color: Color(0xFF8C8C8C),
                  ),
                ),
              if (count != null) const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Color(0xFF8C8C8C),
              ),
            ],
          ),
          onTap: isDisabled
              ? null
              : onTap ??
                    () {
                      if (label == 'Notas') {
                        Navigator.pushNamed(context, '/notes');
                      } else if (label == 'Eliminados') {
                        Navigator.pushNamed(context, '/deleted');
                      }
                    },
        ),
      ),
    );
  }
}

/* ============ ITEM DE CARPETA ============ */

class _FolderRow extends StatelessWidget {
  final FolderModel folder;
  final bool isFirst;
  final bool isLast;
  final bool editMode;
  final VoidCallback onOpen;
  final VoidCallback onTogglePin;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _FolderRow({
    required this.folder,
    required this.isFirst,
    required this.isLast,
    required this.editMode,
    required this.onOpen,
    required this.onTogglePin,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = isFirst && isLast
        ? BorderRadius.circular(12)
        : isFirst
        ? const BorderRadius.vertical(top: Radius.circular(12))
        : isLast
        ? const BorderRadius.vertical(bottom: Radius.circular(12))
        : BorderRadius.zero;

    return ClipRRect(
      borderRadius: borderRadius,
      child: StreamBuilder<int>(
        stream: NoteRepository().countByFolder(folder.id),
        builder: (context, snapCount) {
          final count = snapCount.data ?? 0;
          return ListTile(
            tileColor: Colors.white,
            leading: const Icon(
              Icons.folder_outlined,
              color: Color(0xFFFFCC00),
            ),
            title: Text(
              folder.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                fontFamily: 'SFProDisplay',
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$count',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8C8C8C),
                  ),
                ),
                const SizedBox(width: 8),
                if (editMode) ...[
                  IconButton(
                    tooltip: folder.pinned ? 'Quitar fijado' : 'Fijar',
                    onPressed: onTogglePin,
                    icon: Icon(
                      folder.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                    ),
                    color: folder.pinned
                        ? const Color(0xFFFFCC00)
                        : const Color(0xFF8C8C8C),
                    splashRadius: 20,
                  ),
                  IconButton(
                    tooltip: 'Renombrar',
                    onPressed: onRename,
                    icon: const Icon(Icons.edit),
                    color: const Color(0xFF8C8C8C),
                    splashRadius: 20,
                  ),
                  IconButton(
                    tooltip: 'Eliminar carpeta',
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: onDelete,
                    splashRadius: 20,
                  ),
                ] else ...[
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: Color(0xFF8C8C8C),
                  ),
                ],
              ],
            ),
            onTap: editMode ? null : onOpen,
          );
        },
      ),
    );
  }
}
