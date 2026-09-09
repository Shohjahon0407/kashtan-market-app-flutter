import 'package:flutter/material.dart';

/// Admin bergan fon rangi ustida o'qiladigan matn rangi: och fonda to'q,
/// to'q fonda oq. Do'kon kartalari va katalog hero'si bir xil qoida bilan.
Color onAccent(Color background) => background.computeLuminance() > 0.55
    ? const Color(0xFF0F172A)
    : Colors.white;
