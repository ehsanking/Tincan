import 'package:flutter/material.dart';

import 'ui/onboarding_screen.dart';

/// Root of the Tincan app.
class TincanApp extends StatelessWidget {
  const TincanApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFB5651D), // tin / copper
      brightness: Brightness.dark,
    );
    return MaterialApp(
      title: 'Tincan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: scheme, useMaterial3: true),
      home: const OnboardingScreen(),
    );
  }
}
