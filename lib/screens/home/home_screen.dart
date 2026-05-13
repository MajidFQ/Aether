import 'package:flutter/material.dart';

/// Shown after a successful login. Replace this body with your real home experience.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: const Center(
        child: Text('Welcome to Aether'),
      ),
    );
  }
}
