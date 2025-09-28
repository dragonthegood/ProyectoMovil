# Actualización: Firebase + Firestore + Asistente de Voz

Este paquete contiene los **archivos nuevos y reemplazos** para conectar tu app de notas con **Firebase (Auth anónimo + Firestore)** y añadir un **asistente de voz** (STT/TTS) que navega por comandos.

> **Importante:** Haz copia de seguridad de tu proyecto antes de reemplazar archivos.

---

## 1) Instalar dependencias (VSCode terminal)
```bash
flutter pub add firebase_core firebase_auth cloud_firestore
flutter pub add speech_to_text flutter_tts permission_handler
```

> Si aún no corriste `flutterfire configure`, ya vimos que existe `lib/firebase_options.dart`. Déjalo como está.

---

## 2) Archivos incluidos en este patch

**Nuevos:**  
- `lib/data/models/note.dart`  
- `lib/data/repositories/note_repository.dart`  
- `lib/assistant/voice_assistant.dart`  
- `firestore.rules` (para pegar en Firebase Console)

**Reemplazos (copia/pega el contenido):**  
- `lib/main.dart`  
- `lib/screens/new_note_screen.dart`  
- `lib/screens/notes_screen.dart`  
- `lib/screens/deleted_screen.dart`  
- `lib/screens/search_screen.dart`  

> Si quieres conservar la UI exacta que ya tenías, puedes **usar estos archivos como guía** y mover solo las partes de `StreamBuilder`, llamadas al repositorio y navegación por voz a tus widgets existentes.

---

## 3) Permisos (Android / iOS)

**Android** – abre `android/app/src/main/AndroidManifest.xml` y agrega dentro de `<manifest>`:
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

**iOS** – abre `ios/Runner/Info.plist` y agrega:
```xml
<key>NSSpeechRecognitionUsageDescription</key>
<string>Necesitamos reconocer tu voz para crear y buscar notas.</string>
<key>NSMicrophoneUsageDescription</key>
<string>Usamos el micrófono para dictar notas.</string>
```

---

## 4) Reglas de seguridad Firestore
En **Firebase Console → Firestore → Rules**, pega el contenido de `firestore.rules`:

```
// users/{uid}/notes/{noteId}
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{uid}/notes/{noteId} {
      allow read, update, delete: if request.auth != null && request.auth.uid == uid;
      allow create: if request.auth != null
                    && request.auth.uid == uid
                    && request.resource.data.uid == uid;
    }
  }
}
```

Publica las reglas.

---

## 5) Windows (Error de symlink / CMake)
Si te sale: **“Building with plugins requires symlink support”** o errores de CMake en plugins:

1. Activa **Developer Mode** en Windows: `Win + R` → `start ms-settings:developers` → habilitar.  
2. Cierra VSCode, vuelve a abrir.
3. Instala **Visual Studio Build Tools 2022** con “Desktop development with C++” (incluye CMake).
4. En terminal:
```bash
flutter clean
flutter pub get
flutter run -d windows
```

---

## 6) Orden de pruebas

1. Ejecuta la app (`flutter run`).  
2. Verifica que se crea/entra a sesión anónima (no verás UI, pero Firestore lo usará).  
3. En **Notas**, crea una nota → confirma que aparece en tiempo real.  
4. Manda una nota a **Eliminados** y restáurala.  
5. **Buscar**: escribe término y valida resultados.  
6. Pulsa el botón de **micrófono** y prueba comandos:
   - “crear nota titulada ‘Lista’ con contenido ‘Arroz y carne’”  
   - “buscar universidad”  
   - “abrir eliminados” / “ver notas”

Si algo no compila, revisa que agregaste los **permisos**, instalaste las **dependencias** y que `firebase_options.dart` existe.

¡Listo!

