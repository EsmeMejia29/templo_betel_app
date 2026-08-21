import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';
import 'widgets/streak_badge.dart';
import 'widgets/weekly_chart.dart';

class ProfileScreen extends StatefulWidget {
  final int streakCount;
  final int maxStreak;
  final int totalRead;
  final List<bool> userWeeklyProgress; 
  final String? activeProfileId;
  final Function(String) onAuthChanged;
  final VoidCallback onLogout;

  const ProfileScreen({
    super.key, 
    required this.streakCount, 
    required this.maxStreak,
    required this.totalRead,
    required this.userWeeklyProgress,
    required this.activeProfileId,
    required this.onAuthChanged,
    required this.onLogout,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController(); 
  
  bool _isLoginMode = true;
  bool _isLoading = false;
  String _displayName = "Usuario";
  bool _isAuthHandled = false;

  List<Map<String, String>> _savedProfiles = [];
  StreamSubscription<AuthState>? _authSubscription;
  Future<List<Map<String, dynamic>>>? _rankingFuture;

  @override
  void initState() {
    super.initState();
    _loadSavedProfilesLocal();
    _fetchRanking();

    if (widget.activeProfileId != null) {
      _loadProfileData();
      return;
    }

    final existingSession = supabase.auth.currentSession;
    if (existingSession != null) {
      _handleSuccessfulGoogleAuth(existingSession.user);
    } else {
      _authSubscription = supabase.auth.onAuthStateChange.listen((data) {
        final AuthChangeEvent event = data.event;
        final Session? session = data.session;

        if ((event == AuthChangeEvent.signedIn || event == AuthChangeEvent.initialSession) &&
            session != null &&
            !_isAuthHandled) {
          _handleSuccessfulGoogleAuth(session.user);
        }
      });
    }
  }

  void _fetchRanking() {
    setState(() {
      final hoy = DateTime.now().toUtc();
      final inicioDia = DateTime.utc(hoy.year, hoy.month, hoy.day).toIso8601String();
      _rankingFuture = supabase
          .from('quiz_rankings')
          .select('id, reading_title, correct_answers, total_questions, time_seconds, created_at, profiles(full_name)')
          .gte('created_at', inicioDia)
          .order('correct_answers', ascending: false)
          .order('time_seconds', ascending: true)
          .limit(15);
    });
  }

  Future<void> _handleSuccessfulGoogleAuth(User user) async {
    if (_isAuthHandled) return;
    _isAuthHandled = true;

    _authSubscription?.cancel();
    _authSubscription = null;

    final email = user.email ?? '';
    final name = user.userMetadata?['full_name'] ?? 
                 user.userMetadata?['name'] ?? 
                 (email.isNotEmpty ? email.split('@')[0] : 'Usuario');

    try {
      await supabase.from('profiles').upsert({
        'id': user.id,
        'email': email,
        'full_name': name,
      });
    } catch (_) {}

    await _saveProfileLocally(user.id, name);

    if (mounted) {
      setState(() {
        _displayName = name;
        _isLoading = false;
      });
      widget.onAuthChanged(user.id);
      _fetchRanking();
    }
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeProfileId != oldWidget.activeProfileId) {
      if (widget.activeProfileId != null) {
        _loadProfileData();
      }
      _fetchRanking();
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _phoneController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedProfilesLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> rawList = prefs.getStringList('saved_profiles_keys') ?? [];
    
    List<Map<String, String>> profiles = [];
    for (String rawUser in rawList) {
      final parts = rawUser.split('||');
      if (parts.length == 2) {
        profiles.add({'id': parts[0], 'name': parts[1]});
      }
    }
    if (mounted) {
      setState(() {
        _savedProfiles = profiles;
      });
    }
  }

  Future<void> _saveProfileLocally(String id, String name) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> rawList = prefs.getStringList('saved_profiles_keys') ?? [];
    
    final String entry = "$id||$name";
    if (!rawList.contains(entry)) {
      rawList.add(entry);
      await prefs.setStringList('saved_profiles_keys', rawList);
      _loadSavedProfilesLocal();
    }
  }

  Future<void> _loadProfileData() async {
    try {
      final response = await supabase
          .from('profiles')
          .select('full_name')
          .eq('id', widget.activeProfileId!)
          .maybeSingle();
          
      if (response != null && response['full_name'] != null && mounted) {
        setState(() {
          _displayName = response['full_name'];
        });
        _saveProfileLocally(widget.activeProfileId!, response['full_name']);
      }
    } catch (_) {}
  }

  Future<void> _handleAuth() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    if (_isLoginMode && phone == '77777777' && password == 'TemplobetelAD') {
      setState(() {
        _isLoading = false;
        _displayName = "Administrador";
      });
      
      widget.onAuthChanged('admin'); 
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Sesión de Administrador iniciada"))
      );
      return;
    }

    try {
      if (_isLoginMode) {
        final response = await supabase
            .from('profiles')
            .select()
            .eq('phone', phone)
            .eq('password', password)
            .maybeSingle();

        if (response == null) {
          throw Exception("Número de teléfono o contraseña incorrectos.");
        }

        await _saveProfileLocally(response['id'], response['full_name']);

        if (mounted) {
          setState(() {
            _displayName = response['full_name'];
          });
          widget.onAuthChanged(response['id']);
          _fetchRanking();
        }
      } else {
        final insertResponse = await supabase.from('profiles').insert({
          'phone': phone,
          'password': password,
          'full_name': _nameController.text.trim(),
        }).select().single();

        await _saveProfileLocally(insertResponse['id'], insertResponse['full_name']);

        if (mounted) {
          setState(() {
            _displayName = insertResponse['full_name'];
          });
          widget.onAuthChanged(insertResponse['id']);
          _fetchRanking();
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isLoginMode ? "Sesión iniciada" : "¡Registro completado al instante!"))
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll("Exception:", "")), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : 'io.supabase.flutterquickstart://login-callback/',
        queryParams: {
          'prompt': 'select_account',
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al iniciar con Google: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatTime(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSessionActive = widget.activeProfileId != null;

    if (!isSessionActive) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.phone_android, size: 54, color: theme.primaryColor),
                              const SizedBox(height: 12),
                              Text(
                                _isLoginMode ? "Ingresar a Templo Betel" : "Crear una Cuenta",
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.primaryColor),
                              ),
                              const SizedBox(height: 16),
                              
                              if (!_isLoginMode) ...[
                                TextFormField(
                                  controller: _nameController,
                                  decoration: const InputDecoration(
                                    labelText: "Tu Nombre Completo",
                                    prefixIcon: Icon(Icons.person_outline),
                                    border: OutlineInputBorder(),
                                  ),
                                  textCapitalization: TextCapitalization.words,
                                  validator: (value) => value == null || value.trim().isEmpty ? "Por favor ingresa tu nombre" : null,
                                ),
                                const SizedBox(height: 16),
                              ],

                              TextFormField(
                                controller: _phoneController,
                                decoration: const InputDecoration(
                                  labelText: "Número de Teléfono",
                                  prefixIcon: Icon(Icons.phone),
                                  hintText: "Ej: 70007000",
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.phone,
                                validator: (value) {
                                  if (value == null || value.isEmpty) return "Ingresa tu número de teléfono";
                                  if (value.replaceAll(RegExp(r'[^0-9]'), '').length < 8) return "Número inválido";
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              
                              TextFormField(
                                controller: _passwordController,
                                decoration: const InputDecoration(
                                  labelText: "Contraseña",
                                  prefixIcon: Icon(Icons.lock_outline),
                                  border: OutlineInputBorder(),
                                ),
                                obscureText: true,
                                validator: (value) => value == null || value.length < 6 ? "La contraseña debe tener mínimo 6 caracteres" : null,
                              ),
                              const SizedBox(height: 24),
                              
                              _isLoading
                                  ? const CircularProgressIndicator()
                                  : ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: theme.primaryColor,
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size.fromHeight(50),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      onPressed: _handleAuth,
                                      child: Text(_isLoginMode ? "Iniciar Sesión" : "Registrarse", style: const TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                              const SizedBox(height: 16),

                              Row(
                                children: [
                                  Expanded(child: Divider(color: Colors.grey.shade400)),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: Text("O", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                  ),
                                  Expanded(child: Divider(color: Colors.grey.shade400)),
                                ],
                              ),
                              const SizedBox(height: 16),

                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(50),
                                  side: BorderSide(color: Colors.grey.shade300),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: Image.network(
                                  'https://fonts.gstatic.com/s/i/productlogos/googleg/v6/24px.svg',
                                  height: 20,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata, size: 24, color: Colors.blue),
                                ),
                                label: Text(
                                  _isLoginMode ? "Continuar con Google" : "Registrarse con Google",
                                  style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
                                ),
                                onPressed: _isLoading ? null : _handleGoogleSignIn,
                              ),

                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () {
                                  _phoneController.clear();
                                  _passwordController.clear();
                                  _nameController.clear();
                                  setState(() => _isLoginMode = !_isLoginMode);
                                },
                                child: Text(_isLoginMode ? "¿No tienes cuenta? Regístrate aquí" : "¿Ya tienes una cuenta? Conéctate"),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    if (_savedProfiles.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        "Cuentas detectadas en este dispositivo", 
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade600)
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children: _savedProfiles.map((profile) {
                          final firstLetter = profile['name'] != null && profile['name']!.isNotEmpty 
                              ? profile['name']![0].toUpperCase() 
                              : "U";
                          return ActionChip(
                            avatar: CircleAvatar(child: Text(firstLetter, style: const TextStyle(fontSize: 10))),
                            label: Text(profile['name']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: () {
                              setState(() => _displayName = profile['name']!);
                              widget.onAuthChanged(profile['id']!);
                              _fetchRanking();
                            },
                          );
                        }).toList(),
                      ),
                    ],

                    const SizedBox(height: 28),
                    _buildRankingSection(theme),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 16),
                CircleAvatar(
                  radius: 36,
                  backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
                  child: Icon(Icons.person, size: 50, color: theme.primaryColor),
                ),
                const SizedBox(height: 12),
                Text(_displayName, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.primaryColor)),
                const SizedBox(height: 12),
                StreakBadge(streakCount: widget.streakCount),
                const SizedBox(height: 20),
                Card(
                  color: Colors.white,
                  elevation: 1,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatColumn("Racha Actual", "${widget.streakCount} días", "🔥", theme),
                        Container(height: 40, width: 1, color: Colors.grey.withValues(alpha: 0.3)),
                        _buildStatColumn("Racha Máxima", "${widget.maxStreak} días", "👑", theme),
                        Container(height: 40, width: 1, color: Colors.grey.withValues(alpha: 0.3)),
                        _buildStatColumn("Total Leídos", "${widget.totalRead} cap.", "📖", theme),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Tu constancia esta semana", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.primaryColor)),
                ),
                const SizedBox(height: 12),
                WeeklyProgressChart(weeklyProgress: widget.userWeeklyProgress),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    minimumSize: const Size.fromHeight(45),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    await supabase.auth.signOut();
                    widget.onLogout();
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text("Cerrar Sesión"),
                ),
                const SizedBox(height: 28),
                _buildRankingSection(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRankingSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 24),
                const SizedBox(width: 8),
                Text(
                  "Tabla de Posiciones",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.primaryColor),
                ),
              ],
            ),
            IconButton(
              icon: Icon(Icons.refresh_rounded, color: theme.primaryColor, size: 22),
              onPressed: _fetchRanking,
              tooltip: "Actualizar",
            ),
          ],
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _rankingFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24.0),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "No se pudo cargar el ranking: ${snapshot.error}",
                  style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              );
            }

            final rankingList = snapshot.data ?? [];

            if (rankingList.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Icon(Icons.military_tech_outlined, size: 36, color: Colors.grey.shade400),
                    const SizedBox(height: 6),
                    Text(
                      "Aún no hay puntajes registrados.",
                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "¡Completa un cuestionario diario para aparecer de primero!",
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            return Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              color: Colors.white,
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: rankingList.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = rankingList[index];
                  final profile = item['profiles'] as Map<String, dynamic>?;
                  final userName = profile?['full_name'] ?? 'Anónimo';
                  final correct = item['correct_answers'] ?? 0;
                  final total = item['total_questions'] ?? 0;
                  final timeSec = item['time_seconds'] ?? 0;
                  final readingTitle = item['reading_title'] ?? '';

                  Color? medalColor;
                  Widget rankBadge;

                  if (index == 0) {
                    medalColor = const Color(0xFFFFD700);
                  } else if (index == 1) {
                    medalColor = const Color(0xFFC0C0C0);
                  } else if (index == 2) {
                    medalColor = const Color(0xFFCD7F32);
                  }

                  if (medalColor != null) {
                    rankBadge = CircleAvatar(
                      radius: 14,
                      backgroundColor: medalColor,
                      child: Text(
                        "${index + 1}",
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    );
                  } else {
                    rankBadge = Text(
                      "#${index + 1}",
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                    );
                  }

                  return ListTile(
                    dense: true,
                    leading: Container(
                      width: 32,
                      alignment: Alignment.center,
                      child: rankBadge,
                    ),
                    title: Text(
                      userName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: Text(
                      "$readingTitle • ${_formatTime(timeSec)}",
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "🎯 $correct / $total",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.primaryColor,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatColumn(String label, String value, String icon, ThemeData theme) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.primaryColor)),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }
}