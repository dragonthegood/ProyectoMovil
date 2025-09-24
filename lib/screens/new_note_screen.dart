import 'package:flutter/material.dart';

class NewNoteScreen extends StatelessWidget {
  const NewNoteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Botón atrás combinado (ícono + texto)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 16),
              child: GestureDetector(
                onTap: () {
                  Navigator.pushReplacementNamed(context, '/notes');
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFFFFCC00), size: 20),
                    SizedBox(width: 4),
                    Text(
                      'Notas',
                      style: TextStyle(
                        color: Color(0xFFFFCC00),
                        fontSize: 16,
                        fontFamily: 'SFProDisplay',
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Campo de título vacío
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Título',
                  border: InputBorder.none,
                ),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'SFProDisplay',
                  color: Color(0xFF404040),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Campo de contenido vacío
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Contenido...',
                  border: InputBorder.none,
                ),
                maxLines: null,
                keyboardType: TextInputType.multiline,
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'SFProDisplay',
                  color: Color(0xFF404040),
                ),
              ),
            ),

            const Spacer(),

            // Barra de iconos inferior
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: const [
                  Icon(Icons.attachment, color: Color(0xFFFFCC00), size: 28),
                  Icon(Icons.image_outlined, color: Color(0xFFFFCC00), size: 28),
                  Icon(Icons.edit, color: Color(0xFFFFCC00), size: 28),
                  Icon(Icons.note_add_outlined, color: Color(0xFFFFCC00), size: 28),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
