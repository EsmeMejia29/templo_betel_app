import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../main.dart';
import 'widgets/streak_badge.dart';
import 'widgets/weekly_chart.dart';

class ProfileScreen extends StatefulWidget {
  final int streakCount;
  final int totalRead;
  final List<bool> userWeeklyProgress; 
  final String? activeProfileId;
  final Function(String) onAuthChanged;
  final VoidCallback onLogout;

  const ProfileScreen({
    super.key, 
    required this.streakCount, 
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

  // Lista dinámica que almacenará los perfiles guardados localmente en este dispositivo
  List<Map<String, String>> _savedProfiles = [];

  @override
  void initState() {
    super.initState();
    _loadSavedProfilesLocal(); // Carga las cuentas recordadas al iniciar
    if (widget.activeProfileId != null) {
      _loadProfileData();
    }
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeProfileId != oldWidget.activeProfileId && widget.activeProfileId != null) {
      _loadProfileData();
    }
  }

  // Carga las cuentas que previamente iniciaron sesión en esta máquina/móvil
  Future<void> _loadSavedProfilesLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> rawList = prefs.getStringList('saved_profiles_keys') ?? [];
    
    List<Map<String, String>> profiles = [];
    for (String rawUser in rawList) {
      // El formato guardado es "id||name"
      final parts = rawUser.split('||');
      if (parts.length == 2) {
        profiles.add({'id': parts[0], 'name': parts[1]});
      }
    }
    setState(() {
      _savedProfiles = profiles;
    });
  }

  // Guarda una cuenta en el historial local tras un inicio de sesión exitoso
  Future<void> _saveProfileLocally(String id, String name) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> rawList = prefs.getStringList('saved_profiles_keys') ?? [];
    
    final String entry = "$id||$name";
    // Evitamos duplicar el mismo registro en la lista
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
          
      if (response != null && response['full_name'] != null) {
        setState(() {
          _displayName = response['full_name'];
        });
        // Si ya está adentro, nos aseguramos de que su cuenta quede recordada localmente
        _saveProfileLocally(widget.activeProfileId!, response['full_name']);
      }
    } catch (_) {}
  }

  Future<void> _handleAuth() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

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

        // Guardamos de forma automática en la memoria del dispositivo
        await _saveProfileLocally(response['id'], response['full_name']);

        widget.onAuthChanged(response['id']);
        setState(() {
          _displayName = response['full_name'];
        });
      } else {
        final insertResponse = await supabase.from('profiles').insert({
          'phone': phone,
          'password': password,
          'full_name': _nameController.text.trim(),
        }).select().single();

        // Guardamos de forma automática la cuenta recién creada
        await _saveProfileLocally(insertResponse['id'], insertResponse['full_name']);

        widget.onAuthChanged(insertResponse['id']);
        setState(() {
          _displayName = insertResponse['full_name'];
        });
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isLoginMode ? "Sesión iniciada" : "¡Registro completado al instante!"))
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll("Exception:", "")), backgroundColor: Colors.red)
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSessionActive = widget.activeProfileId != null;

    // VISTA 1: PANTALLA DE INGRESO / REGISTRO
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
                                  validator: (value) => value == null || value.isEmpty ? "Por favor ingresa tu nombre" : null,
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
                    
                    // SECCIÓN COMPLETAMENTE DINÁMICA: CUENTAS CAPTURADAS AUTOMÁTICAMENTE
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
                              // Dispara el login con el UUID legítimo recuperado de la BD en el pasado
                              widget.onAuthChanged(profile['id']!);
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // VISTA 2: PANEL DEL PERFIL ACTIVO
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
                        _buildStatColumn("Racha Máxima", "${widget.streakCount} días", "👑", theme),
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
                  ),
                  onPressed: widget.onLogout,
                  icon: const Icon(Icons.logout),
                  label: const Text("Cerrar Sesión"),
                )
              ],
            ),
          ),
        ),
      ),
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