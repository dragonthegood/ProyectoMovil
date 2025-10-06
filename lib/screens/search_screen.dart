import 'package:flutter/material.dart';
import '../data/models/note.dart';
import '../data/repositories/note_repository.dart';
import '../data/local/preferences_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  // --- repos & controllers
  final _repo = NoteRepository();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();

  // --- query & args
  String _query = '';
  bool _handledArgs = false;

  // --- historial
  static const _historyKey = 'search.history';
  static const _maxHistory = 8;
  List<String> _history = [];
  List<String> _filteredHistory = [];
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();

    // precarga última búsqueda guardada
    final last = PreferencesService().lastSearchQuery ?? '';
    _query = last;
    _controller.text = last;

    _focus.addListener(() {
      if (_focus.hasFocus) {
        _filterHistory(_query);
        setState(() => _showSuggestions = _filteredHistory.isNotEmpty);
      } else {
        setState(() => _showSuggestions = false);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_handledArgs) return;
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, String>?;
    if (args != null && args['query'] != null) {
      _query = args['query']!;
      _controller.text = _query;
    }
    _handledArgs = true;
    _filterHistory(_query);
    _showSuggestions = _focus.hasFocus && _filteredHistory.isNotEmpty;
    setState(() {});
  }

  // ---------- HISTORIAL ----------
  void _loadHistory() {
    // Usa lectura compatible (migra String -> List<String> si hace falta)
    _history = PreferencesService().getStringListCompat(_historyKey);
    _filteredHistory = List.from(_history);
  }

  Future<void> _persistHistory() async {
    // Guarda de forma segura y vuelve a leer para reflejar el estado real
    await PreferencesService().setStringListSafe(_historyKey, _history);
    _loadHistory();
  }

  Future<void> _addToHistory(String term) async {
    final t = term.trim();
    if (t.isEmpty) return;
    _history.removeWhere((e) => e.trim().toLowerCase() == t.toLowerCase());
    _history.insert(0, t);
    if (_history.length > _maxHistory) {
      _history = _history.sublist(0, _maxHistory);
    }
    await _persistHistory();
    _filterHistory(_query);
    if (mounted) setState(() {}); // refresco UI
  }

  Future<void> _removeFromHistory(String term) async {
    final t = term.trim().toLowerCase();
    _history.removeWhere((e) => e.trim().toLowerCase() == t);
    await _persistHistory();
    _filterHistory(_query);
    if (mounted) setState(() {}); // refresco UI
  }

  Future<void> _clearHistory() async {
    _history.clear();
    // Elimina la clave para evitar residuos
    await PreferencesService().setStringListSafe(_historyKey, _history);
    _loadHistory();
    _filterHistory(_query);
    if (mounted) setState(() {}); // refresco UI
  }

  void _filterHistory(String q) {
    final qq = q.trim().toLowerCase();
    if (qq.isEmpty) {
      _filteredHistory = List.from(_history);
    } else {
      _filteredHistory =
          _history.where((e) => e.toLowerCase().contains(qq)).toList();
    }
  }

  // ---------- QUERY ----------
  void _onQueryChanged(String v) {
    setState(() => _query = v);
    PreferencesService().setLastSearchQuery(v.trim().isEmpty ? null : v);

    _filterHistory(v);
    _showSuggestions = _focus.hasFocus && _filteredHistory.isNotEmpty;
  }

  Future<void> _onSubmitted(String v) async {
    await _addToHistory(v);
    setState(() => _showSuggestions = false);
  }

  Future<void> _useSuggestion(String term) async {
    // Rellena y dispara búsqueda
    _controller.text = term;
    _onQueryChanged(term);
    await _addToHistory(term);
    setState(() => _showSuggestions = false);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Column(
          children: [
            // ---------- Barra de búsqueda ----------
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
                        focusNode: _focus,
                        autofocus: true,
                        decoration: InputDecoration(
                          icon: const Icon(Icons.search, color: Colors.grey),
                          hintText: 'Buscar',
                          hintStyle: const TextStyle(
                            fontFamily: 'SFProDisplay',
                            fontSize: 16,
                          ),
                          border: InputBorder.none,
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Limpiar',
                                  icon: const Icon(Icons.close),
                                  onPressed: () {
                                    setState(() {
                                      _query = '';
                                      _controller.clear();
                                    });
                                    PreferencesService()
                                        .setLastSearchQuery(null);
                                    _filterHistory('');
                                    _showSuggestions = _focus.hasFocus &&
                                        _filteredHistory.isNotEmpty;
                                  },
                                ),
                        ),
                        onChanged: _onQueryChanged,
                        onSubmitted: (v) => _onSubmitted(v),
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

            // ---------- Sugerencias (historial) ----------
            if (_showSuggestions) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _HistorySuggestions(
                  suggestions: _filteredHistory,
                  onTapTerm: (t) => _useSuggestion(t),
                  onRemoveTerm: (t) => _removeFromHistory(t),
                  onClearAll: () => _clearHistory(),
                ),
              ),
              const SizedBox(height: 8),
            ],

            // ---------- Resultados ----------
            Expanded(
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

                  final results = all
                      .where((n) =>
                          !n.isDeleted &&
                          (n.title.toLowerCase().contains(q) ||
                              n.content.toLowerCase().contains(q)))
                      .toList()
                    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

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
                          prev.length > 24 ? '${prev.substring(0, 24)}...' : prev;
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

// ------- UI: lista de sugerencias (historial) -------
class _HistorySuggestions extends StatelessWidget {
  final List<String> suggestions;
  final void Function(String term) onTapTerm;
  final void Function(String term) onRemoveTerm;
  final VoidCallback onClearAll;

  const _HistorySuggestions({
    required this.suggestions,
    required this.onTapTerm,
    required this.onRemoveTerm,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 240),
        child: Column(
          children: [
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: suggestions.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final term = suggestions[i];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.history, color: Colors.grey),
                    title: Text(term),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => onRemoveTerm(term),
                      tooltip: 'Quitar de historial',
                    ),
                    onTap: () => onTapTerm(term),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            TextButton.icon(
              onPressed: onClearAll,
              icon: const Icon(Icons.delete_sweep_outlined),
              label: const Text('Borrar historial'),
            ),
          ],
        ),
      ),
    );
  }
}

// ------- UI: item de resultado -------
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
