import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const Scan2ChatApp());
}

class Scan2ChatApp extends StatelessWidget {
  const Scan2ChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scan2Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.green, useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}