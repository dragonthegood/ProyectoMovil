import 'package:flutter/material.dart';
import '../data/models/note.dart';
import '../data/repositories/note_repository.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final _repo = NoteRepository();
  String _query = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, String>?;
    if (args != null && args['query'] != null) {
      _query = args['query']!;
      _controller.text = _query;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // === MISMO DISEÑO, resultados dinámicos ===
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E5EA),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: TextField(
                        controller: _controller,
                        autofocus: true,
                        decoration: const InputDecoration(
                          icon: Icon(Icons.search, color: Colors.grey),
                          hintText: 'Buscar',
                          hintStyle: TextStyle(
                            fontFamily: 'SFProDisplay',
                            fontSize: 16,
                          ),
                          border: InputBorder.none,
                        ),
                        onChanged: (v) => setState(() => _query = v),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFFFFCC00),
                        fontFamily: 'SFProDisplay',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            Expanded(
              // 🔁 Traemos todas las notas y filtramos en cliente (sin cambiar UI)
              child: StreamBuilder<List<Note>>(
                stream: _repo.watchNotes(includeDeleted: true),
                builder: (context, snap) {
                  if (_query.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final q = _query.trim().toLowerCase();
                  final all = snap.data ?? const <Note>[];

                  // Filtra no eliminadas y que contengan en título o contenido
                  final results = all
                      .where((n) =>
                          !n.isDeleted &&
                          (n.title.toLowerCase().contains(q) ||
                              n.content.toLowerCase().contains(q)))
                      .toList()
                    ..sort(
                      (a, b) => b.updatedAt.compareTo(a.updatedAt),
                    );

                  if (results.isEmpty) {
                    return Center(
                      child: Text(
                        'Sin resultados para "$_query".',
                        style: const TextStyle(
                          fontFamily: 'SFProDisplay',
                          color: Color(0xFF999999),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: results.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final n = results[i];
                      final prev = n.content.trim();
                      final short =
                          prev.length > 24 ? "${prev.substring(0, 24)}..." : prev;
                      return SuggestionTile(
                        title: n.title.isEmpty ? '(Sin título)' : n.title,
                        preview: short,
                        onTap: () => Navigator.pushNamed(
                          context,
                          '/note-detail',
                          arguments: n.id,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SuggestionTile extends StatelessWidget {
  final String title;
  final String preview;
  final VoidCallback onTap;

  const SuggestionTile({
    super.key,
    required this.title,
    required this.preview,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'SFProDisplay',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF404040),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              preview,
              style: const TextStyle(
                fontFamily: 'SFProDisplay',
                fontSize: 14,
                color: Color(0xFF999999),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
