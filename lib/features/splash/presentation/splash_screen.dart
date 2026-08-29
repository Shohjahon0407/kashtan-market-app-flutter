import 'package:flutter/material.dart';

import 'startup_intro.dart';

/// Sessiya tekshirilayotgandagi kutish ekrani.
///
/// QOIDA: bu ekran HECH QACHON o'zi navigatsiya qilmaydi — router
/// `checkingSession` tugashi bilan redirect orqali olib chiqadi.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Text(
          'BESHKASHTAN',
          style: TextStyle(
            inherit: false,
            color: StartupIntro.brandColor,
            fontFamily: 'Inter',
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.7,
            height: 1,
            decoration: TextDecoration.none,
            decorationColor: Colors.transparent,
          ),
        ),
      ),
    );
  }
}
