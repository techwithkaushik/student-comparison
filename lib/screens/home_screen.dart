import 'package:flutter/material.dart';

import 'comparison_screen.dart';

/// The comparison dashboard is now the app's primary screen.
/// Import/export actions live in its AppBar menu.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComparisonDashboardScreen();
  }
}
