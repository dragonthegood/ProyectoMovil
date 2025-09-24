import 'package:flutter/material.dart';

class NewFolderScreen extends StatefulWidget {
  const NewFolderScreen({super.key});

  @override
  State<NewFolderScreen> createState() => _NewFolderScreenState();
}

class _NewFolderScreenState extends State<NewFolderScreen> {
  final TextEditingController _controller = TextEditingController(text: 'Nueva carpeta');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Column(
          children: [
            // AppBar manual
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(
                        color: Color(0xFFFFCC00),
                        fontSize: 16,
                        fontFamily: 'SFProDisplay',
                      ),
                    ),
                  ),
                  const Text(
                    'Nueva carpeta',
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: 'SFProDisplay',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      final folderName = _controller.text.trim();
                      if (folderName.isNotEmpty) {
                        Navigator.pop(context, folderName);
                      }
                    },
                    child: const Text(
                      'Listo',
                      style: TextStyle(
                        color: Color(0xFFFFCC00),
                        fontSize: 16,
                        fontFamily: 'SFProDisplay',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // TextField
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: TextField(
                controller: _controller,
                autofocus: true,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: 'Nombre de carpeta',
                  hintStyle: const TextStyle(fontFamily: 'SFProDisplay'),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear, color: Color(0xFFFFCC00)),
                    onPressed: () => _controller.clear(),
                  ),
                ),
                style: const TextStyle(
                  fontSize: 16,
                  fontFamily: 'SFProDisplay',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
