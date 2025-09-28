import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import '../data/repositories/note_repository.dart';
import '../widgets/voice_overlay.dart';

/// Intenciones soportadas
enum _Intent {
  none,
  openNote,
  createNote,
  deleteNote,
  restoreNote,
  editNote,
  search,
}

/// Estado de la conversación (slots)
class _Session {
  _Intent intent = _Intent.none;
  String? title;
  String? content;
  String? query;
  String? pendingSlot; // 'title', 'content', 'query', 'confirm'
  void clear() {
    intent = _Intent.none;
    title = null;
    content = null;
    query = null;
    pendingSlot = null;
  }
}

class VoiceAssistant {
  VoiceAssistant._();
  static final VoiceAssistant I = VoiceAssistant._();

  final stt.SpeechToText _stt = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final _repo = NoteRepository();

  bool _available = false;

  // ===== Config =====
  bool _confirmCreateEdit = true;

  // ===== Estado expuesto al overlay =====
  final ValueNotifier<bool> isListening = ValueNotifier(false);
  final ValueNotifier<String> liveText = ValueNotifier('');
  final ValueNotifier<String> prompt = ValueNotifier(
    'Toca “Hablar” y dime qué hacer. Ej.: "crear nota...", "abrir nota...", "buscar..."',
  );

  // Sesión de diálogo
  final _Session _session = _Session();

  // Timers
  Timer? _autoCloseTimer;
  Timer? _idleTimer;

  // ========= Inicialización =========
  Future<void> init() async {
    if (_available) return;
    _available = await _stt.initialize();

    await _tts.setLanguage('es-ES');
    await _tts.setSpeechRate(0.9);
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
    try { await _tts.stop(); } catch (_) {}
  }

  // ========= Overlay control =========
  Future<void> openOverlay(BuildContext context) async {
    await init();
    _session.clear();
    prompt.value =
        'Hola 👋 Soy tu asistente. Toca “Hablar” y dime qué hacer.\n'
        'Por ejemplo: "crear nota titulada compras con contenido pan", '
        '"abrir nota compras", "buscar recetas", "eliminar nota compras".';

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
    try { await _stt.stop(); } catch (_) {}
    prompt.value = 'Escucha detenida. Toca “Hablar” para continuar.';
  }

  Future<void> onTapClose(BuildContext context) async {
    _cancelAllTimers();
    isListening.value = false;
    try { await _stt.stop(); } catch (_) {}
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
      try { await _stt.stop(); } catch (_) {}
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
        try { await _stt.stop(); } catch (_) {}

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
    const repl = {'á':'a','é':'e','í':'i','ó':'o','ú':'u','ü':'u','ñ':'n'};
    repl.forEach((k, v) => s = s.replaceAll(k, v));
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    return s;
  }

  bool _hasAny(String s, List<String> needles) =>
      needles.any((n) => s.contains(n));

  bool _hasAnyWord(String s, List<String> words) =>
      words.any((w) => RegExp(r'(?:^|\s)'+RegExp.escape(w)+r'(?:\s|$)').hasMatch(s));

  String? _firstQuoted(String s) {
    final m1 = RegExp(r'"(.+?)"').firstMatch(s);
    if (m1 != null) return m1.group(1);
    final m2 = RegExp(r"'(.+?)'").firstMatch(s);
    return m2?.group(1);
  }

  // Recorte para TÍTULOS (no corta por " y " ahora) // CHANGED
  String _stripTitle(String s) {
    final cuts = [
      ' con ', ' que ', ' donde ', ' a ', ' para ', ' por ',
      ' del ', ' de ', '.', ',', ' por favor'
    ];
    var out = s;
    for (final c in cuts) {
      final i = out.indexOf(c);
      if (i > 0) out = out.substring(0, i).trim();
    }
    return out;
  }

  // Recorte para CONTENIDOS (conserva “y”, “con”, etc.)
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

  // NEW: como _after, pero corta solo cuando aparece alguno de los "stops"
  String? _afterUntil(String s, String key, List<String> stops) { // NEW
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

  String? _afterManyUntil(String s, List<String> keys, List<String> stops) { // NEW
    for (final k in keys) {
      final v = _afterUntil(s, k, stops);
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  // ======== Detectores de intención ========
  bool _isOpenNoteIntent(String s) =>
      _hasAny(s, ['abrir','abre','abreme','mostrar','muestrame','quiero ver','ver','ensename']) && s.contains('nota');

  bool _isCreateNoteIntent(String s) =>
      (_hasAnyWord(s, ['crear','crea','nueva','agregar','agrega','anota','apunta','toma nota']) && s.contains('nota'))
      || _hasAnyWord(s, ['anota','apunta']);

  bool _isDeleteNoteIntent(String s) {
    final verbs = ['eliminar','elimina','elimine','borrar','borra','borre','quitar','quita','quite'];
    final movePhrases = ['enviar a eliminados','mandar a eliminados','enviar a la papelera','mandar a la papelera','mover a papelera','mover a la papelera','tirar a la papelera'];
    return (_hasAnyWord(s, verbs) && s.contains('nota')) || _hasAny(s, movePhrases);
  }

  bool _isRestoreNoteIntent(String s) {
    final verbs = ['restaurar','restaura','recuperar','recupera','devolver','devuelve','reponer','repone'];
    final phrases = ['sacar de eliminados','saca de eliminados'];
    return (_hasAnyWord(s, verbs) && s.contains('nota')) || _hasAny(s, phrases);
  }

  bool _isEditNoteIntent(String s) =>
      _hasAnyWord(s, ['editar','edita','actualizar','actualiza','modificar','modifica','cambiar','cambia']) && s.contains('nota');

  bool _isSearchIntent(String s) =>
      _hasAnyWord(s, ['buscar','busca','encuentra','encontrar','filtrar','filtra','listar','lista']);

  // ======== Extractores ========

  // Abrir
  String? _extractOpenTitle(String raw, String lowerNorm) {
    final quoted = _firstQuoted(raw);
    if (quoted != null) return quoted.trim();

    final keys = [
      'abrir la nota llamada','abrir la nota titulada','abrir la nota que se llama',
      'abrir la nota','abrir nota llamada','abrir nota titulada','abrir nota que se llama',
      'abrir nota','abre la nota llamada','abre la nota','abre nota',
      'quiero ver la nota','ver la nota','ver nota',
      'mostrar la nota','muestrame la nota','mostrar nota','ensename la nota',
      'abrir las notas','abrir notas','ver notas','mostrar notas',
      'nota llamada','nota titulada','nota que se llama','la nota','nota'
    ];
    final found = _afterMany(lowerNorm, keys);
    if (found == null) return null;
    return _stripTitle(found);
  }

  // Crear (fuerte): “anota X que diga Y”, “crear nota X con contenido Y”
  ({String? title, String? content}) _extractCreate(String raw, String lower) {
    // 1) título + contenido en una sola frase
    final both = RegExp(
      r'''^\s*(?:anota|apunta|toma\s+nota|crea(?:r)?(?:\s+la)?\s+nota|crear(?:\s+la)?\s+nota|crear|crea)\s+
          (?:"([^"]+)"|'([^']+)'|(.+?))\s*
          (?:[:,-]?\s*)?(?:que\s+diga|con\s+(?:contenido|texto))[:,-]?\s*
          (?:"([^"]+)"|'([^']+)'|(.+))\s*$''',
      multiLine: false, caseSensitive: false, dotAll: true,
    );
    final m = both.firstMatch(raw);
    if (m != null) {
      final t = (m.group(1) ?? m.group(2) ?? m.group(3) ?? '').trim();
      final c = (m.group(4) ?? m.group(5) ?? m.group(6) ?? '').trim();
      return (title: _stripTitle(t), content: _stripContent(c));
    }

    // 2) SOLO TÍTULO con claves tipo "de/con título", "titulada", "llamada"  // NEW
    String? title = _afterManyUntil(
      lower,
      ['de titulo','con titulo','titulada','llamada','que se llama'],
      [' que diga',' con contenido',' con texto']
    );
    String? content;

    // 3) Título entre comillas si no se encontró
    title ??= _firstQuoted(raw);

    // 4) Título tras otras claves estándar
    title ??= _afterMany(lower, [
      'crear la nota llamada','crear la nota titulada','crear la nota que se llama',
      'crear nota llamada','crear nota titulada','crear nota que se llama',
      'crear nota','crea la nota','crea nota','nueva nota','agregar nota','agrega nota',
      'la nota llamada','la nota titulada','nota llamada','nota titulada',
      'nota que se llama','la nota','nota','crear','crea'
    ]);

    // 5) “anota X”, “apunta X”, “toma nota X”
    title ??= _afterMany(lower, ['anota','apunta','toma nota']);

    // 6) Contenido (si viene)
    final contentQuoted = RegExp(
      r'''(contenido|texto|que\s+diga|dice)\s+["'](.+?)["']''',
      caseSensitive: false, dotAll: true,
    ).firstMatch(raw)?.group(2);
    content = contentQuoted ?? _afterMany(lower, ['con contenido','con texto','que diga','dice']);

    if (title != null) title = _stripTitle(title);
    if (content != null) content = _stripContent(content);

    return (title: title, content: content);
  }

  // Eliminar
  String? _extractDeleteTitle(String raw, String lower) {
    final quoted = _firstQuoted(raw);
    if (quoted != null) return quoted.trim();

    final keys = [
      'elimina la nota','eliminar la nota','eliminar nota','elimina nota',
      'borra la nota','borrar la nota','borra nota','borrar nota',
      'quita la nota','quitar la nota','quita nota','quitar nota',
      'enviar a eliminados la nota','mandar a eliminados la nota',
      'enviar a eliminados','mandar a eliminados',
      'enviar a la papelera','mandar a la papelera','mover a papelera','mover a la papelera','tirar a la papelera',
      'la nota','nota'
    ];
    final found = _afterMany(lower, keys);
    return found == null ? null : _stripTitle(found);
  }

  // Restaurar
  String? _extractRestoreTitle(String raw, String lower) {
    final quoted = _firstQuoted(raw);
    if (quoted != null) return quoted.trim();

    final keys = [
      'restaura la nota','restaurar la nota','restaurar nota','restaura nota',
      'recupera la nota','recuperar la nota','recupera nota','recuperar nota',
      'sacar de eliminados la nota','saca de eliminados la nota',
      'sacar de eliminados','saca de eliminados',
      'devuelve la nota','devolver la nota','devuelve nota','devolver nota',
      'reponer la nota','reponer nota','la nota','nota'
    ];
    final found = _afterMany(lower, keys);
    return found == null ? null : _stripTitle(found);
  }

  // Editar (acepta “que diga …” para contenido)
  ({String? title, String? content}) _extractEdit(String raw, String lower) {
    final both = RegExp(
      r'''^\s*(?:edita|editar|actualiza|actualizar|modifica|modificar|cambia|cambiar)\s+(?:la\s+)?nota\s+
          (?:"([^"]+)"|'([^']+)'|(.+?))\s*
          (?:[:,-]?\s*)?(?:que\s+diga|con\s+(?:contenido|texto))[:,-]?\s*
          (?:"([^"]+)"|'([^']+)'|(.+))\s*$''',
      caseSensitive: false, dotAll: true,
    ).firstMatch(raw);

    if (both != null) {
      final t = (both.group(1) ?? both.group(2) ?? both.group(3) ?? '').trim();
      final c = (both.group(4) ?? both.group(5) ?? both.group(6) ?? '').trim();
      return (title: _stripTitle(t), content: _stripContent(c));
    }

    String? title = _firstQuoted(raw) ?? _afterMany(lower, [
      'edita la nota','editar la nota','editar nota','edita nota',
      'actualiza la nota','actualizar la nota','actualizar nota','actualiza nota',
      'modifica la nota','modificar la nota','modificar nota','modifica nota',
      'cambia la nota','cambiar la nota','cambiar nota','cambia nota',
      'la nota','nota'
    ]);

    String? content;
    final quoted = RegExp(
      r'''(?:con|a|y)\s+(?:nuevo\s+)?(?:contenido|texto|que\s+diga|dice)\s+["'](.+?)["']''',
      caseSensitive: false, dotAll: true,
    ).firstMatch(raw)?.group(1);

    content = quoted ?? _afterMany(lower, [
      'con contenido','con texto','que diga','dice',
      'actualizar con','cambiar a','modificar a','pon el','ponle'
    ]);

    if (title != null) title = _stripTitle(title);
    if (content != null) content = _stripContent(content);

    return (title: title, content: content);
  }

  // Buscar
  String? _extractQuery(String raw, String lower) {
    final quoted = _firstQuoted(raw);
    if (quoted != null) return _stripContent(quoted.trim());

    final colon = RegExp(r'^(?:buscar|busca)\s*[:\-]\s*(.+)$', caseSensitive: false, dotAll: true).firstMatch(raw);
    if (colon != null) {
      final q = colon.group(1)!.trim();
      if (q.isNotEmpty) return _stripContent(q);
    }

    final starters = [
      'buscar','busca','encuentra','encontrar','filtrar','filtra','listar','lista',
      'buscar sobre','buscar de','buscar por','buscar con',
      'notas que contengan','notas con'
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

  // ======== Confirmación ========
  bool _isAffirmative(String l) =>
      _hasAnyWord(l, ['si','ok','okay','vale','claro','correcto','de acuerdo','confirmo','hazlo','adelante','dale','va']);
  bool _isNegative(String l) =>
      _hasAnyWord(l, ['no','cancelar','cancela','cancelalo','detener','deten','para','parar']) || _hasAny(l, ['mejor no','no gracias']);

  bool _needConfirmNow() {
    if (!_confirmCreateEdit) return false;
    if (!(_session.intent == _Intent.createNote || _session.intent == _Intent.editNote)) return false;
    final hasTitle = _session.title?.isNotEmpty == true;
    final hasContent = _session.content?.isNotEmpty == true;
    return hasTitle && hasContent;
  }

  Future<void> _askConfirmCurrent(BuildContext context) async {
    final isCreate = _session.intent == _Intent.createNote;
    final action = isCreate ? 'crear la nota' : 'actualizar la nota';
    final t = _session.title ?? '(sin título)';
    final c = _session.content ?? '(sin contenido)';
    final msg = 'Título: $t. Contenido: $c. ¿Confirmo $action? Di "sí" o "no".';
    _session.pendingSlot = 'confirm';
    prompt.value = msg;
    await speak(msg);
    _startIdleTimer(context);
  }

  // ======== Navegación helper ========
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
    if (s.endsWith('r') && s.length > 1) out.add('${s.substring(0, s.length - 1)}as'); // comprar -> compras
    if (s.endsWith('s') && s.length > 1) out.add(s.substring(0, s.length - 1)); // compras -> compra
    return out.toList();
  }

  // ========= Diálogo =========
  Future<void> _handle(BuildContext context, String raw) async {
    final lower = _norm(raw);

    if (_session.pendingSlot != null) {
      await _fillPendingSlotAndProceed(context, raw, lower);
      return;
    }

    // Abrir
    if (_isOpenNoteIntent(lower) || (lower.startsWith('abre ') && lower.contains('nota'))) {
      _session.intent = _Intent.openNote;
      _session.title = _extractOpenTitle(raw, lower);
      if (_session.title == null || _session.title!.isEmpty) {
        _askFor(context, slot: 'title', text: '¿Cómo se llama la nota que debo abrir?');
        return;
      }
      await _doOpen(context); return;
    }

    // Crear
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
        _askFor(context, slot: 'title', text: '¿Qué título le pongo?'); return;
      }
      if (_session.content == null || _session.content!.isEmpty) {
        _askFor(context, slot: 'content', text: '¿Qué contenido escribo?'); return;
      }

      if (_needConfirmNow()) { await _askConfirmCurrent(context); return; }
      await _doCreate(context); return;
    }

    // Eliminar
    if (_isDeleteNoteIntent(lower)) {
      _session.intent = _Intent.deleteNote;
      _session.title = _extractDeleteTitle(raw, lower);
      if (_session.title == null || _session.title!.isEmpty) {
        _askFor(context, slot: 'title', text: '¿Qué nota debo eliminar?'); return;
      }
      await _doDelete(context); return;
    }

    // Restaurar
    if (_isRestoreNoteIntent(lower)) {
      _session.intent = _Intent.restoreNote;
      _session.title = _extractRestoreTitle(raw, lower);
      if (_session.title == null || _session.title!.isEmpty) {
        _askFor(context, slot: 'title', text: '¿Qué nota eliminada debo restaurar?'); return;
      }
      await _doRestore(context); return;
    }

    // Editar
    if (_isEditNoteIntent(lower)) {
      _session.intent = _Intent.editNote;
      final res = _extractEdit(raw, lower);
      _session.title = res.title;
      _session.content = res.content;

      if (_session.title == null || _session.title!.isEmpty) {
        _askFor(context, slot: 'title', text: '¿Cuál es el título de la nota que debo editar?'); return;
      }
      if (_session.content == null || _session.content!.isEmpty) {
        _askFor(context, slot: 'content', text: 'Dime el nuevo contenido.'); return;
      }

      if (_needConfirmNow()) { await _askConfirmCurrent(context); return; }
      await _doEdit(context); return;
    }

    // Buscar
    if (_isSearchIntent(lower)) {
      _session.intent = _Intent.search;
      _session.query = _extractQuery(raw, lower);
      if (_session.query == null || _session.query!.trim().isEmpty) {
        _askFor(context, slot: 'query', text: '¿Qué quieres buscar?'); return;
      }
      await _doSearch(context); return;
    }

    // Navegación directa
    if (_hasAny(lower, ['ver eliminados','mostrar eliminados','abrir eliminados'])) {
      await _speakAndNavigate(context, message: 'Abriendo eliminados…', route: '/deleted'); return;
    }
    if (_hasAny(lower, ['ver notas','abrir notas','mostrar notas'])) {
      await _speakAndNavigate(context, message: 'Abriendo notas…', route: '/notes'); return;
    }

    // Fallback
    final fb = 'No entendí. Puedes decir: "abrir nota compras", '
        '"crear nota titulada compras con contenido pan", '
        '"editar nota compras que diga leche", '
        '"eliminar nota compras", "restaurar nota compras", "buscar recetas".';
    prompt.value = fb;
    await speak(fb);
  }

  Future<void> _fillPendingSlotAndProceed(BuildContext context, String raw, String lower) async {
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
        final l = lower;
        if (_isAffirmative(l)) {
          if (_session.intent == _Intent.createNote) { await _doCreate(context); return; }
          if (_session.intent == _Intent.editNote)   { await _doEdit(context);   return; }
          return;
        } else if (_isNegative(l)) {
          final msg = 'Cancelado. Toca “Hablar” para dictarlo de nuevo.';
          prompt.value = msg;
          await speak(msg);
          _session.clear();
          return;
        } else {
          _session.pendingSlot = 'confirm';
          final msg = '¿Confirmo? Di "sí" o "no".';
          prompt.value = msg;
          await speak(msg);
          _startIdleTimer(context);
          return;
        }
    }

    if (_needConfirmNow()) { await _askConfirmCurrent(context); return; }

    switch (_session.intent) {
      case _Intent.openNote:   await _doOpen(context); break;
      case _Intent.createNote:
        if (_session.content == null || _session.content!.isEmpty) {
          _askFor(context, slot: 'content', text: 'Ahora dime el contenido.'); return;
        }
        await _doCreate(context); break;
      case _Intent.deleteNote: await _doDelete(context); break;
      case _Intent.restoreNote:await _doRestore(context); break;
      case _Intent.editNote:
        if (_session.content == null || _session.content!.isEmpty) {
          _askFor(context, slot: 'content', text: 'Dime el nuevo contenido.'); return;
        }
        await _doEdit(context); break;
      case _Intent.search:     await _doSearch(context); break;
      case _Intent.none:
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
      prompt.value = msg;
      await speak(msg);
      prompt.value = 'Toca “Hablar” para intentar con otro título.';
      await speak('¿Quieres intentar con otro título? Toca “Hablar”.');
      return;
    }
    final msg = 'Abriendo la nota $q…';
    await _speakAndNavigate(context, message: msg, route: '/note-detail', arguments: n.id);
  }

  Future<void> _doCreate(BuildContext context) async {
    final args = <String, String>{};
    if (_session.title?.isNotEmpty == true) args['title'] = _session.title!.trim();
    if (_session.content?.isNotEmpty == true) args['content'] = _session.content!.trim();

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
      prompt.value = msg;
      await speak(msg);
      prompt.value = 'Toca “Hablar” para intentar con otro título.';
      await speak('¿Quieres intentar con otro título? Toca “Hablar”.');
      return;
    }

    final pre = 'Entendido. Eliminando la nota $q…';
    prompt.value = pre;
    await speak(pre);

    await _repo.softDelete(n.id);

    final done = 'Listo. Nota $q enviada a eliminados.';
    prompt.value = done;
    await speak(done);
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
      prompt.value = msg;
      await speak(msg);
      prompt.value = 'Toca “Hablar” para intentar con otro título.';
      await speak('¿Quieres intentar con otro título? Toca “Hablar”.');
      return;
    }

    final pre = 'Restaurando la nota $q…';
    prompt.value = pre;
    await speak(pre);

    await _repo.restore(n.id);

    final done = 'Nota restaurada.';
    prompt.value = done;
    await speak(done);
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
      prompt.value = msg;
      await speak(msg);
      prompt.value = 'Toca “Hablar” para intentar con otro título.';
      await speak('¿Quieres intentar con otro título? Toca “Hablar”.');
      return;
    }

    final pre = 'Actualizando la nota $t…';
    prompt.value = pre;
    await speak(pre);

    await _repo.update(n.copyWith(content: c));

    final done = 'Contenido actualizado.';
    prompt.value = done;
    await speak(done);
    _session.clear();
  }

  Future<void> _doSearch(BuildContext context) async {
    final q = _session.query!;
    await _speakAndNavigate(context, message: 'Buscando "$q"…', route: '/search', arguments: {'query': q});
  }

  // ========= Preguntar por un slot =========
  void _askFor(BuildContext context, {required String slot, required String text}) {
    _session.pendingSlot = slot;
    prompt.value = '$text\nCuando estés listo, toca “Hablar”.';
    speak(text);
    _startIdleTimer(context);
  }

  // ========= Navegación segura =========
  void _safePop(BuildContext context) {
    try { Navigator.of(context, rootNavigator: true).pop(); } catch (_) {}
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
