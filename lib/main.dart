import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

import 'screens/home_screen.dart';
import 'screens/new_folder_screen.dart';
import 'screens/notes_screen.dart';
import 'screens/deleted_screen.dart';
import 'screens/note_detail_screen.dart';
import 'screens/deleted_note_detail_screen.dart';
import 'screens/new_note_screen.dart';
import 'screens/search_screen.dart';
import 'screens/edit_note_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Login anónimo: una cuenta por dispositivo
  if (FirebaseAuth.instance.currentUser == null) {
    await FirebaseAuth.instance.signInAnonymously();
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/notes': (context) => const NotesScreen(),
        '/note-detail': (context) => const NoteDetailScreen(),
        '/edit-note': (context) => const EditNoteScreen(), // <-- AÑADIR
        '/deleted': (context) => const DeletedScreen(),
        '/deleted-detail': (context) => const DeletedNoteDetailScreen(),
        '/new-note': (context) => const NewNoteScreen(),
        '/search': (context) => const SearchScreen(),
        '/new-folder': (context) => const NewFolderScreen(),
      },
    );
  }
}
