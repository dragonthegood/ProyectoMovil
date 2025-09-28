import 'package:flutter/material.dart';
import '../assistant/voice_assistant.dart';

/// Mic flotante centrado, no interfiere con tus otros FAB.
class VoiceButton extends StatelessWidget {
  const VoiceButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 86),
        child: GestureDetector(
          onTap: () => VoiceAssistant.I.openOverlay(context),
          child: Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Color(0xFFFFCC00),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.mic, color: Colors.black87),
          ),
        ),
      ),
    );
  }
}
