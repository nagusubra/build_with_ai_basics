import 'package:flutter/material.dart';

import 'screens/dev/verification_lab_screen.dart';
import 'theme/theme.dart';

void main() {
  runApp(const BakeOutApp());
}

class BakeOutApp extends StatelessWidget {
  const BakeOutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BakeOut',
      debugShowCheckedModeBanner: false,
      theme: buildBakeTheme(),
      home: const VerificationLabScreen(),
    );
  }
}
