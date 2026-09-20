import 'package:flutter/material.dart';
import 'database/database.dart';

import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDatabase.instance.database;

  runApp(const StudentComparisonApp());
}

class StudentComparisonApp extends StatelessWidget {
  const StudentComparisonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PSP vs UDISE',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
        ),
        visualDensity: VisualDensity.compact,
      ),
      home: const HomeScreen(),
    );
  }
}
