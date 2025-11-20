import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:proyectomovil/features/notes/application/voice_assistant.dart';

class VoiceOverlay extends StatefulWidget {
  final VoiceAssistant assistant;
  const VoiceOverlay({super.key, required this.assistant});

  @override
  State<VoiceOverlay> createState() => _VoiceOverlayState();
}

class _VoiceOverlayState extends State<VoiceOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _anim = Tween<double>(
      begin: 0.92,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.assistant.overlayBecameVisible(context);
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    widget.assistant.overlayDisposed();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.assistant;
    final size = MediaQuery.of(context).size;
    final maxH = (size.height * 0.8).clamp(0.0, 400.0); // altura máx. segura

    return SafeArea(
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 520,
              maxHeight: maxH,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // barra superior
                  Row(
                    children: [
                      const Icon(Icons.assistant, color: Color(0xFFFFCC00)),
                      const SizedBox(width: 8),
                      const Text(
                        'Asistente',
                        style: TextStyle(
                          fontFamily: 'SFProDisplay',
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Cerrar',
                        onPressed: () => a.onTapClose(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // ----- CONTENIDO SCROLLEABLE -----
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(right: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Mensaje / prompt del asistente
                          ValueListenableBuilder<String>(
                            valueListenable: a.prompt,
                            builder: (_, value, __) => SelectableText(
                              value,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'SFProDisplay',
                                color: Color(0xFF606060),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // "onda" simple (círculos) con animación segura
                          Center(
                            child: ScaleTransition(
                              scale: _anim,
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFFFFCC00).withOpacity(0.12),
                                ),
                                child: const Icon(
                                  Icons.mic,
                                  color: Color(0xFFFFCC00),
                                  size: 36,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Transcripción en vivo
                          ValueListenableBuilder<String>(
                            valueListenable: a.liveText,
                            builder: (_, text, __) => AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: text.isEmpty ? 0.0 : 1.0,
                              child: SelectableText(
                                text,
                                textAlign: TextAlign.center,
                                // sin maxLines para permitir scroll natural
                                style: const TextStyle(
                                  fontFamily: 'SFProDisplay',
                                  color: Color(0xFF404040),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // ----- FIN CONTENIDO SCROLLEABLE -----

                  const SizedBox(height: 16),

                  // Botón principal: Hablar / Detener
                  ValueListenableBuilder<bool>(
                    valueListenable: a.isListening,
                    builder: (_, listening, __) {
                      return SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFCC00),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                          ),
                          onPressed: () async {
                            if (listening) {
                              await a.onTapStop();
                            } else {
                              await a.onTapSpeak(context);
                            }
                          },
                          icon: Icon(listening ? Icons.stop : Icons.mic),
                          label: Text(
                            listening ? 'Detener' : 'Hablar',
                            style: const TextStyle(fontFamily: 'SFProDisplay'),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Helper para escuchar dos ValueNotifiers a la vez sin mezclar lógica en el árbol
class ValueListenableBuilder2<A, B> extends StatelessWidget {
  final ValueListenable<A> first;
  final ValueListenable<B> second;
  final Widget Function(BuildContext, A, B, Widget?) builder;
  final Widget? child;
  const ValueListenableBuilder2({
    super.key,
    required this.first,
    required this.second,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<A>(
      valueListenable: first,
      builder: (context, a, _) => ValueListenableBuilder<B>(
        valueListenable: second,
        builder: (context, b, __) => builder(context, a, b, child),
      ),
    );
  }
}
