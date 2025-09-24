import 'package:flutter/material.dart';

class DeletedNoteDetailScreen extends StatelessWidget {
  const DeletedNoteDetailScreen({super.key});

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
                onTap: () => Navigator.of(context).pop(),
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
                      'Eliminados',
                      style: TextStyle(
                        fontFamily: 'SFProDisplay',
                        fontSize: 17,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFFFFCC00),
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
                'Contacto administracion',
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
                '3222222',
                style: TextStyle(
                  fontSize: 14,
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
