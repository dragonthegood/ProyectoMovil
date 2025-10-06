import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

Future<void> showAccountSheet(BuildContext context) async {
  final auth = AuthService.I;
  final user = FirebaseAuth.instance.currentUser;

  await showModalBottomSheet(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) {
      final isAnon = user?.isAnonymous ?? true;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(
                isAnon
                    ? 'Modo invitado'
                    : (user?.displayName?.isNotEmpty == true
                        ? user!.displayName!
                        : (user?.email ?? 'Sesión iniciada')),
              ),
              subtitle: Text(isAnon
                  ? 'Tus notas se guardan en la nube con un ID anónimo. Te recomendamos vincular tu cuenta para recuperarlas si reinstalas.'
                  : 'Conectado a tu cuenta'),
            ),
            const SizedBox(height: 8),
            if (isAnon)
              ElevatedButton.icon(
                icon: const Icon(Icons.login),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFCC00),
                  foregroundColor: Colors.black,
                  minimumSize: const Size.fromHeight(44),
                ),
                label: const Text('Iniciar sesión con Google'),
                onPressed: () async {
                  try {
                    await auth.signInWithGoogle();
                    if (context.mounted) Navigator.pop(context);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Sesión iniciada')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error al iniciar sesión: $e')),
                      );
                    }
                  }
                },
              )
            else
              OutlinedButton.icon(
                icon: const Icon(Icons.logout),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
                label: const Text('Cerrar sesión (seguir como invitado)'),
                onPressed: () async {
                  await auth.signOutToAnonymous();
                  if (context.mounted) Navigator.pop(context);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sesión cerrada')),
                    );
                  }
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
