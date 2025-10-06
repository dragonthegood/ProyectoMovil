import 'package:shared_preferences/shared_preferences.dart';

/// Singleton para manejar SharedPreferences en toda la app.
class PreferencesService {
  // --- Singleton ---
  static final PreferencesService _instance = PreferencesService._internal();
  factory PreferencesService() => _instance;
  PreferencesService._internal();

  late SharedPreferences _prefs;

  // --- Claves ---
  static const _kEditMode = 'ui.editMode';
  static const _kLastSearchQuery = 'search.lastQuery';
  static const _kLastTabIndex = 'ui.lastTabIndex';
  static const _kRememberLastFolder = 'folders.rememberLast';
  static const _kLastFolderId = 'folders.lastFolderId';

  // Historial global de búsqueda
  static const _kSearchHistory = 'search.history';

  // TTS
  static const _kTtsRate = 'tts.rate';
  static const _kTtsPitch = 'tts.pitch';

  // Inicialización (llamar antes de runApp)
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // -------- Preferencias genéricas útiles --------
  bool getBool(String key, {bool defaultValue = false}) =>
      _prefs.getBool(key) ?? defaultValue;
  Future<void> setBool(String key, bool value) async =>
      _prefs.setBool(key, value);

  String? getString(String key) => _prefs.getString(key);
  Future<void> setString(String key, String? value) async {
    if (value == null) {
      await _prefs.remove(key);
    } else {
      await _prefs.setString(key, value);
    }
  }

  double getDouble(String key, {required double defaultValue}) =>
      _prefs.getDouble(key) ?? defaultValue;
  Future<void> setDouble(String key, double value) async =>
      _prefs.setDouble(key, value);

  int getInt(String key, {required int defaultValue}) =>
      _prefs.getInt(key) ?? defaultValue;
  Future<void> setInt(String key, int value) async => _prefs.setInt(key, value);

  // -------- Atajos específicos --------

  // Modo edición del Home
  bool get editMode => getBool(_kEditMode, defaultValue: false);
  Future<void> setEditMode(bool value) => setBool(_kEditMode, value);

  // Última búsqueda (texto actual)
  String? get lastSearchQuery => getString(_kLastSearchQuery);
  Future<void> setLastSearchQuery(String? q) => setString(_kLastSearchQuery, q);

  // Última pestaña seleccionada
  int get lastTabIndex => getInt(_kLastTabIndex, defaultValue: 0);
  Future<void> setLastTabIndex(int i) => setInt(_kLastTabIndex, i);

  // Recordar última carpeta
  bool get rememberLastFolder =>
      getBool(_kRememberLastFolder, defaultValue: false);
  Future<void> setRememberLastFolder(bool v) =>
      setBool(_kRememberLastFolder, v);

  String? get lastFolderId => getString(_kLastFolderId);
  Future<void> setLastFolderId(String? id) => setString(_kLastFolderId, id);

  // TTS
  double get ttsRate => getDouble(_kTtsRate, defaultValue: 1.0); // 0.5–1.5
  Future<void> setTtsRate(double v) => setDouble(_kTtsRate, v);

  double get ttsPitch => getDouble(_kTtsPitch, defaultValue: 1.0); // 0.5–2.0
  Future<void> setTtsPitch(double v) => setDouble(_kTtsPitch, v);

  // -------- List<String> --------
  List<String> getStringList(String key) =>
      _prefs.getStringList(key) ?? <String>[];

  Future<void> setStringList(String key, List<String> value) async {
    if (value.isEmpty) {
      await _prefs.remove(key);
    } else {
      await _prefs.setStringList(key, value);
    }
  }

  // --- List<String> con migración segura (String -> List<String>) ---
  List<String> getStringListCompat(String key) {
    try {
      final raw = _prefs.get(key); // puede ser List, String o null
      if (raw is List<String>) return raw;
      if (raw is List) {
        return raw.map((e) => e.toString()).toList();
      }
      if (raw is String) {
        // Migrar de string (separado por \n) a lista
        final list = raw
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        _prefs.remove(key);
        _prefs.setStringList(key, list);
        return list;
      }
    } catch (_) {
      // si algo falla devolvemos lista vacía
    }
    return <String>[];
  }

  /// Guarda una lista de strings. Borra cualquier valor previo de otro tipo.
  Future<void> setStringListSafe(String key, List<String> value) async {
    await _prefs.remove(key); // evita choque de tipos
    if (value.isEmpty) return;
    await _prefs.setStringList(key, value);
  }

  // -------- Helpers del historial de búsqueda --------
  List<String> get searchHistory => getStringListCompat(_kSearchHistory);
  Future<void> setSearchHistory(List<String> v) =>
      setStringListSafe(_kSearchHistory, v);
  Future<void> clearSearchHistory() => setStringListSafe(_kSearchHistory, []);
}
