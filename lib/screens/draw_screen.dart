import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import '../data/repositories/note_repository.dart';

class DrawScreen extends StatefulWidget {
  const DrawScreen({super.key});

  @override
  State<DrawScreen> createState() => _DrawScreenState();
}

class _Sketch {
  _Sketch(this.color, this.strokeWidth);
  final Color color;
  final double strokeWidth;
  final List<Offset> points = <Offset>[];
}

class _SketchPainter extends CustomPainter {
  final List<_Sketch> sketches;
  _SketchPainter(this.sketches);

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in sketches) {
      final paint = Paint()
        ..color = s.color
        ..strokeWidth = s.strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      for (int i = 0; i < s.points.length - 1; i++) {
        canvas.drawLine(s.points[i], s.points[i + 1], paint);
      }
      if (s.points.length == 1) {
        canvas.drawPoints(ui.PointMode.points, s.points, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SketchPainter oldDelegate) => true;
}

class _DrawScreenState extends State<DrawScreen> {
  final _repo = NoteRepository();
  final _key = GlobalKey();
  final List<_Sketch> _sketches = [];
  _Sketch? _current;
  Color _color = const Color(0xFFFFCC00);
  double _stroke = 4;
  bool _saving = false;

  void _start(Offset p) {
    setState(() {
      _current = _Sketch(_color, _stroke)..points.add(p);
      _sketches.add(_current!);
    });
  }

  void _update(Offset p) {
    if (_current == null) return;
    setState(() => _current!.points.add(p));
  }

  void _end() => setState(() => _current = null);

  Future<void> _save(String noteId) async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      // Nota: en web con HTML renderer toImage no está soportado.
      if (kIsWeb) {
        // Intentaremos capturar; si falla, mostramos guía de CanvasKit.
      }

      await WidgetsBinding.instance.endOfFrame;

      final obj = _key.currentContext?.findRenderObject();
      if (obj is! RenderRepaintBoundary) {
        throw 'No se encontró el lienzo para capturar.';
      }

      final boundary = obj as RenderRepaintBoundary;

      ui.Image image;
      try {
        image = await boundary.toImage(pixelRatio: 3.0);
      } on FlutterError catch (e) {
        // Mensaje claro para el caso de HTML renderer
        final msg = e.message ?? e.toString();
        if (kIsWeb && msg.toLowerCase().contains('html renderer')) {
          throw 'En Flutter Web con HTML renderer no se puede capturar el lienzo.\n'
              'Ejecuta con CanvasKit:\n'
              'flutter run -d chrome --web-renderer canvaskit';
        }
        rethrow;
      }

      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw 'Error al convertir el dibujo a PNG.';
      final Uint8List bytes = byteData.buffer.asUint8List();

      final name = 'drawing_${DateTime.now().millisecondsSinceEpoch}.png';

      final url = await _repo.addImageAttachment(
        noteId: noteId,
        name: name,
        bytes: bytes,
        mimeType: 'image/png',
        size: bytes.length,
      );

      // Añade una línea con el URL (texto plano)
      await _repo.appendToContent(noteId, '🖌️ Dibujo agregado ($name)\n$url');

      // --- Si prefieres Markdown de imagen, usa esta línea en su lugar ---
      // await _repo.appendToContent(noteId, '🖌️ Dibujo agregado ($name)\n![]($url)');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dibujo guardado en la nota')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map?;
    final noteId = args?['noteId'] as String?;
    if (noteId == null) {
      return const Scaffold(body: Center(child: Text('Falta el noteId')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // App bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Color(0xFFFFCC00),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Dibujo',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'SFProDisplay',
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _save(noteId),
                        icon: const Icon(
                          Icons.save_rounded,
                          color: Color(0xFFFFCC00),
                        ),
                        label: const Text(
                          'Guardar',
                          style: TextStyle(
                            color: Color(0xFFFFCC00),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // lienzo
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: ColoredBox(
                        color: Colors.white,
                        child: RepaintBoundary(
                          key: _key,
                          child: GestureDetector(
                            onPanStart: (d) => _start(d.localPosition),
                            onPanUpdate: (d) => _update(d.localPosition),
                            onPanEnd: (_) => _end(),
                            child: CustomPaint(
                              painter: _SketchPainter(_sketches),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // herramientas
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          for (final c in <Color>[
                            const Color(0xFFFFCC00),
                            Colors.black,
                            Colors.red,
                            Colors.blue,
                            Colors.green,
                            Colors.purple,
                          ])
                            Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: GestureDetector(
                                onTap: () => setState(() => _color = c),
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: c,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _color == c
                                          ? Colors.black54
                                          : Colors.black12,
                                      width: _color == c ? 2 : 1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          const Spacer(),
                          IconButton(
                            tooltip: 'Deshacer',
                            onPressed: _sketches.isEmpty
                                ? null
                                : () => setState(() => _sketches.removeLast()),
                            icon: const Icon(Icons.undo),
                          ),
                          IconButton(
                            tooltip: 'Limpiar',
                            onPressed: _sketches.isEmpty
                                ? null
                                : () => setState(_sketches.clear),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text(
                            'Grosor',
                            style: TextStyle(fontFamily: 'SFProDisplay'),
                          ),
                          Expanded(
                            child: Slider(
                              min: 1,
                              max: 20,
                              value: _stroke,
                              onChanged: (v) => setState(() => _stroke = v),
                            ),
                          ),
                          Text(_stroke.toStringAsFixed(0)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
            if (_saving)
              Container(
                color: Colors.black26,
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}
