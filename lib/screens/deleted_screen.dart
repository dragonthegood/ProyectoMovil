import 'package:flutter/material.dart';

class DeletedScreen extends StatefulWidget {
  const DeletedScreen({super.key});

  @override
  State<DeletedScreen> createState() => _DeletedScreenState();
}

class _DeletedScreenState extends State<DeletedScreen> {
  bool _editMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.centerLeft,
          color: const Color(0xFFF2F2F7),
          child: SafeArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                  },
                  child: Row(
                    children: const [
                      Icon(Icons.arrow_back_ios_new_rounded,
                          color: Color(0xFFFFCC00), size: 20),
                      SizedBox(width: 4),
                      Text(
                        'Carpetas',
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
                        onTap: () {
                          setState(() {
                            _editMode = false;
                          });
                        },
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
                        icon: const Icon(Icons.menu,
                            color: Color(0xFFFFCC00)),
                        onPressed: () {
                          setState(() {
                            _editMode = true;
                          });
                        },
                      ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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

                // Barra de búsqueda
                GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(context, '/search');
                  },
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E5EA),
                      borderRadius: BorderRadius.circular(12),
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

                const SizedBox(height: 20),
                const Text(
                  'Las notas estarán disponibles aquí por 30 días.\nDespués, se eliminarán de forma permanente.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF8C8C8C),
                    fontFamily: 'SFProDisplay',
                  ),
                ),
                const SizedBox(height: 20),

                // Ítem de nota eliminada
                DeletedNoteItem(
                  title: 'Contacto administracion',
                  date: '22/08/2025',
                  number: '3222222',
                  editMode: _editMode,
                  onTap: () {
                    if (!_editMode) {
                      Navigator.pushNamed(context, '/deleted-detail');
                    }
                  },
                ),
              ],
            ),
          ),

          // Texto "1 notas"
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: const Center(
              child: Text(
                '1 notas',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF8C8C8C),
                  fontFamily: 'SFProDisplay',
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        elevation: 0,
        backgroundColor: const Color(0xFFF2F2F7),
        onPressed: () {
          Navigator.pushNamed(context, '/new-note');
        },
        child: const Icon(Icons.note_add_outlined, color: Color(0xFFFFCC00)),
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

  const DeletedNoteItem({
    super.key,
    required this.title,
    required this.date,
    required this.number,
    required this.editMode,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Contenido principal
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
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

            // Íconos de acción
            if (editMode)
              Container(
                height: 64,
                width: 100,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    // Restaurar
                    Expanded(
                      child: IconButton(
                        icon: const Icon(Icons.restore,
                            color: Color(0xFF8C8C8C), size: 20),
                        onPressed: () {
                          // Acción de restaurar
                        },
                      ),
                    ),
                    Container(
                      width: 1,
                      height: double.infinity,
                      color: const Color(0xFFE5E5EA),
                    ),
                    // Eliminar
                    Expanded(
                      child: IconButton(
                        icon: const Icon(Icons.delete,
                            color: Color(0xFFFF3B30), size: 20),
                        onPressed: () {
                          // Acción de eliminar
                        },
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
