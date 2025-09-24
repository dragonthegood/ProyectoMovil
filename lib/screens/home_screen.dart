import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _editMode = false;

  final folders = const <FolderData>[
    FolderData(icon: Icons.folder_outlined, label: 'Notas', count: 1),
    FolderData(icon: Icons.delete_outline, label: 'Eliminados', count: 1),
  ];

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
                            'Carpetas',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'SFProDisplay',
                            ),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _editMode = !_editMode;
                          });
                        },
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
                          color: Color(0xFFFFCC00),
                          onPressed: () {
                            setState(() {
                              _editMode = true;
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Buscador
                  GestureDetector(
                    onTap: _editMode
                        ? null
                        : () {
                            Navigator.pushNamed(context, '/search');
                          },
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
                  Text(
                    folders.length.toString(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'SFProDisplay',
                    ),
                  ),
                  const SizedBox(height: 12),

                  Expanded(
                    child: ListView.separated(
                      itemCount: folders.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 0),
                      itemBuilder: (context, index) {
                        final data = folders[index];
                        final isTop = index == 0;
                        final isBottom = index == folders.length - 1;

                        final isLocked = _editMode &&
                            (data.label == 'Notas' || data.label == 'Eliminados');

                        return FolderTile(
                          icon: data.icon,
                          label: data.label,
                          count: data.count,
                          isTop: isTop,
                          isBottom: isBottom,
                          isDisabled: isLocked,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Botón crear carpeta
            Positioned(
              bottom: 20,
              left: 20,
              child: FloatingActionButton(
                elevation: 0,
                backgroundColor: const Color(0xFFF2F2F7),
                heroTag: 'folder',
                onPressed: () async {
                  final newLabel =
                      await Navigator.pushNamed(context, '/new-folder');
                  if (newLabel != null && context.mounted) {
                    print("Carpeta creada: $newLabel");
                  }
                },
                child: const Icon(
                  Icons.create_new_folder_outlined,
                  color: Color(0xFFFFCC00),
                ),
              ),
            ),

            // Botón crear nota
            Positioned(
              bottom: 20,
              right: 20,
              child: FloatingActionButton(
                elevation: 0,
                backgroundColor: const Color(0xFFF2F2F7),
                heroTag: 'note',
                onPressed: () {
                  Navigator.pushNamed(context, '/new-note');
                },
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

/* =======================  MODELO ======================= */

class FolderData {
  final IconData icon;
  final String label;
  final int count;
  const FolderData({
    required this.icon,
    required this.label,
    required this.count,
  });
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
