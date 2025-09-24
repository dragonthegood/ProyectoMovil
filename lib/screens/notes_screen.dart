import 'package:flutter/material.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  bool _editMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          color: const Color(0xFFF2F2F7),
          child: SafeArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pushReplacementNamed(context, '/'),
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
                        icon: const Icon(Icons.menu, color: Color(0xFFFFCC00)),
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

                NoteCard(
                  title: 'Lista de compra',
                  date: '25/08/2025',
                  preview: 'Arroz, carne...',
                  editMode: _editMode,
                  onTap: () {
                    if (!_editMode) {
                      Navigator.pushNamed(context, '/note-detail');
                    }
                  },
                ),
              ],
            ),
          ),
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
        backgroundColor: const Color(0xFFF2F2F7),
        elevation: 0,
        onPressed: () {
          Navigator.pushNamed(context, '/new-note');
        },
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
  final VoidCallback? onTap;

  const NoteCard({
    super.key,
    required this.title,
    required this.date,
    required this.preview,
    required this.editMode,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  Container(
                    height: 60,
                    width: 52,
                    alignment: Alignment.center,
                    child: IconButton(
                      icon: const Icon(Icons.delete, color: Color(0xFFFF3B30), size: 20),
                      onPressed: () {
                        // Acción de eliminar
                      },
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
