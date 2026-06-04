import 'package:flutter/material.dart';
import '../../main.dart';
import '../models/reading_model.dart';
import 'calendar_tab.dart';
import 'today_tab.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 1; 
  late Future<List<DevotionalReading>> _futureReadings;
  
  List<DevotionalReading> _loadedReadings = [];
  int _currentStreak = 0;
  int _totalReadChapters = 0;
  bool _isInitialized = false;
  
  String? _activeProfileId; 

  List<bool> _weeklyTracker = List.generate(7, (_) => false);

  @override
  void initState() {
    super.initState();
    _futureReadings = _fetchCalendarFromSupabase();
  }

  Future<List<DevotionalReading>> _fetchCalendarFromSupabase() async {
    try {
      final response = await supabase
          .from('readings')
          .select()
          .order('date', ascending: true);
      
      final readings = (response as List).map((item) {
        final reading = DevotionalReading.fromJson(item);
        final pureDate = reading.date.toLocal();
        return DevotionalReading(
          id: reading.id,
          date: DateTime(pureDate.year, pureDate.month, pureDate.day), 
          bookAndChapter: reading.bookAndChapter,
          specialEvent: reading.specialEvent,
          dailyVerse: reading.dailyVerse,
          dailyVerseRef: reading.dailyVerseRef,
          isCompleted: false, // Se evalúa dinámicamente según el progreso del usuario
        );
      }).toList();

      // Si el usuario tiene sesión activa, cruzamos su progreso guardado en la nube
      if (_activeProfileId != null) {
        final progressResponse = await supabase
            .from('user_progress')
            .select('reading_id')
            .eq('profile_id', _activeProfileId!);

        final completedIds = (progressResponse as List)
            .map((p) => p['reading_id'].toString())
            .toSet();

        for (var r in readings) {
          if (completedIds.contains(r.id)) {
            r.isCompleted = true;
          }
        }
      }
      
      if (!_isInitialized || _activeProfileId != null) {
        _loadedReadings = readings;
        _isInitialized = true;
        _recalculateStats();
      }
      
      return _loadedReadings;
    } catch (error) {
      throw Exception("Error conectando con Supabase: $error");
    }
  }

  void _recalculateStats() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    _totalReadChapters = _loadedReadings.where((r) => r.isCompleted).length;

    // Resetear el tracker de la semana
    _weeklyTracker = List.generate(7, (_) => false);
    for (var reading in _loadedReadings) {
      // Si es de esta semana, marcar constancia
      if (reading.isCompleted) {
        int weekdayIndex = reading.date.weekday - 1;
        if (weekdayIndex >= 0 && weekdayIndex < 7) {
          _weeklyTracker[weekdayIndex] = true;
        }
      }
    }

    int streak = 0;
    final pastAndTodayReadings = _loadedReadings
        .where((r) => !r.date.isAfter(today))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    for (var i = 0; i < pastAndTodayReadings.length; i++) {
      final current = pastAndTodayReadings[i];
      final currentLocalDate = DateTime(current.date.year, current.date.month, current.date.day);
      
      if (currentLocalDate.isAtSameMomentAs(today)) {
        if (current.isCompleted) {
          streak++;
        }
      } else {
        if (current.isCompleted) {
          if (i == 1 && !pastAndTodayReadings[0].isCompleted && streak == 0) {
            streak = 1; 
          } else if (streak > 0) {
            streak++; 
          } else {
            break; 
          }
        } else {
          if (i > 0 || streak > 0) {
            break;
          }
        }
      }
    }

    _currentStreak = streak;
  }

  Future<void> _toggleReadingStatus(DevotionalReading reading) async {
    if (reading.id.isEmpty || reading.id == 'vacioso') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error: ID de lectura inválido."),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final readingDate = DateTime(reading.date.year, reading.date.month, reading.date.day);

    if (readingDate.isAfter(today)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Restricción: No se pueden marcar lecturas de días futuros."))
      );
      return;
    }

    final String? profileId = _activeProfileId ?? supabase.auth.currentUser?.id;

    if (profileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Debes iniciar sesión para guardar tu progreso."),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    final wasCompleted = reading.isCompleted;

    try {
      if (!wasCompleted) {
        await supabase.from('user_progress').insert({
          'profile_id': profileId,
          'reading_id': reading.id, 
          'completed_at': DateTime.now().toIso8601String(),
        });
      } else {
        await supabase.from('user_progress').delete().match({
          'profile_id': profileId,
          'reading_id': reading.id,
        });
      }

      setState(() {
        reading.isCompleted = !reading.isCompleted;
        _recalculateStats();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(wasCompleted ? "Lectura desmarcada" : "¡Progreso guardado exitosamente! 🎉"),
          duration: const Duration(seconds: 1),
        ),
      );

    } catch (error) {
      print("Error de sincronización con Supabase: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error de conexión: No se pudo modificar tu progreso."),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _onLoginOrRegisterSuccess(String profileId) {
    setState(() {
      _activeProfileId = profileId;
      _isInitialized = false; 
      _futureReadings = _fetchCalendarFromSupabase(); // Recarga el calendario cruzando tus lecturas reales
    });
  }

  void _onLogout() {
    setState(() {
      _activeProfileId = null;
      _loadedReadings = []; 
      _isInitialized = false; 
      _currentStreak = 0;
      _totalReadChapters = 0;
      _weeklyTracker = List.generate(7, (_) => false);
      _futureReadings = _fetchCalendarFromSupabase(); 
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<List<DevotionalReading>>(
      future: _futureReadings,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(body: Center(child: Text("⚠️ Error: ${snapshot.error}")));
        }

        final now = DateTime.now();
        
        final todayReading = _loadedReadings.firstWhere(
          (r) => r.date.day == now.day && r.date.month == now.month && r.date.year == now.year,
          orElse: () => _loadedReadings.isNotEmpty 
              ? _loadedReadings.first 
              : DevotionalReading(id: 'vacioso', date: DateTime.now(), bookAndChapter: "Sin lectura asignada"),
        );

        final List<Widget> tabs = [
          CalendarTab(readings: _loadedReadings, onToggle: _toggleReadingStatus),
          TodayTab(todayReading: todayReading, onToggle: _toggleReadingStatus, streakCount: _currentStreak),
          ProfileScreen(
            streakCount: _currentStreak, 
            totalRead: _totalReadChapters,
            userWeeklyProgress: _weeklyTracker,
            activeProfileId: _activeProfileId,
            onAuthChanged: _onLoginOrRegisterSuccess,
            onLogout: _onLogout,
          ),
        ];

        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: tabs,
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            selectedItemColor: theme.primaryColor,
            unselectedItemColor: Colors.grey,
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.grid_on), label: 'Calendario'),
              BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Hoy'),
              BottomNavigationBarItem(icon: Icon(Icons.person_pin), label: 'Perfil'),
            ],
          ),
        );
      },
    );
  }
}