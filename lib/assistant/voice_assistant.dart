import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import '../data/repositories/note_repository.dart';
import '../widgets/voice_overlay.dart';
import '../data/repositories/folder_repository.dart';

/// Intenciones soportadas
enum _Intent {
  none,
  openNote,
  createNote,
  deleteNote,
  restoreNote,
  editNote,
  search,

  // Carpetas
  createFolder,
  openFolder,
  renameFolder,
  deleteFolder,

  // Notas dentro/entre carpetas
  createNoteInFolder,
  moveNoteToFolder,
  moveNoteToRoot,

  // Listados / navegación
  listFolders,
  listNotes,
  listNotesInFolder,
  openDeleted,

  // Papelera (acciones delegadas a UI)
  emptyTrash,
  restoreAllTrash,

  // Varios
  readNoteAloud,
  stopReading,
  toggleConfirmOn,
  toggleConfirmOff,
  help,

  // Desambiguación
  genericDelete,
}

/// Estado de la conversación (slots)
class _Session {
  _Intent intent = _Intent.none;

  // slots comunes
  String? title;
  String? content;
  String? query;

  // slots carpeta/nota
  String? folder;     // carpeta objetivo
  String? newFolder;  // nuevo nombre de carpeta
  String? noteTitle;  // para mover nota

  // control
  String? targetType; // 'nota' | 'carpeta'
  bool askedFolderForCreate = false;

  /// 'title','content','query','confirm',
  /// 'folder','newFolder','noteTitle','targetType','folderOptional'
  String? pendingSlot;

  void clear() {
    intent = _Intent.none;
    title = null;
    content = null;
    query = null;
    folder = null;
    newFolder = null;
    noteTitle = null;
    targetType = null;
    askedFolderForCreate = false;
    pendingSlot = null;
  }
}

class VoiceAssistant {
  VoiceAssistant._();
  static final VoiceAssistant I = VoiceAssistant._();

  final stt.SpeechToText _stt = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final _repo = NoteRepository();
  final _folderRepo = FolderRepository();

  bool _available = false;

  // ===== Config =====
  bool _confirmCreateEdit = true; // confirmación para crear/editar

  // ===== Estado expuesto al overlay =====
  final ValueNotifier<bool> isListening = ValueNotifier(false);
  final ValueNotifier<String> liveText = ValueNotifier('');
  final ValueNotifier<String> prompt = ValueNotifier(
    'Toca “Hablar” y dime qué hacer. Ej.: "crear nota...", "abrir nota...", "buscar..."',
  );

  // Sesión
  final _Session _session = _Session();

  // Timers
  Timer? _autoCloseTimer;
  Timer? _idleTimer;

  // ========= Inicialización =========
  Future<void> init() async {
    if (_available) return;
    _available = await _stt.initialize();

    await _tts.setLanguage('es-ES');
    await _tts.setSpeechRate(0.71);
    await _tts.awaitSpeakCompletion(true);
  }

  // ========= Hablar / Callar =========
  Future<void> speak(String text) async {
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}
  }

  Future<void> stopTts() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  // ========= Overlay control =========
  Future<void> openOverlay(BuildContext context) async {
    await init();
    _session.clear();
    prompt.value =
        'Hola 👋 Soy tu asistente. Toca “Hablar” y dime qué hacer.\n'
        'Notas: "crear nota compras que diga pan", "abrir nota compras", "editar nota compras", '
        '"eliminar nota compras", "restaurar nota compras", "buscar recetas".\n'
        'Carpetas: "crear carpeta trabajo", "abrir carpeta clientes", '
        '"renombra la carpeta trabajo a clientes", "eliminar carpeta trabajo".\n'
        'Dentro/entre carpetas: "crear nota lista en la carpeta mercado que diga leche", '
        '"mover la nota compras a la carpeta mercado", "mover la nota compras a ninguna carpeta".\n'
        'Listados/navegación: "listar carpetas", "listar notas", "listar notas de la carpeta mercado", '
        '"ver eliminados". Papelera (UI): "vaciar eliminados", "restaurar todo".\n'
        'Voz: "leer la nota compras", "detener lectura". Preferencias: "activar confirmaciones", "desactivar confirmaciones".';

    _startIdleTimer(context);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => VoiceOverlay(assistant: this),
    );
  }

  void overlayBecameVisible(BuildContext context) {
    Future.microtask(() => speak(prompt.value));
  }

  void overlayDisposed() {
    _cancelAllTimers();
    isListening.value = false;
    liveText.value = '';
    stopTts();
    _session.clear();
  }

  // ========= Botones =========
  Future<void> onTapSpeak(BuildContext context) async {
    await stopTts();
    await beginListening(context);
  }

  Future<void> onTapStop() async {
    _cancelListenTimer();
    isListening.value = false;
    try {
      await _stt.stop();
    } catch (_) {}
    prompt.value = 'Escucha detenida. Toca “Hablar” para continuar.';
  }

  Future<void> onTapClose(BuildContext context) async {
    _cancelAllTimers();
    isListening.value = false;
    try {
      await _stt.stop();
    } catch (_) {}
    stopTts();
    _safePop(context);
  }

  // ========= Escucha =========
  Future<void> beginListening(BuildContext context) async {
    if (!_available) {
      await speak('No puedo usar el micrófono en este dispositivo.');
      return;
    }

    _cancelIdleTimer();
    isListening.value = true;
    liveText.value = '';

    _cancelListenTimer();
    _autoCloseTimer = Timer(const Duration(seconds: 60), () async {
      if (!isListening.value) return;
      isListening.value = false;
      try {
        await _stt.stop();
      } catch (_) {}
      prompt.value = 'No te escuché. Se cerrará.';
      _safePop(context);
      await speak('No escuché nada, cancelando.');
    });

    await _stt.listen(
      localeId: 'es_ES',
      listenMode: stt.ListenMode.dictation,
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 2),
      onResult: (r) async {
        liveText.value = r.recognizedWords;
        if (!r.finalResult) return;

        _cancelListenTimer();
        isListening.value = false;
        final text = liveText.value.trim();
        try {
          await _stt.stop();
        } catch (_) {}

        if (text.isEmpty) {
          prompt.value = 'No te escuché. Toca “Hablar” e inténtalo otra vez.';
          await speak('No te escuché. Toca “Hablar” e inténtalo otra vez.');
          return;
        }
        await _handle(context, text);
      },
    );
  }

  // ========= Helpers de normalización / parsing =========
  String _norm(String s) {
    s = s.toLowerCase().trim();
    const repl = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ü': 'u',
      'ñ': 'n',
    };
    repl.forEach((k, v) => s = s.replaceAll(k, v));
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    return s;
  }

  bool _hasAny(String s, List<String> needles) =>
      needles.any((n) => s.contains(n));

  bool _hasAnyWord(String s, List<String> words) => words.any(
    (w) => RegExp(r'(?:^|\s)' + RegExp.escape(w) + r'(?:\s|$)').hasMatch(s),
  );

  String? _firstQuoted(String s) {
    final m1 = RegExp(r'"(.+?)"').firstMatch(s);
    if (m1 != null) return m1.group(1);
    final m2 = RegExp(r"'(.+?)'").firstMatch(s);
    return m2?.group(1);
  }

  // ========== Limpieza de TÍTULOS y CONTENIDOS ==========
  String _stripTitle(String s) {
    var out = s.trim();
    out = out.replaceFirst(
      RegExp(r'^(la|una)\s+nota\s+', caseSensitive: false),
      '',
    );
    out = out.replaceFirst(RegExp(r'^(la|una)\s+', caseSensitive: false), '');
    out = out.replaceFirst(
      RegExp(
        r'^(llamada|titulada|de titulo|con titulo|que se llama)\s+',
        caseSensitive: false,
      ),
      '',
    );
    out = out.replaceAll(RegExp(r'\s+por favor\.?$', caseSensitive: false), '');
    out = out.replaceAll(RegExp(r'^[\s,:;\-]+'), '');
    out = out.replaceAll(RegExp(r'[\s,:.;\-]+$'), '');
    return out.trim();
  }

  String _stripContent(String s) {
    var out = s.trim();
    out = out.replaceAll(RegExp(r'\s+por favor\.?$', caseSensitive: false), '');
    out = out.replaceAll(RegExp(r'[.,]\s*$', caseSensitive: false), '');
    return out.trim();
  }

  String? _after(String lower, String key) {
    final i = lower.indexOf(key);
    if (i < 0) return null;
    var cut = lower.substring(i + key.length).trim();
    if (cut.isEmpty) return null;
    return cut;
  }

  String? _afterMany(String s, List<String> keys) {
    for (final k in keys) {
      final v = _after(s, k);
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  final List<String> _titleStops = const [
    ' que diga',
    ' con contenido',
    ' con texto',
    ',',
    '.',
    ';',
    ':',
  ];

  String? _afterUntil(String s, String key, List<String> stops) {
    final i = s.indexOf(key);
    if (i < 0) return null;
    var cut = s.substring(i + key.length).trim();
    if (cut.isEmpty) return null;
    var end = cut.length;
    for (final st in stops) {
      final j = cut.indexOf(st);
      if (j >= 0 && j < end) end = j;
    }
    return cut.substring(0, end).trim();
  }

  String? _afterManyUntil(String s, List<String> keys, List<String> stops) {
    for (final k in keys) {
      final v = _afterUntil(s, k, stops);
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  String? _extractTitleByNamePatterns(String lower) {
    return _afterManyUntil(lower, [
      'llamada ',
      'titulada ',
      'de titulo ',
      'con titulo ',
      'que se llama ',
    ], _titleStops);
  }

  // ======== Detectores de intención ========
  bool _mentionsNote(String s) =>
      s.contains('nota') || s.contains('archivo') || s.contains('apunte');

  bool _isOpenNoteIntent(String s) {
    return _hasAny(s, [
      'abrir',
      'abre',
      'abreme',
      'mostrar',
      'muestrame',
      'quiero ver',
      'ver',
      'ensename',
    ]) && _mentionsNote(s);
  }

  bool _isCreateNoteIntent(String s) {
    return (_hasAnyWord(s, [
              'crear',
              'crea',
              'nueva',
              'agregar',
              'agrega',
              'anota',
              'apunta',
              'toma nota',
            ]) &&
            _mentionsNote(s)) ||
        _hasAnyWord(s, ['anota', 'apunta']);
  }

  bool _isDeleteNoteIntent(String s) {
    final verbs = [
      'eliminar','elimina','elimine','borrar','borra','borre','quitar','quita','quite','remover','remueve'
    ];
    final movePhrases = [
      'enviar a eliminados',
      'mandar a eliminados',
      'enviar a la papelera',
      'mandar a la papelera',
      'mover a papelera',
      'mover a la papelera',
      'tirar a la papelera',
    ];
    return (_hasAnyWord(s, verbs) && _mentionsNote(s)) || _hasAny(s, movePhrases);
  }

  bool _isGenericDeleteIntent(String s) {
    final verbs = ['eliminar','elimina','elimine','borrar','borra','borre','quitar','quita','quite','remover','remueve','tirar'];
    if (!_hasAnyWord(s, verbs)) return false;
    final mentionsAny = _mentionsNote(s) || s.contains('carpeta') || s.contains('folder');
    return !mentionsAny; // dijo “elimina…” sin objeto claro
  }

  bool _isRestoreNoteIntent(String s) {
    final verbs = ['restaurar','restaura','recuperar','recupera','devolver','devuelve','reponer','repone'];
    final phrases = ['sacar de eliminados', 'saca de eliminados'];
    return (_hasAnyWord(s, verbs) && _mentionsNote(s)) || _hasAny(s, phrases);
  }

  bool _isEditNoteIntent(String s) {
    return _hasAnyWord(s, ['editar','edita','actualizar','actualiza','modificar','modifica','cambiar','cambia']) && _mentionsNote(s);
  }

  bool _isSearchIntent(String s) {
    return _hasAnyWord(s, ['buscar','busca','encuentra','encontrar','filtrar','filtra','listar','lista']);
  }

  // Carpetas
  bool _isCreateFolderIntent(String s) {
    return (_hasAnyWord(s, ['crear','crea','nueva','agregar','agrega']) && s.contains('carpeta'));
  }

  bool _isOpenFolderIntent(String s) {
    return _hasAny(s, ['abrir carpeta','abre carpeta','mostrar carpeta','ver carpeta']);
  }

  bool _isRenameFolderIntent(String s) {
    return _hasAny(s, [
      'renombrar carpeta',
      'renombra la carpeta',
      'cambiar nombre de la carpeta',
      'cambia el nombre de la carpeta',
      'editar carpeta',
      'edita la carpeta',
    ]);
  }

  bool _isDeleteFolderIntent(String s) {
    final verbs = ['eliminar','elimina','borrar','borra','quitar','quita','remover','remueve','tirar'];
    return _hasAnyWord(s, verbs) && s.contains('carpeta');
  }

  bool _isCreateNoteInFolderIntent(String s) {
    return _isCreateNoteIntent(s) && _hasAny(s, [
      'en la carpeta','dentro de la carpeta','en carpeta','dentro de carpeta'
    ]);
  }

  bool _isMoveNoteToFolderIntent(String s) {
    return _hasAny(s, ['mover la nota','mueve la nota','llevar la nota','lleva la nota']) &&
           _hasAny(s, ['a la carpeta','a carpeta']);
  }

  bool _isMoveNoteToRootIntent(String s) {
    return _hasAny(s, ['mover la nota','mueve la nota','llevar la nota','lleva la nota']) &&
           _hasAny(s, ['a ninguna carpeta','a la raiz','a raíz','a principal']);
  }

  // Listados / navegación
  bool _isListFoldersIntent(String s) {
    return _hasAny(s, ['listar carpetas','lista carpetas','ver carpetas','mostrar carpetas']);
  }
  bool _isListNotesIntent(String s) {
    return _hasAny(s, ['listar notas','lista notas','ver notas','mostrar notas']) && !s.contains('carpeta');
  }
  bool _isListNotesInFolderIntent(String s) {
    return _hasAny(s, ['listar notas de la carpeta','lista notas de la carpeta','notas de la carpeta']);
  }
  bool _isOpenDeletedIntent(String s) {
    return _hasAny(s, ['ver eliminados','mostrar eliminados','abrir eliminados','papelera']);
  }
  bool _isEmptyTrashIntent(String s) {
    return _hasAny(s, ['vaciar eliminados','vaciar papelera','vaciar la papelera']);
  }
  bool _isRestoreAllTrashIntent(String s) {
    return _hasAny(s, ['restaurar todo','restaurar todo de eliminados','restaurar todas las notas']);
  }

  // Voz y settings
  bool _isReadNoteIntent(String s) {
    return _hasAny(s, ['leer la nota','lee la nota','leer nota','lee nota']);
  }
  bool _isStopReadingIntent(String s) {
    return _hasAny(s, ['detener lectura','para la lectura','deten lectura','calla','silencio','deja de leer','stop']);
  }
  bool _isToggleConfirmOnIntent(String s) {
    return _hasAny(s, ['activar confirmaciones','activa confirmaciones','pide confirmacion','pide confirmación']);
  }
  bool _isToggleConfirmOffIntent(String s) {
    return _hasAny(s, ['desactivar confirmaciones','desactiva confirmaciones','no pidas confirmacion','no pidas confirmación']);
  }
  bool _isHelpIntent(String s) {
    return _hasAny(s, ['ayuda','que puedo decir','como funciona','comandos']);
  }

  // ======== Extractores de slots ========
  String? _extractOpenTitle(String raw, String lowerNorm) {
    final byName = _extractTitleByNamePatterns(lowerNorm);
    if (byName != null) return _stripTitle(byName);

    final quoted = _firstQuoted(raw);
    if (quoted != null) return _stripTitle(quoted);

    final keys = [
      'abrir la nota','abrir nota','abre la nota','abre nota',
      'quiero ver la nota','ver la nota','ver nota','mostrar la nota',
      'muestrame la nota','mostrar nota','ensename la nota',
      'nota','archivo','apunte',
    ];
    final found = _afterMany(lowerNorm, keys);
    return found == null ? null : _stripTitle(found);
  }

  ({String? title, String? content}) _extractCreate(String raw, String lower) {
    final both = RegExp(
      r'''^\s*(?:anota|apunta|toma\s+nota|crea(?:r)?(?:\s+la)?\s+(?:nota|archivo)|crear(?:\s+la)?\s+(?:nota|archivo)|crear|crea)\s+
          (?:"([^"]+)"|'([^']+)'|(.+?))\s*
          (?:[:,-]?\s*)?(?:que\s+diga|con\s+(?:contenido|texto))[:,-]?\s*
          (?:"([^"]+)"|'([^']+)'|(.+))\s*$''',
      multiLine: false,
      caseSensitive: false,
      dotAll: true,
    );
    final m = both.firstMatch(raw);
    if (m != null) {
      final t = (m.group(1) ?? m.group(2) ?? m.group(3) ?? '').trim();
      final c = (m.group(4) ?? m.group(5) ?? m.group(6) ?? '').trim();
      return (title: _stripTitle(t), content: _stripContent(c));
    }

    String? title = _extractTitleByNamePatterns(lower);
    title ??= _firstQuoted(raw);
    title ??= _afterMany(lower, [
      'crear la nota','crear nota','crea la nota','crea nota',
      'nueva nota','agregar nota','agrega nota',
      'crear el archivo','crear archivo','crea el archivo','crea archivo',
      'nueva archivo','agregar archivo','agrega archivo',
      'nota','archivo','apunte',
    ]);
    title ??= _afterMany(lower, ['anota','apunta','toma nota']);

    final contentQuoted = RegExp(
      r'''(contenido|texto|que\s+diga|dice)\s+["'](.+?)["']''',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(raw)?.group(2);
    String? content =
        contentQuoted ??
        _afterMany(lower, ['con contenido','con texto','que diga','dice']);

    if (title != null) title = _stripTitle(title);
    if (content != null) content = _stripContent(content);

    return (title: title, content: content);
  }

  String? _extractDeleteTitle(String raw, String lower) {
    final byName = _extractTitleByNamePatterns(lower);
    if (byName != null) return _stripTitle(byName);

    final quoted = _firstQuoted(raw);
    if (quoted != null) return _stripTitle(quoted);

    final keys = [
      'elimina la nota','eliminar la nota','eliminar nota','elimina nota',
      'borra la nota','borrar la nota','borra nota','borrar nota',
      'quita la nota','quitar la nota','quita nota','quitar nota',
      'elimina el archivo','borrar el archivo','archivo','apunte',
      'enviar a eliminados la nota','mandar a eliminados la nota',
      'enviar a eliminados','mandar a eliminados','enviar a la papelera',
      'mandar a la papelera','mover a papelera','mover a la papelera',
      'tirar a la papelera','nota',
    ];
    final found = _afterMany(lower, keys);
    return found == null ? null : _stripTitle(found);
  }

  String? _extractRestoreTitle(String raw, String lower) {
    final byName = _extractTitleByNamePatterns(lower);
    if (byName != null) return _stripTitle(byName);

    final quoted = _firstQuoted(raw);
    if (quoted != null) return _stripTitle(quoted);

    final keys = [
      'restaura la nota','restaurar la nota','restaurar nota','restaura nota',
      'recupera la nota','recuperar la nota','recupera nota','recuperar nota',
      'sacar de eliminados la nota','saca de eliminados la nota',
      'sacar de eliminados','saca de eliminados',
      'devuelve la nota','devolver la nota','devuelve nota','devolver nota',
      'reponer la nota','reponer nota','nota','archivo','apunte',
    ];
    final found = _afterMany(lower, keys);
    return found == null ? null : _stripTitle(found);
  }

  ({String? title, String? content}) _extractEdit(String raw, String lower) {
    final both = RegExp(
      r'''^\s*(?:edita|editar|actualiza|actualizar|modifica|modificar|cambia|cambiar)\s+(?:la\s+)?(?:nota|archivo)\s+
          (?:"([^"]+)"|'([^']+)'|(.+?))\s*
          (?:[:,-]?\s*)?(?:que\s+diga|con\s+(?:contenido|texto))[:,-]?\s*
          (?:"([^"]+)"|'([^']+)'|(.+))\s*$''',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(raw);

    if (both != null) {
      final t = (both.group(1) ?? both.group(2) ?? both.group(3) ?? '').trim();
      final c = (both.group(4) ?? both.group(5) ?? both.group(6) ?? '').trim();
      return (title: _stripTitle(t), content: _stripContent(c));
    }

    String? title =
        _extractTitleByNamePatterns(lower) ??
        _firstQuoted(raw) ??
        _afterMany(lower, [
          'edita la nota','editar la nota','editar nota','edita nota',
          'actualiza la nota','actualizar la nota','actualizar nota','actualiza nota',
          'modifica la nota','modificar la nota','modificar nota','modifica nota',
          'cambia la nota','cambiar la nota','cambiar nota','cambia nota',
          'edita el archivo','editar el archivo','archivo','apunte','nota',
        ]);

    String? content;
    final quoted = RegExp(
      r'''(?:con|a|y)\s+(?:nuevo\s+)?(?:contenido|texto|que\s+diga|dice)\s+["'](.+?)["']''',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(raw)?.group(1);

    content =
        quoted ??
        _afterMany(lower, [
          'con contenido','con texto','que diga','dice',
          'actualizar con','cambiar a','modificar a','pon el','ponle',
        ]);

    if (title != null) title = _stripTitle(title);
    if (content != null) content = _stripContent(content);

    return (title: title, content: content);
  }

  // Buscar
  String? _extractQuery(String raw, String lower) {
    final quoted = _firstQuoted(raw);
    if (quoted != null) return _stripContent(quoted.trim());

    final colon = RegExp(
      r'^(?:buscar|busca)\s*[:\-]\s*(.+)$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(raw);
    if (colon != null) {
      final q = colon.group(1)!.trim();
      if (q.isNotEmpty) return _stripContent(q);
    }

    final starters = [
      'buscar','busca','encuentra','encontrar','filtrar','filtra',
      'listar','lista','buscar sobre','buscar de','buscar por','buscar con',
      'notas que contengan','notas con',
    ];
    for (final k in starters) {
      if (lower.startsWith(k)) {
        final rest = lower.substring(k.length).trim();
        if (rest.isNotEmpty) return _stripContent(rest);
      }
    }
    final any = _afterMany(lower, starters);
    return any == null ? null : _stripContent(any);
  }

  // Carpetas
  String? _extractFolderName(String raw, String lower) {
    final q = _firstQuoted(raw);
    if (q != null) return _stripTitle(q);

    final m = RegExp(
      r'carpeta\s+([^\.,;:]+)$',
      caseSensitive: false,
    ).firstMatch(lower);
    if (m != null) return _stripTitle(m.group(1)!.trim());

    final m2 = RegExp(
      r'(?:en|dentro de)\s+la\s+carpeta\s+([^\.,;:]+)',
      caseSensitive: false,
    ).firstMatch(lower);
    if (m2 != null) return _stripTitle(m2.group(1)!.trim());

    final m3 = RegExp(
      r'de\s+la\s+carpeta\s+([^\.,;:]+)',
      caseSensitive: false,
    ).firstMatch(lower);
    if (m3 != null) return _stripTitle(m3.group(1)!.trim());

    return null;
  }

  ({String? from, String? to}) _extractFolderRename(String raw, String lower) {
    final r = RegExp(
      r'''(?:renombrar|renombra|cambiar nombre|cambia el nombre|editar|edita)\s+la\s+carpeta\s+(?:"([^"]+)"|'([^']+)'|([^\s]+))\s+a\s+(?:"([^"]+)"|'([^']+)'|(.+))''',
      caseSensitive: false,
    ).firstMatch(raw);
    if (r != null) {
      final from = (r.group(1) ?? r.group(2) ?? r.group(3) ?? '').trim();
      final to = (r.group(4) ?? r.group(5) ?? r.group(6) ?? '').trim();
      return (from: _stripTitle(from), to: _stripTitle(to));
    }

    final r2 = RegExp(
      r'''cambiar\s+nombre\s+de\s+la\s+carpeta\s+(?:"([^"]+)"|'([^']+)'|([^\s]+))\s+por\s+(?:"([^"]+)"|'([^']+)'|(.+))''',
      caseSensitive: false,
    ).firstMatch(raw);
    if (r2 != null) {
      final from = (r2.group(1) ?? r2.group(2) ?? r2.group(3) ?? '').trim();
      final to = (r2.group(4) ?? r2.group(5) ?? r2.group(6) ?? '').trim();
      return (from: _stripTitle(from), to: _stripTitle(to));
    }

    return (from: null, to: null);
  }

  ({String? note, String? folder}) _extractMoveNote(String raw, String lower) {
    final r = RegExp(
      r'''(?:mover|mueve|llevar|lleva)\s+la\s+nota\s+(?:"([^"]+)"|'([^']+)'|(.+?))\s+a\s+la\s+carpeta\s+(?:"([^"]+)"|'([^']+)'|(.+))$''',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(raw);

    if (r != null) {
      final note = (r.group(1) ?? r.group(2) ?? r.group(3) ?? '').trim();
      final folder = (r.group(4) ?? r.group(5) ?? r.group(6) ?? '').trim();
      return (note: _stripTitle(note), folder: _stripTitle(folder));
    }

    // si no vino la nota, al menos intentemos carpeta
    return (note: null, folder: _extractFolderName(raw, lower));
  }

  // ======== Confirmación ========
  bool _isAffirmative(String l) => _hasAnyWord(l, [
    'si','ok','okay','vale','claro','correcto','de acuerdo','confirmo','hazlo','adelante','dale','va',
  ]);

  bool _isNegative(String l) =>
      _hasAnyWord(l, ['no','cancelar','cancela','cancelalo','detener','deten','para','parar']) ||
      _hasAny(l, ['mejor no','no gracias']);

  bool _needConfirmNow() {
    if (!_confirmCreateEdit) return false;
    if (!(_session.intent == _Intent.createNote ||
        _session.intent == _Intent.editNote)) {
      return false;
    }
    final hasTitle = _session.title?.isNotEmpty == true;
    final hasContent = _session.content?.isNotEmpty == true;
    return hasTitle && hasContent;
  }

  Future<void> _askConfirmCurrent(BuildContext context) async {
    String action;
    if (_session.intent == _Intent.createNote) {
      action = 'crear la nota';
    } else if (_session.intent == _Intent.editNote) {
      action = 'actualizar la nota';
    } else if (_session.intent == _Intent.deleteNote) {
      action = 'enviar a Eliminados la nota';
    } else if (_session.intent == _Intent.deleteFolder) {
      action = 'eliminar la carpeta (sus notas irán a “Eliminados”)';
    } else {
      action = 'continuar';
    }

    final t = _session.title ?? _session.noteTitle ?? _session.folder ?? '';
    final c = _session.content ?? '';
    final extra = (c.isNotEmpty) ? '. Contenido: $c.' : '';
    final msg = (t.isNotEmpty)
        ? '¿Confirmo $action "$t"$extra? Di "sí" o "no".'
        : '¿Confirmo $action?$extra Di "sí" o "no".';
    _session.pendingSlot = 'confirm';
    prompt.value = msg;
    await speak(msg);
    _startIdleTimer(context);
  }

  // ======== Navegación / speech helper ========
  Future<void> _speakAndNavigate(
    BuildContext context, {
    required String message,
    required String route,
    Object? arguments,
    bool closeOverlay = true,
  }) async {
    prompt.value = message;
    await speak(message);
    if (closeOverlay) _safePop(context);
    _safePush(context, route, arguments: arguments);
    _session.clear();
  }

  List<String> _titleCandidates(String q) {
    final s = q.trim();
    final out = <String>{s};
    if (s.endsWith('r') && s.length > 1) {
      out.add('${s.substring(0, s.length - 1)}as'); // comprar -> compras
    }
    if (s.endsWith('s') && s.length > 1) {
      out.add(s.substring(0, s.length - 1)); // compras -> compra
    }
    return out.toList();
  }

  // ========= Diálogo: detección + slots =========
  Future<void> _handle(BuildContext context, String raw) async {
    final lower = _norm(raw);

    // Slots pendientes
    if (_session.pendingSlot != null) {
      await _fillPendingSlotAndProceed(context, raw, lower);
      return;
    }

    // Togglear confirmaciones
    if (_isToggleConfirmOnIntent(lower)) {
      _confirmCreateEdit = true;
      final m = 'Confirmaciones activadas.';
      prompt.value = m; await speak(m); return;
    }
    if (_isToggleConfirmOffIntent(lower)) {
      _confirmCreateEdit = false;
      final m = 'Confirmaciones desactivadas.';
      prompt.value = m; await speak(m); return;
    }

    // Detener lectura
    if (_isStopReadingIntent(lower)) {
      await stopTts();
      prompt.value = 'Lectura detenida.'; await speak('Listo.');
      return;
    }

    // Ayuda
    if (_isHelpIntent(lower)) {
      await speak(prompt.value);
      return;
    }

    // Desambiguación genérica de eliminar
    if (_isGenericDeleteIntent(lower)) {
      _session.intent = _Intent.genericDelete;
      _askFor(
        context,
        slot: 'targetType',
        text: '¿Qué deseas eliminar: una nota o una carpeta? Dímelo con su nombre después.',
      );
      return;
    }

    // ======== Notas ========
    if (_isOpenNoteIntent(lower) || (lower.startsWith('abre ') && _mentionsNote(lower))) {
      _session.intent = _Intent.openNote;
      _session.title = _extractOpenTitle(raw, lower);
      if (_session.title == null || _session.title!.isEmpty) {
        _askFor(context, slot: 'title', text: '¿Cómo se llama la nota (o archivo) que debo abrir?');
        return;
      }
      await _doOpen(context);
      return;
    }

    if (_isCreateNoteIntent(lower)) {
      _session.intent = _Intent.createNote;
      final res = _extractCreate(raw, lower);
      _session.title = res.title;
      _session.content = res.content;

      if ((_session.title == null || _session.title!.isEmpty) &&
          (_session.content == null || _session.content!.isEmpty)) {
        _askFor(context, slot: 'title', text: 'Vamos a crear la nota. ¿Qué título le pongo? Luego te pediré el contenido.');
        return;
      }
      if (_session.title == null || _session.title!.isEmpty) {
        _askFor(context, slot: 'title', text: '¿Qué título le pongo?');
        return;
      }
      if (_session.content == null || _session.content!.isEmpty) {
        _askFor(context, slot: 'content', text: '¿Qué contenido escribo?');
        return;
      }

      // Pregunta opcional carpeta
      if (!_session.askedFolderForCreate && (_session.folder == null)) {
        _session.askedFolderForCreate = true;
        _askFor(context, slot: 'folderOptional', text: '¿Quieres guardarla en alguna carpeta? Dime el nombre o di "ninguna".');
        return;
      }

      if (_needConfirmNow()) {
        await _askConfirmCurrent(context);
        return;
      }
      await _doCreate(context);
      return;
    }

    if (_isDeleteNoteIntent(lower)) {
      _session.intent = _Intent.deleteNote;
      _session.title = _extractDeleteTitle(raw, lower);
      if (_session.title == null || _session.title!.isEmpty) {
        _askFor(context, slot: 'title', text: '¿Qué nota o archivo debo eliminar?');
        return;
      }
      await _askConfirmCurrent(context);
      return;
    }

    if (_isRestoreNoteIntent(lower)) {
      _session.intent = _Intent.restoreNote;
      _session.title = _extractRestoreTitle(raw, lower);
      if (_session.title == null || _session.title!.isEmpty) {
        _askFor(context, slot: 'title', text: '¿Qué nota eliminada debo restaurar?');
        return;
      }
      await _doRestore(context);
      return;
    }

    if (_isEditNoteIntent(lower)) {
      _session.intent = _Intent.editNote;
      final res = _extractEdit(raw, lower);
      _session.title = res.title;
      _session.content = res.content;

      if (_session.title == null || _session.title!.isEmpty) {
        _askFor(context, slot: 'title', text: '¿Cuál es el título de la nota (o archivo) que debo editar?');
        return;
      }
      if (_session.content == null || _session.content!.isEmpty) {
        _askFor(context, slot: 'content', text: 'Dime el nuevo contenido.');
        return;
      }

      if (_needConfirmNow()) {
        await _askConfirmCurrent(context);
        return;
      }
      await _doEdit(context);
      return;
    }

    if (_isReadNoteIntent(lower)) {
      _session.intent = _Intent.readNoteAloud;
      _session.title = _extractOpenTitle(raw, lower) ?? _extractTitleByNamePatterns(lower);
      if (_session.title == null || _session.title!.isEmpty) {
        _askFor(context, slot: 'title', text: '¿Qué nota debo leer en voz alta?');
        return;
      }
      await _doReadNoteAloud(context);
      return;
    }

    if (_isSearchIntent(lower)) {
      _session.intent = _Intent.search;
      _session.query = _extractQuery(raw, lower);
      if (_session.query == null || _session.query!.trim().isEmpty) {
        _askFor(context, slot: 'query', text: '¿Qué quieres buscar?');
        return;
      }
      await _doSearch(context);
      return;
    }

    // ======== Carpetas ========
    if (_isCreateFolderIntent(lower)) {
      _session.intent = _Intent.createFolder;
      _session.folder = _extractFolderName(raw, lower);
      if (_session.folder == null || _session.folder!.isEmpty) {
        _askFor(context, slot: 'folder', text: 'Perfecto. Vamos a crear una carpeta. ¿Cómo se llamará la carpeta?');
        return;
      }
      await _doCreateFolder(context);
      return;
    }

    if (_isOpenFolderIntent(lower)) {
      _session.intent = _Intent.openFolder;
      _session.folder = _extractFolderName(raw, lower);
      if (_session.folder == null || _session.folder!.isEmpty) {
        _askFor(context, slot: 'folder', text: '¿Qué carpeta debo abrir?');
        return;
      }
      await _doOpenFolder(context);
      return;
    }

    if (_isRenameFolderIntent(lower)) {
      _session.intent = _Intent.renameFolder;
      final rn = _extractFolderRename(raw, lower);
      _session.folder = rn.from;
      _session.newFolder = rn.to;
      if (_session.folder == null || _session.folder!.isEmpty) {
        _askFor(context, slot: 'folder', text: '¿Cuál carpeta debo renombrar?');
        return;
      }
      if (_session.newFolder == null || _session.newFolder!.isEmpty) {
        _askFor(context, slot: 'newFolder', text: '¿Cuál será el nuevo nombre?');
        return;
      }
      await _doRenameFolder(context);
      return;
    }

    if (_isDeleteFolderIntent(lower)) {
      _session.intent = _Intent.deleteFolder;
      _session.folder = _extractFolderName(raw, lower);
      if (_session.folder == null || _session.folder!.isEmpty) {
        _askFor(context, slot: 'folder', text: '¿Qué carpeta debo eliminar?');
        return;
      }
      await _askConfirmCurrent(context);
      return;
    }

    // Notas dentro/entre carpetas
    if (_isCreateNoteInFolderIntent(lower)) {
      _session.intent = _Intent.createNoteInFolder;
      final res = _extractCreate(raw, lower);
      _session.title = res.title;
      _session.content = res.content;
      _session.folder = _extractFolderName(raw, lower);

      if (_session.title == null || _session.title!.isEmpty) {
        _askFor(context, slot: 'title', text: '¿Qué título tendrá la nota?');
        return;
      }
      if (_session.folder == null || _session.folder!.isEmpty) {
        _askFor(context, slot: 'folder', text: '¿En qué carpeta la creo?');
        return;
      }
      if (_session.content == null || _session.content!.isEmpty) {
        _askFor(context, slot: 'content', text: '¿Qué contenido escribo?');
        return;
      }
      await _doCreateNoteInFolder(context);
      return;
    }

    if (_isMoveNoteToFolderIntent(lower)) {
      _session.intent = _Intent.moveNoteToFolder;
      final mv = _extractMoveNote(raw, lower);
      _session.noteTitle = mv.note ?? _session.noteTitle;
      _session.folder = mv.folder ?? _session.folder;

      if (_session.noteTitle == null || _session.noteTitle!.isEmpty) {
        _askFor(context, slot: 'noteTitle', text: '¿Qué nota debo mover?');
        return;
      }
      if (_session.folder == null || _session.folder!.isEmpty) {
        _askFor(context, slot: 'folder', text: '¿A qué carpeta la muevo?');
        return;
      }
      await _doMoveNoteToFolder(context);
      return;
    }

    if (_isMoveNoteToRootIntent(lower)) {
      _session.intent = _Intent.moveNoteToRoot;
      // intenta extraer título
      _session.noteTitle = _firstQuoted(raw) ??
          _extractTitleByNamePatterns(lower) ??
          _afterMany(lower, ['mover la nota','mueve la nota','llevar la nota','lleva la nota']);
      if (_session.noteTitle == null || _session.noteTitle!.isEmpty) {
        _askFor(context, slot: 'noteTitle', text: '¿Qué nota debo mover a ninguna carpeta?');
        return;
      }
      await _doMoveNoteToRoot(context);
      return;
    }

    // Listados / navegación
    if (_isListFoldersIntent(lower)) {
      _session.intent = _Intent.listFolders;
      await _speakAndNavigate(context, message: 'Mostrando carpetas…', route: '/folders');
      return;
    }

    if (_isListNotesInFolderIntent(lower)) {
      _session.intent = _Intent.listNotesInFolder;
      _session.folder = _extractFolderName(raw, lower);
      if (_session.folder == null || _session.folder!.isEmpty) {
        _askFor(context, slot: 'folder', text: '¿De qué carpeta muestro las notas?');
        return;
      }
      await _speakAndNavigate(context, message: 'Mostrando notas de ${_session.folder}…', route: '/notes', arguments: {'folder': _session.folder});
      return;
    }

    if (_isListNotesIntent(lower)) {
      _session.intent = _Intent.listNotes;
      await _speakAndNavigate(context, message: 'Mostrando notas…', route: '/notes');
      return;
    }

    if (_isOpenDeletedIntent(lower)) {
      _session.intent = _Intent.openDeleted;
      await _speakAndNavigate(context, message: 'Abriendo Eliminados…', route: '/deleted');
      return;
    }

    if (_isEmptyTrashIntent(lower)) {
      _session.intent = _Intent.emptyTrash;
      await _speakAndNavigate(context, message: 'Abriendo Eliminados para vaciar…', route: '/deleted', arguments: {'action':'empty'});
      return;
    }

    if (_isRestoreAllTrashIntent(lower)) {
      _session.intent = _Intent.restoreAllTrash;
      await _speakAndNavigate(context, message: 'Abriendo Eliminados para restaurar todo…', route: '/deleted', arguments: {'action':'restoreAll'});
      return;
    }

    // Fallback
    final fb =
        'No entendí. Puedes decir: "abrir nota compras", '
        '"crear nota titulada compras con contenido pan", '
        '"editar nota compras que diga leche", '
        '"eliminar nota compras", "restaurar nota compras", "buscar recetas". '
        'Carpetas: "crear carpeta trabajo", "abrir carpeta clientes", '
        '"renombra la carpeta trabajo a clientes", "eliminar carpeta trabajo". '
        'Entre carpetas: "crear nota X en la carpeta Y", "mover la nota X a la carpeta Y", '
        '"mover la nota X a ninguna carpeta". '
        'Listados: "listar carpetas", "listar notas", "listar notas de la carpeta Y". '
        'Papelera: "ver eliminados", "vaciar eliminados", "restaurar todo". '
        'Voz: "leer la nota X", "detener lectura".';
    prompt.value = fb;
    await speak(fb);
  }

  Future<void> _fillPendingSlotAndProceed(
    BuildContext context,
    String raw,
    String lower,
  ) async {
    final slot = _session.pendingSlot!;
    _session.pendingSlot = null;

    switch (slot) {
      case 'title':
        _session.title = _firstQuoted(raw) ?? _stripTitle(raw.trim());
        if (_session.title == null || _session.title!.isEmpty) {
          _askFor(context, slot: 'title', text: 'No te entendí. Repite el título, por favor.');
          return;
        }
        break;
      case 'content':
        final quoted = _firstQuoted(raw);
        _session.content = _stripContent(quoted ?? raw.trim());
        if (_session.content == null || _session.content!.isEmpty) {
          _askFor(context, slot: 'content', text: 'No te entendí. Repite el contenido.');
          return;
        }
        break;
      case 'query':
        final q = _firstQuoted(raw) ?? raw.trim();
        _session.query = _stripContent(q);
        if (_session.query == null || _session.query!.isEmpty) {
          _askFor(context, slot: 'query', text: 'No te entendí. ¿Qué quieres buscar?');
          return;
        }
        break;
      case 'confirm':
        if (_isAffirmative(lower)) {
          if (_session.intent == _Intent.createNote) { await _doCreate(context); return; }
          if (_session.intent == _Intent.editNote)   { await _doEdit(context);   return; }
          if (_session.intent == _Intent.deleteNote) { await _doDelete(context); return; }
          if (_session.intent == _Intent.deleteFolder) { await _doDeleteFolder(context); return; }
          return;
        } else if (_isNegative(lower)) {
          final msg = 'Cancelado. Toca “Hablar” para indicarlo de nuevo.';
          prompt.value = msg; await speak(msg);
          _session.clear(); return;
        } else {
          _session.pendingSlot = 'confirm';
          final msg = '¿Confirmo? Di "sí" o "no".';
          prompt.value = msg; await speak(msg);
          _startIdleTimer(context); return;
        }
      case 'folder':
        _session.folder = _firstQuoted(raw) ?? _stripTitle(raw.trim());
        if (_session.folder == null || _session.folder!.isEmpty) {
          _askFor(context, slot: 'folder', text: 'No te entendí. ¿Cuál es el nombre de la carpeta?');
          return;
        }
        break;
      case 'newFolder':
        _session.newFolder = _firstQuoted(raw) ?? _stripTitle(raw.trim());
        if (_session.newFolder == null || _session.newFolder!.isEmpty) {
          _askFor(context, slot: 'newFolder', text: 'No te entendí. ¿Cuál es el nuevo nombre de la carpeta?');
          return;
        }
        break;
      case 'noteTitle':
        _session.noteTitle = _firstQuoted(raw) ?? _stripTitle(raw.trim());
        if (_session.noteTitle == null || _session.noteTitle!.isEmpty) {
          _askFor(context, slot: 'noteTitle', text: 'No te entendí. ¿Cuál es el título de la nota?');
          return;
        }
        break;
      case 'targetType':
        final txt = _norm(raw);
        if (txt.contains('carpeta')) {
          _session.targetType = 'carpeta';
          _session.intent = _Intent.deleteFolder;
          _askFor(context, slot: 'folder', text: '¿Cómo se llama la carpeta?');
          return;
        } else if (txt.contains('nota') || txt.contains('archivo') || txt.contains('apunte')) {
          _session.targetType = 'nota';
          _session.intent = _Intent.deleteNote;
          _askFor(context, slot: 'title', text: '¿Cómo se llama la nota o archivo?');
          return;
        } else {
          _session.pendingSlot = 'targetType';
          _askFor(context, slot: 'targetType', text: 'No te entendí. ¿Elimino una nota o una carpeta?');
          return;
        }
      case 'folderOptional':
        final ans = _norm(raw);
        if (ans.contains('ninguna') || _isNegative(ans)) {
          _session.folder = null;
        } else {
          _session.folder = _firstQuoted(raw) ?? _stripTitle(raw.trim());
        }
        if (_needConfirmNow()) {
          await _askConfirmCurrent(context);
          return;
        }
        await _doCreate(context);
        return;
    }

    // Completar flujos según intención
    if (_session.intent == _Intent.createFolder) {
      if (_session.folder == null || _session.folder!.isEmpty) {
        _askFor(context, slot: 'folder', text: '¿Cómo se llamará la carpeta?');
        return;
      }
      await _doCreateFolder(context);
      return;
    }

    if (_needConfirmNow()) {
      await _askConfirmCurrent(context);
      return;
    }

    if (_session.intent == _Intent.createNoteInFolder) {
      if (_session.title == null || _session.title!.isEmpty) {
        _askFor(context, slot: 'title', text: '¿Qué título le pongo a la nota?');
        return;
      }
      if (_session.folder == null || _session.folder!.isEmpty) {
        _askFor(context, slot: 'folder', text: '¿En qué carpeta la creo?');
        return;
      }
      if (_session.content == null || _session.content!.isEmpty) {
        _askFor(context, slot: 'content', text: '¿Qué contenido escribo?');
        return;
      }
      await _doCreateNoteInFolder(context);
      return;
    }

    if (_session.intent == _Intent.renameFolder) {
      if (_session.folder == null || _session.folder!.isEmpty) {
        _askFor(context, slot: 'folder', text: '¿Cuál carpeta debo renombrar?');
        return;
      }
      if (_session.newFolder == null || _session.newFolder!.isEmpty) {
        _askFor(context, slot: 'newFolder', text: '¿Cuál será el nuevo nombre?');
        return;
      }
      await _doRenameFolder(context);
      return;
    }

    if (_session.intent == _Intent.moveNoteToFolder) {
      if (_session.noteTitle == null || _session.noteTitle!.isEmpty) {
        _askFor(context, slot: 'noteTitle', text: '¿Qué nota debo mover?');
        return;
      }
      if (_session.folder == null || _session.folder!.isEmpty) {
        _askFor(context, slot: 'folder', text: '¿A qué carpeta la muevo?');
        return;
      }
      await _doMoveNoteToFolder(context);
      return;
    }

    if (_session.intent == _Intent.moveNoteToRoot) {
      if (_session.noteTitle == null || _session.noteTitle!.isEmpty) {
        _askFor(context, slot: 'noteTitle', text: '¿Qué nota debo mover a ninguna carpeta?');
        return;
      }
      await _doMoveNoteToRoot(context);
      return;
    }

    // Ejecutar pendientes simples
    switch (_session.intent) {
      case _Intent.openNote:        await _doOpen(context); break;
      case _Intent.createNote:
        if (_session.content == null || _session.content!.isEmpty) {
          _askFor(context, slot: 'content', text: 'Ahora dime el contenido.');
          return;
        }
        if (!_session.askedFolderForCreate && (_session.folder == null)) {
          _session.askedFolderForCreate = true;
          _askFor(context, slot: 'folderOptional', text: '¿Quieres guardarla en alguna carpeta? Dime el nombre o di "ninguna".');
          return;
        }
        await _doCreate(context);
        break;
      case _Intent.deleteNote:      await _askConfirmCurrent(context); break;
      case _Intent.deleteFolder:    await _askConfirmCurrent(context); break;
      case _Intent.restoreNote:     await _doRestore(context); break;
      case _Intent.editNote:
        if (_session.content == null || _session.content!.isEmpty) {
          _askFor(context, slot: 'content', text: 'Dime el nuevo contenido.');
          return;
        }
        await _doEdit(context); break;
      case _Intent.search:          await _doSearch(context); break;

      // navegación/listas (por si llegaron aquí)
      case _Intent.listFolders:     await _speakAndNavigate(context, message: 'Mostrando carpetas…', route: '/folders'); break;
      case _Intent.listNotes:       await _speakAndNavigate(context, message: 'Mostrando notas…', route: '/notes'); break;
      case _Intent.listNotesInFolder:
        if (_session.folder == null) {
          _askFor(context, slot: 'folder', text: '¿De qué carpeta muestro las notas?');
          return;
        }
        await _speakAndNavigate(context, message: 'Mostrando notas de ${_session.folder}…', route: '/notes', arguments: {'folder': _session.folder});
        break;
      case _Intent.openDeleted:     await _speakAndNavigate(context, message: 'Abriendo Eliminados…', route: '/deleted'); break;
      case _Intent.emptyTrash:      await _speakAndNavigate(context, message: 'Abriendo Eliminados para vaciar…', route: '/deleted', arguments: {'action':'empty'}); break;
      case _Intent.restoreAllTrash: await _speakAndNavigate(context, message: 'Abriendo Eliminados para restaurar todo…', route: '/deleted', arguments: {'action':'restoreAll'}); break;

      // varios
      case _Intent.readNoteAloud:
        if (_session.title == null || _session.title!.isEmpty) {
          _askFor(context, slot: 'title', text: '¿Qué nota debo leer?');
          return;
        }
        await _doReadNoteAloud(context);
        break;
      case _Intent.stopReading:     await stopTts(); break;
      case _Intent.toggleConfirmOn: case _Intent.toggleConfirmOff:
      case _Intent.createFolder: case _Intent.openFolder:
      case _Intent.renameFolder: case _Intent.createNoteInFolder:
      case _Intent.moveNoteToFolder: case _Intent.moveNoteToRoot:
      case _Intent.help: case _Intent.genericDelete: case _Intent.none:
        prompt.value = 'Toca “Hablar” y dime qué hacer.';
        await speak('Toca “Hablar” y dime qué hacer.');
        break;
    }
  }

  // ========= Acciones =========
  Future<void> _doOpen(BuildContext context) async {
    final q = _session.title!;
    dynamic n;
    for (final cand in _titleCandidates(q)) {
      n = await _repo.findByTitleContains(cand);
      if (n != null) break;
    }
    if (n == null) {
      final msg = 'No encontré la nota $q.';
      prompt.value = msg; await speak(msg);
      prompt.value = 'Toca “Hablar” para intentar con otro título.';
      await speak('¿Quieres intentar con otro título? Toca “Hablar”.');
    } else {
      final msg = 'Abriendo la nota $q…';
      await _speakAndNavigate(context, message: msg, route: '/note-detail', arguments: n.id);
    }
  }

  Future<void> _doCreate(BuildContext context) async {
    final args = <String, String>{};
    if (_session.title?.isNotEmpty == true)   args['title'] = _session.title!.trim();
    if (_session.content?.isNotEmpty == true) args['content'] = _session.content!.trim();
    if (_session.folder?.isNotEmpty == true)  args['folder'] = _session.folder!.trim();

    final msg = args['title'] != null
        ? 'Creando nota titulada ${args['title']}…'
        : 'Creando nueva nota…';

    await _speakAndNavigate(context, message: msg, route: '/new-note', arguments: args);
  }

  Future<void> _doDelete(BuildContext context) async {
    final q = _session.title!;
    dynamic n;
    for (final cand in _titleCandidates(q)) {
      n = await _repo.findByTitleContains(cand);
      if (n != null) break;
    }
    if (n == null) {
      final msg = 'No encontré la nota $q.';
      prompt.value = msg; await speak(msg);
      prompt.value = 'Toca “Hablar” para intentar con otro título.';
      await speak('¿Quieres intentar con otro título? Toca “Hablar”.');
      return;
    }

    final pre = 'Eliminando la nota $q…';
    prompt.value = pre; await speak(pre);

    await _repo.softDelete(n.id);

    final done = 'Listo. Nota $q enviada a Eliminados.';
    prompt.value = done; await speak(done);
    _session.clear();
  }

  String _normStr(String s) => s.toLowerCase().trim();

  Future<dynamic> _findFolderByName(String name) async {
    try {
      final all = await _folderRepo.watch().first;
      for (final f in all) {
        final fname = (f.name ?? '').toString();
        if (_normStr(fname) == _normStr(name)) return f;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _doDeleteFolder(BuildContext context) async {
    final name = (_session.folder ?? '').trim();
    if (name.isEmpty) {
      _askFor(context, slot: 'folder', text: '¿Qué carpeta debo eliminar?');
      return;
    }

    final folder = await _findFolderByName(name);
    if (folder == null) {
      final msg = 'No encontré la carpeta "$name".';
      prompt.value = msg; await speak(msg);
      _session.clear(); return;
    }

    final pre = 'Eliminando la carpeta "${folder.name}". Todas sus notas se moverán a "Eliminados".';
    prompt.value = pre; await speak(pre);

    await _folderRepo.deleteAndSoftDeleteNotes(folder.id);

    final done = 'Carpeta "${folder.name}" eliminada.';
    prompt.value = done; await speak(done);

    _safePop(context);
    _safePush(context, '/'); // vuelve al inicio/lista
    _session.clear();
  }

  Future<void> _doRestore(BuildContext context) async {
    final q = _session.title!;
    dynamic n;
    for (final cand in _titleCandidates(q)) {
      n = await _repo.findByTitleContains(cand, includeDeleted: true);
      if (n != null && (n.isDeleted == true)) break;
      n = null;
    }
    if (n == null) {
      final msg = 'No encontré una nota eliminada llamada $q.';
      prompt.value = msg; await speak(msg);
      prompt.value = 'Toca “Hablar” para intentar con otro título.';
      await speak('¿Quieres intentar con otro título? Toca “Hablar”.');
      return;
    }

    final pre = 'Restaurando la nota $q…';
    prompt.value = pre; await speak(pre);

    // Restaura a raíz
    await _repo.restoreToRoot(n.id);

    final done = 'Nota restaurada a Notas.';
    prompt.value = done; await speak(done);
    _session.clear();
  }

  Future<void> _doEdit(BuildContext context) async {
    final t = _session.title!;
    final c = _session.content!;
    dynamic n;
    for (final cand in _titleCandidates(t)) {
      n = await _repo.findByTitleContains(cand);
      if (n != null) break;
    }
    if (n == null) {
      final msg = 'No encontré la nota $t.';
      prompt.value = msg; await speak(msg);
      prompt.value = 'Toca “Hablar” para intentar con otro título.';
      await speak('¿Quieres intentar con otro título? Toca “Hablar”.');
      return;
    }

    final pre = 'Actualizando la nota $t…';
    prompt.value = pre; await speak(pre);

    await _repo.update(n.copyWith(content: c));

    final done = 'Contenido actualizado.';
    prompt.value = done; await speak(done);
    _session.clear();
  }

  Future<void> _doSearch(BuildContext context) async {
    final q = _session.query!;
    await _speakAndNavigate(context, message: 'Buscando "$q"…', route: '/search', arguments: {'query': q});
  }

  Future<void> _doCreateFolder(BuildContext context) async {
    final name = _session.folder?.trim();
    if (name == null || name.isEmpty) {
      _askFor(context, slot: 'folder', text: '¿Cómo se llamará la carpeta?');
      return;
    }
    await _speakAndNavigate(context, message: 'Creando carpeta "$name"…', route: '/new-folder', arguments: {'prefill': name, 'autoSave': true});
  }

  Future<void> _doOpenFolder(BuildContext context) async {
    final f = _session.folder!;
    await _speakAndNavigate(context, message: 'Abriendo carpeta $f…', route: '/notes', arguments: {'folder': f});
  }

  Future<void> _doRenameFolder(BuildContext context) async {
    final oldName = _session.folder!;
    final newName = _session.newFolder!;
    prompt.value = 'Renombrando carpeta $oldName a $newName…';
    await speak(prompt.value);
    _safePop(context);
    _safePush(context, '/notes', arguments: {'folderRenamedFrom': oldName, 'folderRenamedTo': newName});
    _session.clear();
  }

  Future<void> _doCreateNoteInFolder(BuildContext context) async {
    final args = <String, String>{
      if (_session.title?.isNotEmpty == true) 'title': _session.title!.trim(),
      if (_session.content?.isNotEmpty == true) 'content': _session.content!.trim(),
      if (_session.folder?.isNotEmpty == true) 'folder': _session.folder!.trim(),
    };
    final msg = 'Creando nota "${_session.title ?? '(sin título)'}" en la carpeta ${_session.folder}…';
    await _speakAndNavigate(context, message: msg, route: '/new-note', arguments: args);
  }

  Future<void> _doMoveNoteToFolder(BuildContext context) async {
    final n = _session.noteTitle!;
    final f = _session.folder!;
    final msg = 'Moviendo la nota "$n" a la carpeta $f…';
    prompt.value = msg; await speak(msg);
    _safePop(context);
    _safePush(context, '/notes', arguments: {'folder': f, 'movedNote': n});
    _session.clear();
  }

  Future<void> _doMoveNoteToRoot(BuildContext context) async {
    final n = _session.noteTitle!;
    final msg = 'Moviendo la nota "$n" a ninguna carpeta…';
    prompt.value = msg; await speak(msg);
    _safePop(context);
    _safePush(context, '/notes', arguments: {'folder': null, 'movedNote': n});
    _session.clear();
  }

  Future<void> _doReadNoteAloud(BuildContext context) async {
    final t = _session.title!;
    dynamic n;
    for (final cand in _titleCandidates(t)) {
      n = await _repo.findByTitleContains(cand);
      if (n != null) break;
    }
    if (n == null) {
      final msg = 'No encontré la nota $t para leerla.';
      prompt.value = msg; await speak(msg);
      return;
    }
    if ((n.content as String?)?.trim().isEmpty ?? true) {
      await speak('La nota "$t" no tiene contenido.');
      return;
    }
    await speak('Leyendo la nota "$t". ${n.content}');
  }

  // ========= Preguntar por un slot =========
  void _askFor(
    BuildContext context, {
    required String slot,
    required String text,
  }) {
    _session.pendingSlot = slot;
    prompt.value = '$text\nCuando estés listo, toca “Hablar”.';
    speak(text);
    _startIdleTimer(context);
  }

  // ========= Navegación segura =========
  void _safePop(BuildContext context) {
    try {
      Navigator.of(context, rootNavigator: true).pop();
    } catch (_) {}
  }

  void _safePush(BuildContext context, String route, {Object? arguments}) {
    Future.microtask(() {
      Navigator.of(context, rootNavigator: true).pushNamed(route, arguments: arguments);
    });
  }

  // ========= Timers =========
  void _startIdleTimer(BuildContext context) {
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(seconds: 30), () {
      if (!isListening.value) _safePop(context);
    });
  }

  void _cancelIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = null;
  }

  void _cancelListenTimer() {
    _autoCloseTimer?.cancel();
    _autoCloseTimer = null;
  }

  void _cancelAllTimers() {
    _cancelIdleTimer();
    _cancelListenTimer();
  }
}
