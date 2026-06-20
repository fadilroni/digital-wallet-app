import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'data_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initDatabase();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aplikasi Dompet Digital',
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.green,
      ),

      // 2. Tema Gelap (Dark Mode)
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
      ),

      // 3. Perintah untuk mendeteksi sistem HP
      themeMode: ThemeMode.system,
      home: HomeScreen(), // Aplikasi langsung membuka halaman utama
      debugShowCheckedModeBanner: false,
    );
  }
}
