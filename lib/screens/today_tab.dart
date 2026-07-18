import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_tts/flutter_tts.dart';
import '../models/reading_model.dart';
import 'dart:js' as js;
import 'package:flutter_tts/flutter_tts.dart';

class TodayTab extends StatefulWidget {
  final DevotionalReading todayReading;
  final Function(DevotionalReading) onToggle;
  final int streakCount;
  final double currentFontSize;
  final ValueChanged<double> onFontSizeChanged;

  const TodayTab({
    super.key,
    required this.todayReading,
    required this.onToggle,
    required this.streakCount,
    required this.currentFontSize,
    required this.onFontSizeChanged,
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
    if (!kIsWeb) {
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
  }

  @override
  void dispose() {
    if (kIsWeb) {
      _stopWebSpeech();
    } else {
      _flutterTts.stop();
    }
    super.dispose();
  }

  void _speakWebText(String text) {
    if (_isPlaying) {
      _stopWebSpeech();
    } else {
      final synth = js.context['speechSynthesis'];
      if (synth == null) return;

      synth.callMethod('cancel');

      final utteranceInterface = js.context['SpeechSynthesisUtterance'];
      if (utteranceInterface == null) return;

      final utterance = js.JsObject(utteranceInterface, [text]);
      utterance['lang'] = 'es-ES';
      utterance['rate'] = 0.95;

      utterance['onstart'] = js.allowInterop((_) {
        setState(() => _isPlaying = true);
      });
      utterance['onend'] = js.allowInterop((_) {
        setState(() => _isPlaying = false);
      });
      utterance['onerror'] = js.allowInterop((_) {
        setState(() => _isPlaying = false);
      });

      synth.callMethod('speak', [utterance]);
    }
  }

  void _stopWebSpeech() {
    js.context['speechSynthesis']?.callMethod('cancel');
    setState(() => _isPlaying = false);
  }

  void _speakText(String text) {
    if (text.isEmpty) return;

    String cleanText = text
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\d+'), '')
        .replaceAll(RegExp(r'[\$\#\_\@]'), '')
        .trim();

    if (kIsWeb) {
      _speakWebText(cleanText);
    } else {
      if (_isPlaying) {
        _flutterTts.stop();
        setState(() => _isPlaying = false);
      } else {
        _flutterTts.speak(cleanText);
        setState(() => _isPlaying = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasEvent = widget.todayReading.specialEvent != null && widget.todayReading.specialEvent!.isNotEmpty;
    final hasVerse = widget.todayReading.dailyVerse != null && widget.todayReading.dailyVerse!.isNotEmpty;
    final hasContent = widget.todayReading.chapterContent != null && widget.todayReading.chapterContent!.isNotEmpty;

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
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}