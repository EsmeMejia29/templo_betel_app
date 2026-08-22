import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../main.dart';
import '../services/devotional_service.dart';

class AIService {
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const String _model = 'gemini-3.6-flash';

  static String _limpiarJson(String rawText) {
    String clean = rawText.replaceAll(RegExp(r'```json\s*'), '').replaceAll(RegExp(r'```\s*'), '').trim();
    final int startIndex = clean.indexOf('{');
    final int endIndex = clean.lastIndexOf('}');
    if (startIndex != -1 && endIndex != -1 && endIndex >= startIndex) {
      clean = clean.substring(startIndex, endIndex + 1);
    }
    return clean;
  }

  static Future<Map<String, String>> extraerVersiculoClave(String chapterContent) async {
    if (_apiKey.isEmpty) {
      return {'versiculo': '', 'referencia': '', 'error': 'API Key no configurada.'};
    }

    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$_apiKey',
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
        final String rawText = jsonResponse['candidates'][0]['content']['parts'][0]['text'] ?? '';
        final String cleanJson = _limpiarJson(rawText);
        final Map<String, dynamic> data = jsonDecode(cleanJson);

        return {
          'versiculo': data['versiculo']?.toString() ?? '',
          'referencia': data['referencia']?.toString() ?? '',
          'error': '', 
        };
      } else {
        return {
          'versiculo': '',
          'referencia': '',
          'error': 'Error Gemini (${response.statusCode}): ${response.body}'
        };
      }
    } catch (e) {
      return {
        'versiculo': '',
        'referencia': '',
        'error': '$e'
      };
    }
  }

  static Future<Map<String, dynamic>> generarCuestionario(String chapterContent, String bookAndChapter) async {
    if (_apiKey.isEmpty) {
      return {'preguntas': [], 'error': 'API Key no configurada en GEMINI_API_KEY.'};
    }

    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$_apiKey',
      );

      final prompt = """
Eres un maestro bíblico didáctico y divertido. Crea un cuestionario de recapitulación de 3 preguntas de opción múltiple basado exclusivamente en el siguiente texto de la Biblia correspondiente a $bookAndChapter.

Reglas estrictas:
1. Cada pregunta debe tener exactamente 4 opciones de respuesta.
2. Indica en 'respuesta_correcta' el índice numérico (0, 1, 2 o 3) de la opción que es correcta.
3. Añade una 'explicacion' breve explicando por qué esa es la respuesta según el texto bíblico.
4. Devuelve única y estrictamente un objeto JSON con este formato sin explicaciones ni markdown:
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
        final String rawText = jsonResponse['candidates'][0]['content']['parts'][0]['text'] ?? '';
        final String cleanJson = _limpiarJson(rawText);
        final Map<String, dynamic> data = jsonDecode(cleanJson);

        return {
          'preguntas': data['preguntas'] ?? [],
          'error': '',
        };
      } else {
        return {
          'preguntas': [],
          'error': 'Error Gemini (${response.statusCode}): ${response.body}'
        };
      }
    } catch (e) {
      return {
        'preguntas': [],
        'error': '$e'
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
  bool _isLoadingChapter = false;
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

    setState(() {
      _isLoadingChapter = true;
      _isLoadingQuiz = true;
      _bookController.clear();
      _contentController.clear();
      _verseController.clear();
      _verseRefController.clear();
      _eventController.clear();
      _generatedQuiz = null;
    });

    try {
      String? libroYCapituloFirebase;

      final planMes = await _devotionalService.leerPlanMes(fecha.year, fecha.month);
      if (planMes != null) {
        final diaStr = fecha.day.toString();
        final diaPadded = fecha.day.toString().padLeft(2, '0');

        final dynamic lecturaDia = planMes[diaStr] ??
            planMes[diaPadded] ??
            (planMes['dias'] is Map ? (planMes['dias'][diaStr] ?? planMes['dias'][diaPadded]) : null) ??
            (planMes['days'] is Map ? (planMes['days'][diaStr] ?? planMes['days'][diaPadded]) : null);

        if (lecturaDia != null) {
          if (lecturaDia is String) {
            libroYCapituloFirebase = lecturaDia;
          } else if (lecturaDia is Map) {
            libroYCapituloFirebase = lecturaDia['lectura'] ?? lecturaDia['book_and_chapter'] ?? lecturaDia['capitulo'];
          }
        }
      }

      final responseSupabase = await supabase
          .from('readings')
          .select()
          .eq('date', formattedDate)
          .maybeSingle();

      if (!mounted) return;

      if (responseSupabase != null) {
        _isUpdating = true;
        _bookController.text = libroYCapituloFirebase ?? responseSupabase['book_and_chapter'] ?? '';
        _verseController.text = responseSupabase['daily_verse'] ?? '';
        _verseRefController.text = responseSupabase['daily_verse_ref'] ?? '';
        _eventController.text = responseSupabase['special_event'] ?? '';
        _contentController.text = responseSupabase['chapter_content'] ?? '';
        _generatedQuiz = responseSupabase['quiz'] as List<dynamic>?;
      } else {
        _isUpdating = false;
        if (libroYCapituloFirebase != null) {
          _bookController.text = libroYCapituloFirebase;
        }
      }

      String textoFirebase = '';
      if (_bookController.text.trim().isNotEmpty) {
        textoFirebase = await _obtenerCapituloFirebase(_bookController.text.trim());
      } else {
        setState(() => _isLoadingChapter = false);
      }

      final String textoFinal = textoFirebase.isNotEmpty ? textoFirebase : _contentController.text.trim();
      final String libroFinal = _bookController.text.trim();

      if (_verseController.text.trim().isEmpty && textoFinal.isNotEmpty && libroFinal.isNotEmpty) {
        await _autocompletarVersiculoSilencioso(textoFinal, libroFinal, formattedDate);
      }

      if (_generatedQuiz == null || _generatedQuiz!.isEmpty) {
        if (textoFinal.isNotEmpty && libroFinal.isNotEmpty) {
          await _generarYAutoguardarQuiz(textoFinal, libroFinal, formattedDate);
        } else {
          setState(() => _isLoadingQuiz = false);
        }
      } else {
        setState(() => _isLoadingQuiz = false);
      }

    } catch (e) {
      debugPrint("Error al sincronizar fecha: $e");
      if (mounted) {
        setState(() {
          _isLoadingChapter = false;
          _isLoadingQuiz = false;
        });
      }
    }
  }

  Future<String> _obtenerCapituloFirebase(String rawBookAndChapter) async {
    setState(() => _isLoadingChapter = true);
    String textoEncontrado = '';

    try {
      final match = RegExp(r'^(.*?)\s*(\d+)(?::.*)?$').firstMatch(rawBookAndChapter.trim());
      if (match != null) {
        final libro = match.group(1)?.trim() ?? '';
        final capitulo = int.tryParse(match.group(2) ?? '1') ?? 1;

        final doc = await _devotionalService.leerCapitulo(libro, capitulo);
        if (mounted && doc != null) {
          String? texto;
          if (doc.containsKey('content')) texto = doc['content']?.toString();
          else if (doc.containsKey('texto')) texto = doc['texto']?.toString();
          else if (doc.containsKey('chapter_content')) texto = doc['chapter_content']?.toString();
          else if (doc.containsKey('text')) texto = doc['text']?.toString();
          else if (doc.containsKey('versiculos') || doc.containsKey('verses')) {
            final lista = (doc['versiculos'] ?? doc['verses']) as List?;
            texto = lista?.join('\n');
          }

          if (texto != null && texto.isNotEmpty) {
            textoEncontrado = texto;
            _contentController.text = texto;
          }
        }
      }
    } catch (e) {
      debugPrint("Error obteniendo capítulo de Firebase: $e");
    } finally {
      if (mounted) setState(() => _isLoadingChapter = false);
    }
    return textoEncontrado;
  }

  Future<void> _autocompletarVersiculoSilencioso(String chapterText, String bookAndChapter, String formattedDate) async {
    if (chapterText.trim().isEmpty) return;

    setState(() => _isLoadingAI = true);

    try {
      final resultado = await AIService.extraerVersiculoClave(chapterText);

      if (!mounted) return;

      final versiculo = resultado['versiculo'] ?? '';
      final referencia = resultado['referencia'] ?? '';

      if (versiculo.isNotEmpty && referencia.isNotEmpty) {
        setState(() {
          _verseController.text = versiculo;
          _verseRefController.text = referencia;
          _isLoadingAI = false;
        });

        await supabase.from('readings').upsert({
          'date': formattedDate,
          'book_and_chapter': bookAndChapter,
          'chapter_content': chapterText,
          'daily_verse': versiculo,
          'daily_verse_ref': referencia,
          'quiz': _generatedQuiz,
          if (_eventController.text.trim().isNotEmpty) 'special_event': _eventController.text.trim(),
        }, onConflict: 'date');
      } else {
        setState(() => _isLoadingAI = false);
      }
    } catch (e) {
      debugPrint("Error autogenerando versículo: $e");
      if (mounted) setState(() => _isLoadingAI = false);
    }
  }

  Future<void> _generarYAutoguardarQuiz(String chapterText, String bookAndChapter, String formattedDate) async {
    setState(() => _isLoadingQuiz = true);

    try {
      final resultado = await AIService.generarCuestionario(chapterText, bookAndChapter);
      final preguntas = resultado['preguntas'] as List? ?? [];
      final String errorMsg = resultado['error']?.toString() ?? '';

      if (!mounted) return;

      if (preguntas.isNotEmpty) {
        setState(() {
          _generatedQuiz = preguntas;
          _isLoadingQuiz = false;
        });

        await supabase.from('readings').upsert({
          'date': formattedDate,
          'book_and_chapter': bookAndChapter,
          'chapter_content': chapterText,
          'quiz': preguntas,
          if (_verseController.text.trim().isNotEmpty) 'daily_verse': _verseController.text.trim(),
          if (_verseRefController.text.trim().isNotEmpty) 'daily_verse_ref': _verseRefController.text.trim(),
          if (_eventController.text.trim().isNotEmpty) 'special_event': _eventController.text.trim(),
        }, onConflict: 'date');

        if (mounted) {
          messengerKey.currentState?.clearSnackBars();
          messengerKey.currentState?.showSnackBar(
            const SnackBar(
              content: Text('⚡ Cuestionario sincronizado con éxito.'),
              backgroundColor: Color(0xFF6C5CE7),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        setState(() => _isLoadingQuiz = false);
        if (errorMsg.isNotEmpty) {
          messengerKey.currentState?.clearSnackBars();
          messengerKey.currentState?.showSnackBar(
            SnackBar(
              content: Text('Aviso Quiz: $errorMsg'),
              backgroundColor: Colors.orangeAccent,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error generando quiz automático: $e");
      if (mounted) setState(() => _isLoadingQuiz = false);
    }
  }

  Future<void> _autocompletarVersiculoConIA() async {
    final text = _contentController.text.trim();

    if (text.isEmpty) {
      messengerKey.currentState?.clearSnackBars();
      messengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('No hay contenido disponible del capítulo para analizar.'),
          backgroundColor: Colors.orangeAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoadingAI = true);

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
              ? "🎉 ¡Lectura actualizada con éxito en la BD!"
              : "🎉 ¡Lectura publicada con éxito en la BD!"),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );

      await _cargarLecturaPorFecha(_selectedDate);

    } catch (e) {
      debugPrint("Error atrapado en base de datos: $e");

      messengerKey.currentState?.clearSnackBars();
      messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text("Error al guardar: $e"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
                      ? const Text("Esta fecha ya tiene registros. Se actualizarán.",
                          style: TextStyle(color: Colors.amber, fontSize: 12))
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
                decoration: InputDecoration(
                  labelText: 'Libro y Capítulo (Ej: 1 Reyes 18)',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.cloud_sync_outlined),
                    tooltip: 'Sincronizar capítulo desde Firebase',
                    onPressed: () async {
                      if (_bookController.text.trim().isNotEmpty) {
                        final txt = await _obtenerCapituloFirebase(_bookController.text.trim());
                        final formattedDate = _selectedDate.toIso8601String().split('T')[0];
                        final String finalTxt = txt.isNotEmpty ? txt : _contentController.text.trim();
                        if (finalTxt.isNotEmpty) {
                          if (_verseController.text.trim().isEmpty) {
                            await _autocompletarVersiculoSilencioso(finalTxt, _bookController.text.trim(), formattedDate);
                          }
                          await _generarYAutoguardarQuiz(finalTxt, _bookController.text.trim(), formattedDate);
                        }
                      }
                    },
                  ),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 16),
              if (_isLoadingChapter)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                TextFormField(
                  controller: _contentController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Contenido del Capítulo (desde Firebase)',
                    hintText: 'Se cargará automáticamente al elegir la fecha',
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
              Card(
                elevation: 0,
                color: const Color(0xFF6C5CE7).withOpacity(0.08),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.sports_esports_rounded, color: Color(0xFF6C5CE7), size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Cuestionario Interactivo',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            if (_isLoadingQuiz)
                              const Row(
                                children: [
                                  SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                                  SizedBox(width: 8),
                                  Text('Generando y guardando quiz con IA...',
                                      style: TextStyle(fontSize: 12, color: Colors.deepPurple)),
                                ],
                              )
                            else if (_generatedQuiz != null && _generatedQuiz!.isNotEmpty)
                              Text('${_generatedQuiz!.length} preguntas listas y sincronizadas ✅',
                                  style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 12))
                            else
                              const Text('El quiz se generará al cargar el capítulo',
                                  style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                      if (_generatedQuiz != null && _generatedQuiz!.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.visibility_rounded, color: Color(0xFF6C5CE7)),
                          tooltip: 'Previsualizar Cuestionario',
                          onPressed: () => _mostrarModalJuego(_generatedQuiz!, _bookController.text.trim()),
                        ),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, color: Color(0xFF6C5CE7)),
                        tooltip: 'Forzar generación de Quiz',
                        onPressed: _isLoadingQuiz
                            ? null
                            : () {
                                final txt = _contentController.text.trim();
                                final book = _bookController.text.trim();
                                final formattedDate = _selectedDate.toIso8601String().split('T')[0];
                                if (txt.isNotEmpty && book.isNotEmpty) {
                                  _generarYAutoguardarQuiz(txt, book, formattedDate);
                                }
                              },
                      ),
                    ],
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
                        _isUpdating ? 'ACTUALIZAR LECTURA EN BD' : 'PUBLICAR LECTURA EN BD 🚀',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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