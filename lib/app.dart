import 'package:flutter/material.dart';

import 'ui/home_shell.dart';

class CaisseApp extends StatelessWidget {
  const CaisseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ma Caisse',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B7F5C)),
      ),
      home: const HomeShell(),
    );
  }
}
