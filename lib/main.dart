import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Make sure this file exists and is correctly configured.
import 'login_page.dart'; // This should be the file that contains your LoginPage widget.

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BenosAfrimed',
      theme: ThemeData(
        primaryColor: const Color(0xFF8D1B3D), // Example primary color
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.red).copyWith(
          secondary: const Color(0xFF8D1B3D),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF8D1B3D),
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8D1B3D),
            foregroundColor: Colors.white,
          ),
        ),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        textSelectionTheme: const TextSelectionThemeData(
          selectionColor: Colors.transparent,
          selectionHandleColor: Colors.transparent,
          cursorColor: Colors.white,
        ),
      ),
      home: LoginPage(), // This refers to the LoginPage defined in login_page.dart
    );
  }
}
