import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:proyectomovil/features/notes/domain/models/note.dart';

class ShareHelper {
  static Future<void> shareNote(Note note, {BuildContext? context}) async {
    final title = note.title.isEmpty ? '(Sin título)' : note.title;
    final content =
        note.content.trim().isEmpty ? '(Nota vacía)' : note.content.trim();
    final message = '📝 $title\n\n$content';

    try {
      // En Web móvil usa Navigator.share si está disponible; en desktop puede no estar
      if (kIsWeb) {
        await Share.share(message, subject: title);
        return;
      }

      // Android / iOS / desktop
      await Share.share(message, subject: title);
    } on MissingPluginException catch (_) {
      // Fallback: copiar al portapapeles y avisar
      await Clipboard.setData(ClipboardData(text: message));
      _showSnack(context, 'No pude abrir “Compartir”. Texto copiado.');
    } catch (e) {
      _showSnack(context, 'No se pudo compartir: $e');
    }
  }

  static void _showSnack(BuildContext? ctx, String msg) {
    if (ctx == null) return;
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg)));
  }
}
