import 'package:flutter/material.dart';
import '../data/repositories/folder_repository.dart';

/// Pantalla para crear carpeta.
/// - Manual: el usuario escribe y toca "Guardar".
/// - Asistente: navegar a '/new-folder' con:
///   - {'name': 'Trabajo'}  [modo legacy]
///   - o {'prefill': 'Trabajo', 'autoSave': true}
class NewFolderScreen extends StatefulWidget {
  const NewFolderScreen({super.key});

  @override
  State<NewFolderScreen> createState() => _NewFolderScreenState();
}

class _NewFolderScreenState extends State<NewFolderScreen> {
  final _controller = TextEditingController(text: 'Nueva carpeta');
  final _repo = FolderRepository();

  bool _saving = false;
  bool _autoTried = false; // evita doble guardado al entrar con argumentos

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_autoTried) return;

    final args = ModalRoute.of(context)?.settings.arguments;

    String? prefill;
    bool autoSave = false;

    if (args is Map) {
      // Compatibilidad: name (viejo), prefill (nuevo) y banderita autoSave
      if (args['name'] is String) prefill = (args['name'] as String).trim();
      if (args['prefill'] is String) prefill = (args['prefill'] as String).trim();
      if (args['autoSave'] is bool) autoSave = args['autoSave'] as bool;
    }

    if ((prefill ?? '').isNotEmpty) {
      _controller.text = prefill!;
    }

    if (autoSave && (_controller.text.trim().isNotEmpty)) {
      _autoTried = true;
      // Ejecutar tras el primer frame
      WidgetsBinding.instance.addPostFrameCallback((_) => _onSave(auto: true));
    }
  }

  Future<void> _onSave({bool auto = false}) async {
    if (_saving) return;

    final name = _controller.text.trim();
    if (name.isEmpty) {
      if (!auto && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Escribe un nombre para la carpeta')),
        );
      }
      return;
    }

    setState(() => _saving = true);
    try {
      await _repo.create(name);
      if (!mounted) return;

      if (!auto) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Carpeta "$name" creada')),
        );
      }
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo crear la carpeta: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: _saving ? null : () => Navigator.pop(context),
                    child: Text(
                      'Cancelar',
                      style: TextStyle(
                        fontSize: 16,
                        color: _saving ? Colors.grey : const Color(0xFFFFCC00),
                      ),
                    ),
                  ),
                  const Text(
                    'Nueva carpeta',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  GestureDetector(
                    onTap: _saving ? null : () => _onSave(),
                    child: Text(
                      _saving ? 'Guardando…' : 'Guardar',
                      style: TextStyle(
                        fontSize: 16,
                        color: _saving ? Colors.grey : const Color(0xFFFFCC00),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _controller,
                autofocus: true,
                enabled: !_saving,
                decoration: const InputDecoration(
                  hintText: 'Nombre de la carpeta',
                  border: OutlineInputBorder(borderSide: BorderSide.none),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onSubmitted: (_) => _onSave(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
