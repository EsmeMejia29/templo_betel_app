import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';

class RecuperarContraScreen extends StatefulWidget {
  const RecuperarContraScreen({super.key});

  @override
  State<RecuperarContraScreen> createState() => _RecuperarContraScreenState();
}

class _RecuperarContraScreenState extends State<RecuperarContraScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  DateTime? _selectedBirthDate;
  bool _isLoading = false;
  bool _userVerified = false;
  String? _matchedProfileId;

  @override
  void dispose() {
    _phoneController.dispose();
    _birthDateController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _selectBirthDate(BuildContext context) async {
    final DateTime initialDate = _selectedBirthDate ?? DateTime(2005, 1, 1);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      helpText: 'SELECCIONA TU FECHA DE NACIMIENTO',
    );

    if (picked != null) {
      setState(() {
        _selectedBirthDate = picked;
        final day = picked.day.toString().padLeft(2, '0');
        final month = picked.month.toString().padLeft(2, '0');
        _birthDateController.text = "$day/$month/${picked.year}";
      });
    }
  }

  // Paso 1: Validar teléfono y fecha de nacimiento
  Future<void> _verifyIdentity() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final phone = _phoneController.text.trim();
    final formattedBirthDate =
        "${_selectedBirthDate!.year}-${_selectedBirthDate!.month.toString().padLeft(2, '0')}-${_selectedBirthDate!.day.toString().padLeft(2, '0')}";

    try {
      final response = await supabase
          .from('profiles')
          .select('id, full_name')
          .eq('phone', phone)
          .eq('birthdate', formattedBirthDate)
          .maybeSingle();

      if (response == null) {
        throw Exception(
            "Los datos no coinciden con ninguna cuenta registrada.");
      }

      setState(() {
        _userVerified = true;
        _matchedProfileId = response['id'];
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("¡Hola ${response['full_name']}! Ahora ingresa tu nueva contraseña."),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll("Exception:", "").trim()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Paso 2: Actualizar la contraseña en Supabase
  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Las contraseñas no coinciden"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await supabase.from('profiles').update({
        'password': _newPasswordController.text.trim(),
      }).eq('id', _matchedProfileId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("¡Contraseña actualizada con éxito! Ya puedes iniciar sesión."),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al cambiar contraseña: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Recuperar Contraseña"),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _userVerified ? Icons.lock_reset_rounded : Icons.security_rounded,
                        size: 54,
                        color: theme.primaryColor,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _userVerified
                            ? "Crea tu nueva contraseña"
                            : "Verifica tu identidad",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: theme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _userVerified
                            ? "Ingresa y confirma tu nueva clave de acceso."
                            : "Ingresa el teléfono y fecha de nacimiento con los que te registraste.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 24),

                      if (!_userVerified) ...[
                        // Teléfono
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: "Número de Teléfono",
                            prefixIcon: Icon(Icons.phone),
                            border: OutlineInputBorder(),
                          ),
                          validator: (val) =>
                              val == null || val.trim().isEmpty
                                  ? "Ingresa tu número de teléfono"
                                  : null,
                        ),
                        const SizedBox(height: 16),

                        // Fecha de nacimiento
                        TextFormField(
                          controller: _birthDateController,
                          readOnly: true,
                          onTap: () => _selectBirthDate(context),
                          decoration: const InputDecoration(
                            labelText: "Fecha de Nacimiento",
                            prefixIcon: Icon(Icons.cake_outlined),
                            suffixIcon: Icon(Icons.calendar_today_rounded),
                            border: OutlineInputBorder(),
                            hintText: "DD/MM/AAAA",
                          ),
                          validator: (val) =>
                              val == null || val.trim().isEmpty
                                  ? "Selecciona tu fecha de nacimiento"
                                  : null,
                        ),
                        const SizedBox(height: 24),

                        _isLoading
                            ? const CircularProgressIndicator()
                            : ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.primaryColor,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: _verifyIdentity,
                                child: const Text(
                                  "Verificar Cuenta",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                      ] else ...[
                        // Nueva contraseña
                        TextFormField(
                          controller: _newPasswordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: "Nueva Contraseña",
                            prefixIcon: Icon(Icons.lock_outline),
                            border: OutlineInputBorder(),
                          ),
                          validator: (val) =>
                              val == null || val.length < 6
                                  ? "Mínimo 6 caracteres"
                                  : null,
                        ),
                        const SizedBox(height: 16),

                        // Confirmar contraseña
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: "Confirmar Contraseña",
                            prefixIcon: Icon(Icons.lock_outline),
                            border: OutlineInputBorder(),
                          ),
                          validator: (val) =>
                              val == null || val.length < 6
                                  ? "Mínimo 6 caracteres"
                                  : null,
                        ),
                        const SizedBox(height: 24),

                        _isLoading
                            ? const CircularProgressIndicator()
                            : ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.primaryColor,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: _updatePassword,
                                child: const Text(
                                  "Actualizar Contraseña",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}