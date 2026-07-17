import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../main.dart';

class AIService {
  static const String _apiKey = 'AQ.Ab8RN6I6HNLPWSul8y630Nb_YPA9qF9VgAXtBHqFZCP7xpGYig'; 
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent';

  static Future<Map<String, String>> extraerVersiculoClave(String chapterContent) async {
    try {
      final url = Uri.parse(_baseUrl);

      final prompt = """
Analiza el siguiente capítulo de la Biblia. Identifica el versículo más importante o representativo de todo el texto provisto.

Es estrictamente obligatorio que en la referencia incluyas el libro, el capítulo y el número exacto del versículo identificado (por ejemplo: "Génesis 1:1" o "1 Crónicas 1:34"). No omitas el número de versículo por ningún motivo.

Devuelve la respuesta única y estrictamente en este formato JSON:
{
  "versiculo": "Texto exacto del versículo seleccionado",
  "referencia": "Libro Capítulo:Versículo"
}

Texto del capítulo:
$chapterContent
""";

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-goog-api-key': _apiKey, 
        },
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        String rawText = jsonResponse['candidates'][0]['content']['parts'][0]['text'];

        final int startIndex = rawText.indexOf('{');
        final int endIndex = rawText.lastIndexOf('}');

        if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
          rawText = rawText.substring(startIndex, endIndex + 1);
        }

        final Map<String, dynamic> data = jsonDecode(rawText);

        return {
          'versiculo': data['versiculo'] ?? '',
          'referencia': data['referencia'] ?? '',
          'error': '', 
        };
      } else {
        return {
          'versiculo': '',
          'referencia': '',
          'error': 'Código ${response.statusCode}: ${response.body}'
        };
      }
    } catch (e) {
      return {
        'versiculo': '',
        'referencia': '',
        'error': 'Error local: $e'
      };
    }
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bookController = TextEditingController();
  final _verseController = TextEditingController();
  final _verseRefController = TextEditingController();
  final _contentController = TextEditingController();
  final _eventController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;
  bool _isLoadingAI = false;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _cargarLecturaPorFecha(_selectedDate);
  }

  @override
  void dispose() {
    _bookController.dispose();
    _verseController.dispose();
    _verseRefController.dispose();
    _contentController.dispose();
    _eventController.dispose();
    super.dispose();
  }

  Future<void> _cargarLecturaPorFecha(DateTime fecha) async {
    final String formattedDate = fecha.toIso8601String().split('T')[0];
    
    try {
      final response = await supabase
          .from('readings')
          .select()
          .eq('date', formattedDate)
          .maybeSingle();

      if (!mounted) return;

      if (response != null) {
        setState(() {
          _bookController.text = response['book_and_chapter'] ?? '';
          _verseController.text = response['daily_verse'] ?? '';
          _verseRefController.text = response['daily_verse_ref'] ?? '';
          _contentController.text = response['chapter_content'] ?? '';
          _eventController.text = response['special_event'] ?? '';
          _isUpdating = true;
        });
      } else {
        _limpiarFormulario(mantenerFecha: true);
      }
    } catch (e) {
      debugPrint("Error interno al recuperar fecha: $e");
    }
  }

  void _limpiarFormulario({required bool mantenerFecha}) {
    _bookController.clear();
    _verseController.clear();
    _verseRefController.clear();
    _contentController.clear();
    _eventController.clear();
    
    if (mounted) {
      setState(() {
        _isUpdating = false;
        if (!mantenerFecha) {
          _selectedDate = DateTime.now();
        }
      });
    }
  }

  Future<void> _autocompletarVersiculoConIA() async {
    final text = _contentController.text.trim();

    if (text.isEmpty) {
      messengerKey.currentState?.clearSnackBars();
      messengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Por favor, ingresa primero el contenido del capítulo.'),
          backgroundColor: Colors.orangeAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isLoadingAI = true;
    });

    final resultado = await AIService.extraerVersiculoClave(text);

    if (!mounted) return;

    setState(() {
      _isLoadingAI = false;
      
      if (resultado['error'] != null && resultado['error']!.isNotEmpty) {
        messengerKey.currentState?.clearSnackBars();
        messengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('Error de la IA: ${resultado['error']}'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      if (resultado['versiculo']!.isNotEmpty && resultado['referencia']!.isNotEmpty) {
        _verseController.text = resultado['versiculo']!;
        _verseRefController.text = resultado['referencia']!;
        
        messengerKey.currentState?.clearSnackBars();
        messengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('¡Versículo sugerido con éxito usando IA! 🧠✨'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  Future<void> _saveReading() async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) return;
    
    final bool fueActualizacion = _isUpdating;
    final String formattedDate = _selectedDate.toIso8601String().split('T')[0];

    setState(() => _isSaving = true);

    try {
      await supabase.from('readings').upsert({
        'date': formattedDate,
        'book_and_chapter': _bookController.text.trim(),
        'daily_verse': _verseController.text.trim(),
        'daily_verse_ref': _verseRefController.text.trim(),
        'chapter_content': _contentController.text.trim(),
        'special_event': _eventController.text.trim().isEmpty ? null : _eventController.text.trim(),
      }, onConflict: 'date');

      messengerKey.currentState?.clearSnackBars();
      messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(fueActualizacion 
              ? "🎉 ¡Lectura actualizada con éxito!" 
              : "🎉 ¡Lectura guardada con éxito!"),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        )
      );

      _limpiarFormulario(mantenerFecha: false);
      
      _cargarLecturaPorFecha(_selectedDate);

    } catch (e) {
      debugPrint("Error atrapado en base de datos: $e");

      messengerKey.currentState?.clearSnackBars();
      messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text("Error al guardar: $e"), 
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        )
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Panel de Administración')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isUpdating ? 'Editar Capítulos del Día' : 'Agregar Capítulos del Día',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                color: _isUpdating 
                    ? Colors.amber.withOpacity(0.1)
                    : theme.primaryColor.withOpacity(0.05),
                child: ListTile(
                  leading: Icon(_isUpdating ? Icons.edit_calendar : Icons.calendar_month),
                  title: Text("Fecha: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}"),
                  subtitle: _isUpdating 
                      ? const Text("Esta fecha ya tiene registros. Se actualizarán.", style: TextStyle(color: Colors.amber, fontSize: 12)) 
                      : null,
                  trailing: const Icon(Icons.edit),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2025),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() => _selectedDate = picked);
                      _cargarLecturaPorFecha(picked);
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bookController,
                decoration: const InputDecoration(
                  labelText: 'Libro y Capítulo (Ej: Deuteronomio 5)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contentController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Guía o Contenido del Capítulo',
                  hintText: 'Pega el texto aquí antes de presionar el botón de IA',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.deepPurple,
                    side: const BorderSide(color: Colors.deepPurple, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoadingAI ? null : _autocompletarVersiculoConIA,
                  icon: _isLoadingAI
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.deepPurple),
                        )
                      : const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: Text(
                    _isLoadingAI ? 'Analizando texto con IA...' : 'Analizar y sugerir versículo con IA',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 16),
              TextFormField(
                controller: _verseController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Versículo Clave (Sugerido por IA)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _verseRefController,
                decoration: const InputDecoration(
                  labelText: 'Referencia del Versículo (Sugerido por IA)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _eventController,
                decoration: const InputDecoration(
                  labelText: 'Actividad de la Iglesia (Opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              _isSaving
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isUpdating ? Colors.amber[800] : theme.primaryColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _saveReading,
                      icon: Icon(_isUpdating ? Icons.sync_rounded : Icons.save_rounded),
                      label: Text(
                        _isUpdating ? 'ACTUALIZAR LECTURA' : 'PUBLICAR LECTURA', 
                        style: const TextStyle(fontWeight: FontWeight.bold)
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}