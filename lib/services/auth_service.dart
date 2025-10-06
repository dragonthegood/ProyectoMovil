import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService._();
  static final I = AuthService._();

  final _auth = FirebaseAuth.instance;

  User? get user => _auth.currentUser;
  bool get isSignedIn => _auth.currentUser != null && !_auth.currentUser!.isAnonymous;
  bool get isAnonymous => _auth.currentUser?.isAnonymous ?? true;

  /// Garantiza que haya un usuario (anónimo si no hay sesión).
  Future<User> ensureSignedInAnonymously() async {
    if (_auth.currentUser == null) {
      final cred = await _auth.signInAnonymously();
      return cred.user!;
    }
    return _auth.currentUser!;
    }

  /// Iniciar sesión con Google. Si el user actual es anónimo, enlaza (link)
  /// las credenciales para **conservar el mismo UID** y por tanto tus notas.
  Future<User?> signInWithGoogle() async {
    final auth = _auth;
    final isAnon = auth.currentUser?.isAnonymous ?? false;

    if (kIsWeb) {
      final provider = GoogleAuthProvider()
        ..addScope('email')
        ..setCustomParameters({'prompt': 'select_account'});
      try {
        if (isAnon) {
          // Enlaza la cuenta anónima con Google (mantiene UID)
          final userCred = await auth.currentUser!.linkWithPopup(provider);
          return userCred.user;
        } else {
          final userCred = await auth.signInWithPopup(provider);
          return userCred.user;
        }
      } on FirebaseAuthException catch (e) {
        // Si ya estaba enlazado o la credencial está en uso, hacemos signIn normal
        if (e.code == 'credential-already-in-use' || e.code == 'provider-already-linked') {
          final userCred = await auth.signInWithPopup(provider);
          return userCred.user;
        }
        rethrow;
      }
    } else {
      // Android / iOS
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return auth.currentUser; // cancelado
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      try {
        if (isAnon) {
          final userCred = await auth.currentUser!.linkWithCredential(credential);
          return userCred.user;
        } else {
          final userCred = await auth.signInWithCredential(credential);
          return userCred.user;
        }
      } on FirebaseAuthException catch (e) {
        if (e.code == 'credential-already-in-use' || e.code == 'provider-already-linked') {
          final userCred = await auth.signInWithCredential(credential);
          return userCred.user;
        }
        rethrow;
      }
    }
  }

  /// Cerrar sesión: dejamos la app usable sin cuenta volviendo a anónimo.
  Future<User> signOutToAnonymous() async {
    try {
      await _auth.signOut();
    } catch (_) {}
    final cred = await _auth.signInAnonymously();
    return cred.user!;
  }
}
