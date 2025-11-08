//main.dart
import 'package:flutter/material.dart';
import 'accueil_screen.dart';

void main() => runApp(const ExplorezVotreVilleApp());

class ExplorezVotreVilleApp extends StatelessWidget {
  const ExplorezVotreVilleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Explorez Votre Ville',
      theme: ThemeData(primarySwatch: Colors.teal),
      home: const AccueilScreen(),
    );
  }
}
