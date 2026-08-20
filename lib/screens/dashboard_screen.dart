import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../main.dart';
import '../services/devotional_service.dart';

class AIService {
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');

  static Future<Map<String, String>> extraerVersiculoClave(String chapterContent) async {
    if (_apiKey.isEmpty) {
      return {'versiculo': '', 'referencia': '', 'error': 'API Key no configurada.'};
    }

    try {
      // Pasamos la clave directamente en el parámetro ?key=
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent?key=$_apiKey',
      );

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
        headers: {'Content-Type': 'application/json'},
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

  static Future<Map<String, dynamic>> generarCuestionario(String chapterContent, String bookAndChapter) async {
    if (_apiKey.isEmpty) {
      return {'preguntas': [], 'error': 'API Key no configurada.'};
    }

    try {
      // Pasamos la clave directamente en el parámetro ?key=
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent?key=$_apiKey',
      );

      final prompt = """
Eres un maestro bíblico didáctico y divertido. Crea un cuestionario de recapitulación de 3 preguntas de opción múltiple basado exclusivamente en el siguiente texto de la Biblia correspondiente a $bookAndChapter.

Reglas estrictas:
1. Cada pregunta debe tener exactamente 4 opciones de respuesta.
2. Indica en 'respuesta_correcta' el índice numérico (0, 1, 2 o 3) de la opción que es correcta.
3. Añade una 'explicacion' breve explicando por qué esa es la respuesta según el texto bíblico.
4. Devuelve única y estrictamente un objeto JSON con este formato (sin markdown adicional):
{
  "preguntas": [
    {
      "pregunta": "¿Texto de la pregunta?",
      "opciones": ["Opción A", "Opción B", "Opción C", "Opción D"],
      "respuesta_correcta": 0,
      "explicacion": "Breve explicación basada en el capítulo."
    }
  ]
}

Texto del capítulo bíblico:
$chapterContent
""";

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
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
          'preguntas': data['preguntas'] ?? [],
          'error': '',
        };
      } else {
        return {
          'preguntas': [],
          'error': 'Código ${response.statusCode}: ${response.body}'
        };
      }
    } catch (e) {
      return {
        'preguntas': [],
        'error': 'Error al generar juego: $e'
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

  final DevotionalService _devotionalService = DevotionalService();

  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;
  bool _isLoadingAI = false;
  bool _isLoadingQuiz = false;
  bool _isUpdating = false;
  List<dynamic>? _generatedQuiz;

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
          _generatedQuiz = response['quiz'] as List<dynamic>?;
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
    _generatedQuiz = null;
    
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

  Future<void> _generarYGuardarJuego() async {
    final rawBookAndChapter = _bookController.text.trim();

    if (rawBookAndChapter.isEmpty && _contentController.text.trim().isEmpty) {
      messengerKey.currentState?.clearSnackBars();
      messengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Ingresa el Libro y Capítulo (ej: 1 Reyes 18) o el contenido del capítulo.'),
          backgroundColor: Colors.orangeAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoadingQuiz = true);

    String textoCapitulo = '';
    String tituloLectura = rawBookAndChapter.isEmpty ? 'Capítulo' : rawBookAndChapter;

    try {
      final partes = rawBookAndChapter.split(RegExp(r'\s+'));
      if (partes.length >= 2) {
        final numeroCap = int.tryParse(partes.last);
        final nombreLibro = partes.sublist(0, partes.length - 1).join(' ');

        if (numeroCap != null && nombreLibro.isNotEmpty) {
          final docFirebase = await _devotionalService.leerCapitulo(nombreLibro, numeroCap);
          if (docFirebase != null && docFirebase['text'] != null && docFirebase['text'].toString().isNotEmpty) {
            textoCapitulo = docFirebase['text'].toString();
          }
        }
      }
    } catch (e) {
      debugPrint("No se pudo obtener de Firebase BD: $e");
    }

    if (textoCapitulo.isEmpty) {
      textoCapitulo = _contentController.text.trim();
    }

    if (textoCapitulo.isEmpty) {
      if (!mounted) return;
      setState(() => _isLoadingQuiz = false);
      messengerKey.currentState?.clearSnackBars();
      messengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('No se encontró el capítulo en la BD ni en el campo de texto.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final resultado = await AIService.generarCuestionario(textoCapitulo, tituloLectura);

    if (!mounted) return;
    setState(() => _isLoadingQuiz = false);

    if (resultado['error'] != null && resultado['error'].toString().isNotEmpty) {
      messengerKey.currentState?.clearSnackBars();
      messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Error: ${resultado['error']}'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final List preguntas = resultado['preguntas'] as List? ?? [];
    if (preguntas.isEmpty) {
      messengerKey.currentState?.clearSnackBars();
      messengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('No se pudieron generar preguntas para este capítulo.')),
      );
      return;
    }

    setState(() {
      _generatedQuiz = preguntas;
    });

    _mostrarModalJuego(preguntas, tituloLectura);
  }

  void _mostrarModalJuego(List preguntas, String libroCapitulo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return _QuizViewerModal(preguntas: preguntas, titulo: libroCapitulo);
      },
    );
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
        'quiz': _generatedQuiz,
      }, onConflict: 'date');

      messengerKey.currentState?.clearSnackBars();
      messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(fueActualizacion 
              ? "🎉 ¡Lectura y juego actualizados con éxito en la BD!" 
              : "🎉 ¡Lectura y juego publicados con éxito en la BD!"),
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
                  labelText: 'Libro y Capítulo (Ej: 1 Reyes 18)',
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
              const SizedBox(height: 30),
              const Divider(),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Dinámicas & Recapitulación',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (_generatedQuiz != null && _generatedQuiz!.isNotEmpty)
                    Chip(
                      backgroundColor: Colors.green.shade50,
                      label: Text('${_generatedQuiz!.length} preguntas listas ✅', style: TextStyle(color: Colors.green.shade800, fontSize: 12)),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Genera un cuestionario interactivo con IA a partir de la información del capítulo en la BD.',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C5CE7),
                    foregroundColor: Colors.white,
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoadingQuiz ? null : _generarYGuardarJuego,
                  icon: _isLoadingQuiz
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.sports_esports_rounded),
                  label: Text(
                    _isLoadingQuiz ? 'Consultando BD y creando juego...' : 'Crear juego sobre el capítulo 🎮',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _isSaving
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isUpdating ? Colors.amber[800] : theme.primaryColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _saveReading,
                      icon: Icon(_isUpdating ? Icons.sync_rounded : Icons.rocket_launch_rounded),
                      label: Text(
                        _isUpdating ? 'ACTUALIZAR LECTURA Y JUEGO EN BD' : 'PUBLICAR LECTURA Y JUEGO EN BD 🚀', 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)
                      ),
                    ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuizViewerModal extends StatefulWidget {
  final List preguntas;
  final String titulo;

  const _QuizViewerModal({required this.preguntas, required this.titulo});

  @override
  State<_QuizViewerModal> createState() => _QuizViewerModalState();
}

class _QuizViewerModalState extends State<_QuizViewerModal> {
  final Map<int, int> _respuestasSeleccionadas = {};
  int _aciertos = 0;
  bool _revisado = false;

  void _evaluarRespuestas() {
    int total = 0;
    for (int i = 0; i < widget.preguntas.length; i++) {
      final correcta = widget.preguntas[i]['respuesta_correcta'] ?? 0;
      if (_respuestasSeleccionadas[i] == correcta) {
        total++;
      }
    }
    setState(() {
      _aciertos = total;
      _revisado = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Cuestionario: ${widget.titulo}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          if (_revisado)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _aciertos == widget.preguntas.length ? Colors.green[50] : Colors.amber[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _aciertos == widget.preguntas.length ? Colors.green : Colors.amber,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _aciertos == widget.preguntas.length ? Icons.celebration : Icons.stars,
                    color: _aciertos == widget.preguntas.length ? Colors.green : Colors.amber[800],
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '¡Puntaje obtenido: $_aciertos / ${widget.preguntas.length}!',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
            ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: widget.preguntas.length,
              itemBuilder: (context, index) {
                final item = widget.preguntas[index];
                final List opciones = item['opciones'] ?? [];
                final int correcta = item['respuesta_correcta'] ?? 0;
                final seleccionada = _respuestasSeleccionadas[index];

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${index + 1}. ${item['pregunta']}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 10),
                        ...List.generate(opciones.length, (opcIndex) {
                          Color? colorFondo;
                          if (_revisado) {
                            if (opcIndex == correcta) {
                              colorFondo = Colors.green.withOpacity(0.2);
                            } else if (seleccionada == opcIndex) {
                              colorFondo = Colors.red.withOpacity(0.2);
                            }
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: colorFondo,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: seleccionada == opcIndex
                                    ? const Color(0xFF6C5CE7)
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: RadioListTile<int>(
                              dense: true,
                              value: opcIndex,
                              groupValue: _respuestasSeleccionadas[index],
                              title: Text(opciones[opcIndex].toString()),
                              onChanged: _revisado
                                  ? null
                                  : (val) {
                                      setState(() {
                                        _respuestasSeleccionadas[index] = val!;
                                      });
                                    },
                            ),
                          );
                        }),
                        if (_revisado && item['explicacion'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              '💡 ${item['explicacion']}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[700], fontStyle: FontStyle.italic),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5CE7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _respuestasSeleccionadas.length < widget.preguntas.length
                  ? null
                  : (_revisado ? () => Navigator.pop(context) : _evaluarRespuestas),
              child: Text(
                _revisado ? 'Cerrar Juego' : 'Comprobar Respuestas',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}