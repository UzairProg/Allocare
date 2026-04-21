import 'package:flutter/material.dart';

void main() {
  runApp(const AllocareApp());
}

class AllocareApp extends StatelessWidget {
  const AllocareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Allocare',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      home: const Scaffold(
        body: Center(child: Text('Allocare')),
      ),
    );
  }
}