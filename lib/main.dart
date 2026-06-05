import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/theme.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://qmwljxvpawnfthsfkstb.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFtd2xqeHZwYXduZnRoc2Zrc3RiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA1MzY0MzEsImV4cCI6MjA5NjExMjQzMX0.ujWsQ6yt-pg2H77nqVuI8ZZVTR6SuUERGjWsiNnwWhY',
  );

  runApp(const TemploBetelApp());
}

final supabase = Supabase.instance.client;

class TemploBetelApp extends StatelessWidget {
  const TemploBetelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Templo Betel',
      debugShowCheckedModeBanner: false,
      theme: BetelTheme.lightTheme,
      home: const HomeScreen(),
    );
  }
}