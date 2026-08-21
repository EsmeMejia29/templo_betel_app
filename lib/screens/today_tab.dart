import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/reading_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TodayTab extends StatefulWidget {
  final DevotionalReading todayReading;
  final Function(DevotionalReading) onToggle;
  final int streakCount;
  final double currentFontSize;
  final ValueChanged<double> onFontSizeChanged;
  final VoidCallback? onGoToProfile;
  final bool isLoggedIn;
  final String? activeProfileId;

  const TodayTab({
    super.key,
    required this.todayReading,
    required this.onToggle,
    required this.streakCount,
    required this.currentFontSize,
    required this.onFontSizeChanged,
    this.onGoToProfile,
    required this.isLoggedIn,
    this.activeProfileId,
  });

  @override
  State<TodayTab> createState() => _TodayTabState();
}

class _TodayTabState extends State<TodayTab> {
  late FlutterTts _flutterTts;
  bool _isPlaying = false;

  static const List<String> _meses = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];

  static const List<String> _diasSemana = [
    'Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'
  ];

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  void _initTts() {
    _flutterTts = FlutterTts();
    _flutterTts.setLanguage("es");
    _flutterTts.setSpeechRate(0.5);
    _flutterTts.setVolume(1.0);
    _flutterTts.setPitch(1.0);

    _flutterTts.setStartHandler(() {
      setState(() => _isPlaying = true);
    });
    _flutterTts.setCompletionHandler(() {
      setState(() => _isPlaying = false);
    });
    _flutterTts.setErrorHandler((msg) {
      setState(() => _isPlaying = false);
    });
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  void _speakText(String text) async {
    if (text.isEmpty) return;

    String cleanText = text
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\d+'), '')
        .replaceAll(RegExp(r'[\$\#\_\@]'), '')
        .trim();

    if (_isPlaying) {
      await _flutterTts.stop();
      setState(() => _isPlaying = false);
    } else {
      await _flutterTts.speak(cleanText);
      setState(() => _isPlaying = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasEvent = widget.todayReading.specialEvent != null && widget.todayReading.specialEvent!.isNotEmpty;
    final hasVerse = widget.todayReading.dailyVerse != null && widget.todayReading.dailyVerse!.isNotEmpty;
    final hasContent = widget.todayReading.chapterContent != null && widget.todayReading.chapterContent!.isNotEmpty;
    final hasQuiz = widget.todayReading.quiz != null && widget.todayReading.quiz!.isNotEmpty;

    final readingDate = widget.todayReading.date;
    final nombreDia = _diasSemana[readingDate.weekday % 7]; 
    final nombreMes = _meses[readingDate.month - 1];
    final String formattedDate = "$nombreDia, ${readingDate.day} de $nombreMes".toUpperCase();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "PANEL DEVOCIONAL",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600, letterSpacing: 1.1),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formattedDate,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.primaryColor),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("🔥", style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      "${widget.streakCount} ${widget.streakCount == 1 ? 'DÍA' : 'DÍAS'}",
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [theme.primaryColor, theme.primaryColor.withOpacity(0.85)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.all(22.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.menu_book, color: Colors.white, size: 28),
                      const SizedBox(width: 10),
                      Text(
                        "LECTURA DE HOY",
                        style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.todayReading.bookAndChapter,
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                  ),
                  if (hasEvent) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        widget.todayReading.specialEvent!,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.todayReading.isCompleted ? Colors.green.shade600 : Colors.white,
                      foregroundColor: widget.todayReading.isCompleted ? Colors.white : theme.primaryColor,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: () => widget.onToggle(widget.todayReading),
                    icon: Icon(widget.todayReading.isCompleted ? Icons.check_circle : Icons.bookmark_add_outlined),
                    label: Text(
                      widget.todayReading.isCompleted ? "¡COMPLETADO!" : "MARCAR COMO LEÍDO",
                      style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (hasVerse) ...[
            Text(
              "Versículo Clave",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.primaryColor),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "\"${widget.todayReading.dailyVerse}\"",
                      style: TextStyle(fontSize: 15, fontStyle: FontStyle.italic, color: Colors.grey.shade800, height: 1.4),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        widget.todayReading.dailyVerseRef ?? "",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.primaryColor),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
          if (hasContent) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Guía del Capítulo",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.primaryColor),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _isPlaying ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded,
                        color: _isPlaying ? Colors.redAccent : theme.primaryColor,
                        size: 26,
                      ),
                      tooltip: _isPlaying ? "Detener" : "Escuchar",
                      onPressed: () => _speakText(widget.todayReading.chapterContent!),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.text_decrease_rounded, color: theme.primaryColor, size: 20),
                      onPressed: widget.currentFontSize > 12.0
                          ? () => widget.onFontSizeChanged(widget.currentFontSize - 2.0)
                          : null,
                    ),
                    IconButton(
                      icon: Icon(Icons.text_increase_rounded, color: theme.primaryColor, size: 20),
                      onPressed: widget.currentFontSize < 24.0
                          ? () => widget.onFontSizeChanged(widget.currentFontSize + 2.0)
                          : null,
                    ),
                  ],
                )
              ],
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
              color: Colors.grey.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.auto_stories, color: theme.primaryColor.withOpacity(0.7), size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.todayReading.chapterContent!,
                        textAlign: TextAlign.justify, 
                        style: TextStyle(
                          fontSize: widget.currentFontSize, 
                          color: Colors.grey.shade800, 
                          height: 1.6, 
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
          if (hasQuiz) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.primaryColor.withOpacity(0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.sports_esports_rounded, color: theme.primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        "¡Pon a prueba lo aprendido!",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: theme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Responde el cuestionario interactivo de este capítulo para recapitular tu devocional.",
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                  if (!widget.isLoggedIn) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade600),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lock_outline_rounded, size: 18, color: Colors.amber.shade900),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Debes iniciar sesión para jugar y guardar tu progreso en el ranking.",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.isLoggedIn ? theme.primaryColor : Colors.amber.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: widget.isLoggedIn
                          ? () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                ),
                                builder: (context) => _QuizViewerModal(
                                  preguntas: widget.todayReading.quiz!,
                                  titulo: widget.todayReading.bookAndChapter,
                                  activeProfileId: widget.activeProfileId,
                                ),
                              );
                            }
                          : () {
                              if (widget.onGoToProfile != null) {
                                widget.onGoToProfile!();
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Inicia sesión en tu perfil para registrar tu puntaje 🎯'),
                                  backgroundColor: Colors.orange,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                      icon: Icon(widget.isLoggedIn ? Icons.play_arrow_rounded : Icons.login_rounded),
                      label: Text(
                        widget.isLoggedIn ? "JUGAR CUESTIONARIO 🎯" : "INICIAR SESIÓN PARA JUGAR",
                        style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _QuizViewerModal extends StatefulWidget {
  final List<dynamic> preguntas;
  final String titulo;
  final String? activeProfileId;

  const _QuizViewerModal({
    required this.preguntas,
    required this.titulo,
    this.activeProfileId,
  });

  @override
  State<_QuizViewerModal> createState() => _QuizViewerModalState();
}

class _QuizViewerModalState extends State<_QuizViewerModal> {
  final Map<int, int> _respuestasSeleccionadas = {};
  int _aciertos = 0;
  bool _revisado = false;
  bool _isSaving = false;
  bool _hasSaved = false;

  late final DateTime _startTime;
  Duration _elapsedTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  void _evaluarRespuestas() {
    _elapsedTime = DateTime.now().difference(_startTime);
    int total = 0;
    for (int i = 0; i < widget.preguntas.length; i++) {
      final correcta = widget.preguntas[i]['respuesta_correcta'] ?? 0;
      if (_respuestasSeleccionadas[i] == correcta) total++;
    }
    setState(() {
      _aciertos = total;
      _revisado = true;
    });
  }

  Future<void> _guardarProgresoEnRanking() async {
    final profileId = widget.activeProfileId ?? Supabase.instance.client.auth.currentUser?.id;

    if (profileId == null || profileId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ No se detectó un usuario activo. Inicia sesión.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await Supabase.instance.client.from('quiz_rankings').insert({
        'profile_id': profileId,
        'reading_title': widget.titulo,
        'correct_answers': _aciertos,
        'total_questions': widget.preguntas.length,
        'time_seconds': _elapsedTime.inSeconds,
      });

      if (mounted) {
        setState(() {
          _hasSaved = true;
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Puntaje guardado en el ranking con éxito! 🏆'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error guardando en ranking: $e");
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
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
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          if (_revisado) ...[
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _aciertos == widget.preguntas.length ? Colors.green.shade50 : Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _aciertos == widget.preguntas.length ? Colors.green : Colors.amber.shade700,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        _aciertos == widget.preguntas.length ? Icons.celebration : Icons.stars,
                        color: _aciertos == widget.preguntas.length ? Colors.green.shade700 : Colors.amber.shade800,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '¡Puntaje: $_aciertos / ${widget.preguntas.length}!',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.timer_outlined, size: 18, color: Colors.grey.shade700),
                      const SizedBox(width: 4),
                      Text(
                        _formatDuration(_elapsedTime),
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey.shade800),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!_hasSaved)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.primaryColor,
                    side: BorderSide(color: theme.primaryColor),
                    minimumSize: const Size.fromHeight(40),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isSaving ? null : _guardarProgresoEnRanking,
                  icon: _isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.leaderboard_rounded, size: 18),
                  label: Text(
                    _isSaving ? 'Guardando...' : 'Guardar progreso para el ranking 🏆',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.check_circle, color: Colors.green, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Progreso registrado en el ranking',
                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ],
                ),
              ),
          ],
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
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
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
                          BorderSide borderSide = BorderSide(
                            color: seleccionada == opcIndex ? theme.primaryColor : Colors.grey.shade300,
                            width: seleccionada == opcIndex ? 1.5 : 1.0,
                          );

                          if (_revisado) {
                            if (opcIndex == correcta) {
                              colorFondo = Colors.green.withOpacity(0.15);
                              borderSide = const BorderSide(color: Colors.green, width: 1.5);
                            } else if (seleccionada == opcIndex) {
                              colorFondo = Colors.red.withOpacity(0.15);
                              borderSide = const BorderSide(color: Colors.redAccent, width: 1.5);
                            }
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: colorFondo,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.fromBorderSide(borderSide),
                            ),
                            child: RadioListTile<int>(
                              dense: true,
                              activeColor: theme.primaryColor,
                              value: opcIndex,
                              groupValue: _respuestasSeleccionadas[index],
                              title: Text(opciones[opcIndex].toString()),
                              onChanged: _revisado ? null : (val) => setState(() => _respuestasSeleccionadas[index] = val!),
                            ),
                          );
                        }),
                        if (_revisado && item['explicacion'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              '💡 ${item['explicacion']}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                                fontStyle: FontStyle.italic,
                              ),
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
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
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