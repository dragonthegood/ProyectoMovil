import 'package:flutter/material.dart';

class NoteDetailScreen extends StatelessWidget {
  const NoteDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Botón atrás + "Notas"
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 16),
              child: GestureDetector(
                onTap: () => Navigator.pushReplacementNamed(context, '/notes'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Color(0xFFFFCC00),
                      size: 20,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Notas',
                      style: TextStyle(
                        color: Color(0xFFFFCC00),
                        fontSize: 18,
                        fontFamily: 'SFProDisplay',
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Título estático
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Lista de compra',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'SFProDisplay',
                  color: Color(0xFF404040),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Contenido estático
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Arroz\nCarne\nPan\nTomates\nQueso\nMortadela',
                style: TextStyle(
                  fontSize: 17,
                  fontFamily: 'SFProDisplay',
                  color: Color(0xFF404040),
                ),
              ),
            ),

            const Spacer(),

            // Iconos inferiores
            const Padding(
              padding: EdgeInsets.only(bottom: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
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
