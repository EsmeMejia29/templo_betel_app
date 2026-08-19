import 'package:flutter/material.dart';
import '../../main.dart';
import '../models/reading_model.dart';
import '../services/devotional_service.dart';
import 'calendar_tab.dart';
import 'today_tab.dart';
import 'profile_screen.dart';
import 'dashboard_screen.dart'; 

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
  int _maxStreak = 0;
  int _totalReadChapters = 0;
  bool _isInitialized = false;
  
  String? _activeProfileId; 

  List<bool> _weeklyTracker = List.generate(7, (_) => false);
  double _bibleFontSize = 14.0;

  @override
  void initState() {
    super.initState();
    _futureReadings = _fetchCalendarAndProfileStats();
    _probarConexionDevocional(); // <-- Prueba de conexión añadida
  }

  Future<void> _probarConexionDevocional() async {
    final devotionalService = DevotionalService();
    try {
      print('=== INICIANDO PRUEBA DEVOCIONAL ===');
      
      final indice = await devotionalService.leerIndice();
      print('Índice obtenido: $indice');

      final capitulo = await devotionalService.leerCapitulo('Genesis', 1);
      print('Capítulo obtenido: $capitulo');
      
      print('=== PRUEBA COMPLETADA CON ÉXITO ===');
    } catch (e) {
      print('=== ERROR EN PRUEBA DEVOCIONAL ===: $e');
    }
  }

  Future<List<DevotionalReading>> _fetchCalendarAndProfileStats() async {
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
          chapterContent: reading.chapterContent,
          isCompleted: false, 
        );
      }).toList();

      if (_activeProfileId != null && _activeProfileId != 'admin') {
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

        final profileResponse = await supabase
            .from('profiles')
            .select('max_streak')
            .eq('id', _activeProfileId!)
            .maybeSingle();

        if (profileResponse != null && profileResponse['max_streak'] != null) {
          setState(() {
            _maxStreak = profileResponse['max_streak'];
          });
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

    _weeklyTracker = List.generate(7, (_) => false);

    final inicioSemana = today.subtract(Duration(days: today.weekday - 1));
    final finSemana = inicioSemana.add(const Duration(days: 6));

    for (var reading in _loadedReadings) {
      if (reading.isCompleted) {
        final fechaLectura = DateTime(reading.date.year, reading.date.month, reading.date.day);
        
        if ((fechaLectura.isAtSameMomentAs(inicioSemana) || fechaLectura.isAfter(inicioSemana)) &&
            (fechaLectura.isAtSameMomentAs(finSemana) || fechaLectura.isBefore(finSemana))) {
          int weekdayIndex = reading.date.weekday - 1;
          if (weekdayIndex >= 0 && weekdayIndex < 7) {
            _weeklyTracker[weekdayIndex] = true;
          }
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

    if (_currentStreak > _maxStreak) {
      _maxStreak = _currentStreak;
    }
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
        
        _recalculateStats();
        await supabase.from('profiles').update({
          'current_streak': _currentStreak,
        }).eq('id', profileId);

      } else {
        await supabase.from('user_progress').delete().match({
          'profile_id': profileId,
          'reading_id': reading.id,
        });

        _recalculateStats();
        await supabase.from('profiles').update({
          'current_streak': _currentStreak,
        }).eq('id', profileId);
      }

      if (mounted) {
        final profileResponse = await supabase
            .from('profiles')
            .select('max_streak')
            .eq('id', profileId)
            .maybeSingle();

        if (profileResponse != null && profileResponse['max_streak'] != null) {
          setState(() {
            _maxStreak = profileResponse['max_streak'];
          });
        }
      }

      if (!mounted) return;
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
      if (!mounted) return;
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
      if (profileId == 'admin') {
        _currentIndex = 1; 
      } else {
        _currentIndex = 1;
        _isInitialized = false; 
        _futureReadings = _fetchCalendarAndProfileStats(); 
      }
    });
  }

  void _onLogout() {
    setState(() {
      _activeProfileId = null;
      _currentIndex = 1;
      _loadedReadings = []; 
      _isInitialized = false; 
      _currentStreak = 0;
      _maxStreak = 0; 
      _totalReadChapters = 0;
      _weeklyTracker = List.generate(7, (_) => false);
      _futureReadings = _fetchCalendarAndProfileStats(); 
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAdmin = _activeProfileId == 'admin';

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

        final List<Widget> tabs = isAdmin
            ? [
                ProfileScreen(
                  streakCount: _currentStreak, 
                  maxStreak: _maxStreak, 
                  totalRead: _totalReadChapters,
                  userWeeklyProgress: _weeklyTracker,
                  activeProfileId: _activeProfileId,
                  onAuthChanged: _onLoginOrRegisterSuccess,
                  onLogout: _onLogout,
                ),
                const DashboardScreen(), 
              ]
            : [
                CalendarTab(readings: _loadedReadings, onToggle: _toggleReadingStatus),
                TodayTab(
                  todayReading: todayReading, 
                  onToggle: _toggleReadingStatus, 
                  streakCount: _currentStreak,
                  currentFontSize: _bibleFontSize,
                  onFontSizeChanged: (newSize) {
                    setState(() {
                      _bibleFontSize = newSize;
                    });
                  },
                ),
                ProfileScreen(
                  streakCount: _currentStreak, 
                  maxStreak: _maxStreak, 
                  totalRead: _totalReadChapters,
                  userWeeklyProgress: _weeklyTracker,
                  activeProfileId: _activeProfileId,
                  onAuthChanged: _onLoginOrRegisterSuccess,
                  onLogout: _onLogout,
                ),
              ];

        final List<BottomNavigationBarItem> navigationItems = isAdmin
            ? const [
                BottomNavigationBarItem(icon: Icon(Icons.person_pin), label: 'Perfil Admin'),
                BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
              ]
            : const [
                BottomNavigationBarItem(icon: Icon(Icons.grid_on), label: 'Calendario'),
                BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Hoy'),
                BottomNavigationBarItem(icon: Icon(Icons.person_pin), label: 'Perfil'),
              ];

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 30),
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: tabs,
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            selectedItemColor: theme.primaryColor,
            unselectedItemColor: Colors.grey,
            type: BottomNavigationBarType.fixed,
            items: navigationItems,
          ),
        );
      },
    );
  }
}