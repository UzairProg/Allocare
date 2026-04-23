import 'package:flutter/material.dart';

import 'main_navigation_screen.dart';

class HomeShellPage extends StatelessWidget {
  const HomeShellPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Keep this wrapper for compatibility with older route/import references.
    return const MainNavigationScreen();
  }
}
