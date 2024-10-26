import 'package:flutter/material.dart';
import 'screens/pickMenu.dart'; // pickMenu.dart dosyasını import ettik

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PickMenu(), // PickMenu sayfasını ana sayfa olarak ayarladık
    );
  }
}
