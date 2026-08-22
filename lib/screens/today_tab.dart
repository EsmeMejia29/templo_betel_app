// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/reading_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/devotional_service.dart';

import 'dart:js' as js;

class _TextChunk {
  final String text;
  final int globalStartOffset;
  final List<RegExpMatch> localWords;
  _TextChunk(this.text, this.globalStartOffset, this.localWords);
}

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

  final DevotionalService _devotionalService = DevotionalService();
  String? _firebaseChapterContent;
  bool _isLoadingChapter = true;


  late FlutterTts _flutterTts;
  bool _isPlaying = false;
  bool _isPaused = false;
  bool _showPlayerBar = false;

  int _playSessionId = 0;

  // Velocidades calibradas para pronunciación natural
  int _speedIndex = 0;
  final List<String> _speedLabels = ["1.0x", "1.5x", "2.0x"];
  final List<double> _webSpeedRates = [1.0, 1.25, 1.45];
  final List<double> _nativeSpeedRates = [0.5, 0.65, 0.8];

  // Subrayado y posición
  int _currentWordStart = 0;
  int _currentWordEnd = 0;
  int _currentWordIndex = 0;
  double? _draggedWordIndex;
  List<RegExpMatch> _wordMatches = [];
  Timer? _highlightTimer;

  List<_TextChunk> _textChunks = [];
  int _currentChunkIndex = 0;
  String _cachedCleanText = "";

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
    _cargarCapituloFirebase();
  }

  @override
  void didUpdateWidget(covariant TodayTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.todayReading.bookAndChapter != widget.todayReading.bookAndChapter) {
      _stopAudio();
      _cachedCleanText = "";
      _firebaseChapterContent = null;
      _cargarCapituloFirebase();
    }
  }

  double get _currentRate => kIsWeb ? _webSpeedRates[_speedIndex] : _nativeSpeedRates[_speedIndex];

  void _initTts() {
    _flutterTts = FlutterTts();

    _flutterTts.setLanguage("es-US");
    _flutterTts.setVolume(1.0);
    _flutterTts.setPitch(1.0);
    _flutterTts.setSpeechRate(_currentRate);

    _flutterTts.setStartHandler(() {
      if (mounted) {
        setState(() {
          _isPlaying = true;
          _isPaused = false;
          _showPlayerBar = true;
        });
      }
    });

    _flutterTts.setCompletionHandler(() {
      if (!kIsWeb) {
        _stopAudio();
      }
    });

    _flutterTts.setCancelHandler(() {
      if (!kIsWeb && !_isPaused) _stopAudio();
    });

    _flutterTts.setErrorHandler((msg) {
      final errorStr = msg.toString().toLowerCase();
      if (errorStr.contains("interrupted") || errorStr.contains("canceled")) return;
      debugPrint("TTS Error: $msg");
      _stopAudio();
    });

    _flutterTts.setProgressHandler((String text, int start, int end, String word) {
      if (mounted && _isPlaying && !kIsWeb) {
        _onBoundaryHit(start);
      }
    });

    if (kIsWeb) {
      // Re-sincronización instantánea al inicio de cada oración
      js.context['flutterOnChunkStart'] = (int incomingSessionId, int chunkIndex) {
        if (mounted && _isPlaying && incomingSessionId == _playSessionId) {
          _startChunkHighlight(incomingSessionId, chunkIndex);
        }
      };

      // Si el navegador soporta onboundary, lo usa como respaldo de sincronía fina
      js.context['flutterOnWordBoundary'] = (int incomingSessionId, int globalCharIndex) {
        if (mounted && _isPlaying && incomingSessionId == _playSessionId) {
          _onBoundaryHit(globalCharIndex);
        }
      };

      js.context['flutterOnChunkEnd'] = (int incomingSessionId) {
        if (mounted && _isPlaying && incomingSessionId == _playSessionId) {
          _playNextChunk(incomingSessionId);
        }
      };

      try {
        js.context.callMethod('eval', [
          '''
          (function() {
            if (!('speechSynthesis' in window)) return;
            function warmUpVoices() {
              var voices = window.speechSynthesis.getVoices();
              if (voices.length > 0 && !window._cachedEsVoice) {
                for (var i = 0; i < voices.length; i++) {
                  if (voices[i].lang.indexOf('es') !== -1 && voices[i].localService) {
                    window._cachedEsVoice = voices[i];
                    break;
                  }
                }
                if (!window._cachedEsVoice) {
                  for (var i = 0; i < voices.length; i++) {
                    if (voices[i].lang.indexOf('es') !== -1) {
                      window._cachedEsVoice = voices[i];
                      break;
                    }
                  }
                }
              }
            }
            warmUpVoices();
            if (speechSynthesis.onvoiceschanged !== undefined) {
              speechSynthesis.onvoiceschanged = warmUpVoices;
            }
            var silentUtter = new SpeechSynthesisUtterance(' ');
            silentUtter.volume = 0.01;
            window.speechSynthesis.speak(silentUtter);
          })();
          '''
        ]);
      } catch (_) {}
    }
  }

  Future<void> _cargarCapituloFirebase() async {
    setState(() => _isLoadingChapter = true);

    try {
      final rawBookAndChapter = widget.todayReading.bookAndChapter.trim();
      debugPrint("🔍 [Firebase] Intentando buscar para: '$rawBookAndChapter'");

      // Extraer libro y capítulo tolerando referencias como "1 Juan 2", "Génesis 1" o "Mateo 5:1-10"
      final match = RegExp(r'^(.*?)\s*(\d+)(?::.*)?$').firstMatch(rawBookAndChapter);
      
      if (match != null) {
        final libro = match.group(1)?.trim() ?? '';
        final capitulo = int.tryParse(match.group(2) ?? '1') ?? 1;

        debugPrint("📖 [Firebase] Libro extraído: '$libro', Capítulo: $capitulo");

        final doc = await _devotionalService.leerCapitulo(libro, capitulo);
        
        debugPrint("📦 [Firebase] Documento recibido de Firestore: $doc");

        if (mounted && doc != null) {
          // Extraer el texto buscando todas las variantes posibles
          String? textoExtraido;

          if (doc.containsKey('content')) textoExtraido = doc['content']?.toString();
          else if (doc.containsKey('texto')) textoExtraido = doc['texto']?.toString();
          else if (doc.containsKey('chapter_content')) textoExtraido = doc['chapter_content']?.toString();
          else if (doc.containsKey('text')) textoExtraido = doc['text']?.toString();
          else if (doc.containsKey('versiculos') || doc.containsKey('verses')) {
            // Si viene en lista de versículos
            final lista = (doc['versiculos'] ?? doc['verses']) as List?;
            textoExtraido = lista?.join('\n');
          }

          if (textoExtraido != null && textoExtraido.isNotEmpty) {
            setState(() {
              _firebaseChapterContent = textoExtraido;
              _isLoadingChapter = false;
            });
            debugPrint("✅ [Firebase] Capítulo cargado exitosamente.");
            return;
          } else {
            debugPrint("⚠️ [Firebase] El documento existe pero no se encontró la clave de texto en: ${doc.keys}");
          }
        } else {
          debugPrint("❌ [Firebase] No se encontró el documento en Firestore (null / 404).");
        }
      } else {
        debugPrint("⚠️ [Firebase] No coincidió el RegExp con: '$rawBookAndChapter'");
      }
    } catch (e, stack) {
      debugPrint("💥 [Firebase Error]: $e");
      debugPrint("Stack: $stack");
    }

    if (mounted) {
      setState(() => _isLoadingChapter = false);
    }
  }

  void _onBoundaryHit(int globalCharIndex) {
    if (_wordMatches.isEmpty) return;

    int foundIdx = -1;
    for (int i = 0; i < _wordMatches.length; i++) {
      final m = _wordMatches[i];
      if (globalCharIndex >= m.start && globalCharIndex <= m.end) {
        foundIdx = i;
        break;
      } else if (m.start > globalCharIndex) {
        foundIdx = i;
        break;
      }
    }

    if (foundIdx != -1 && foundIdx != _currentWordIndex) {
      final m = _wordMatches[foundIdx];
      setState(() {
        _currentWordIndex = foundIdx;
        _currentWordStart = m.start;
        _currentWordEnd = m.end;
      });
    }
  }

  // Ejecuta la animación de subrayado palabra por palabra para la oración actual
  void _startChunkHighlight(int activeSessionId, int chunkIdx) {
    if (chunkIdx >= _textChunks.length) return;
    final chunk = _textChunks[chunkIdx];
    final words = chunk.localWords;
    if (words.isEmpty) return;

    _highlightTimer?.cancel();
    final double rate = _currentRate;
    final double msPerChar = 68.0 / rate;
    int localIdx = 0;

    void step() {
      if (!_isPlaying || activeSessionId != _playSessionId || localIdx >= words.length) {
        return;
      }

      final w = words[localIdx];
      final globalStart = chunk.globalStartOffset + w.start;
      final globalEnd = chunk.globalStartOffset + w.end;
      final wordText = chunk.text.substring(w.start, w.end);

      if (mounted) {
        // Encontrar índice global en la lista completa
        final gIdx = _wordMatches.indexWhere((m) => m.start == globalStart);
        setState(() {
          if (gIdx != -1) _currentWordIndex = gIdx;
          _currentWordStart = globalStart;
          _currentWordEnd = globalEnd;
        });
      }

      double durationMs = (wordText.length * msPerChar).clamp(160.0 / rate, 750.0 / rate);

      if (wordText.endsWith('.') || wordText.endsWith('!') || wordText.endsWith('?')) {
        durationMs += (260.0 / rate);
      } else if (wordText.endsWith(',') || wordText.endsWith(';') || wordText.endsWith(':')) {
        durationMs += (130.0 / rate);
      }

      localIdx++;
      _highlightTimer = Timer(Duration(milliseconds: durationMs.round()), step);
    }

    step();
  }

  void _stopAudio() {
    _playSessionId++;
    _highlightTimer?.cancel();
    _highlightTimer = null;
    _textChunks.clear();
    _currentChunkIndex = 0;

    if (kIsWeb) {
      try {
        js.context.callMethod('eval', [
          'if (window.speechSynthesis) { window.speechSynthesis.cancel(); }'
        ]);
      } catch (_) {}
    } else {
      _flutterTts.stop();
    }

    if (mounted) {
      setState(() {
        _isPlaying = false;
        _isPaused = false;
        _showPlayerBar = false;
        _currentWordStart = 0;
        _currentWordEnd = 0;
        _currentWordIndex = 0;
        _draggedWordIndex = null;
      });
    }
  }

  void _pauseAudio() {
    _playSessionId++;
    _highlightTimer?.cancel();
    _highlightTimer = null;

    if (kIsWeb) {
      try {
        js.context.callMethod('eval', [
          'if (window.speechSynthesis) { window.speechSynthesis.cancel(); }'
        ]);
      } catch (_) {}
    } else {
      _flutterTts.stop();
    }

    if (mounted) {
      setState(() {
        _isPlaying = false;
        _isPaused = true;
      });
    }
  }

  void _cycleSpeed() {
    setState(() {
      _speedIndex = (_speedIndex + 1) % _speedLabels.length;
    });

    _flutterTts.setSpeechRate(_currentRate);

    if (_isPlaying) {
      _resumeAudioFromIndex(_currentWordIndex);
    }
  }

  void _playNextChunk(int activeSessionId) {
    if (activeSessionId != _playSessionId) return;

    if (_currentChunkIndex < _textChunks.length && _isPlaying) {
      final chunkIdx = _currentChunkIndex;
      final chunk = _textChunks[chunkIdx];
      _currentChunkIndex++;

      if (kIsWeb) {
        _speakDirectWeb(chunk.text, activeSessionId, chunkIdx, chunk.globalStartOffset);
      } else {
        _flutterTts.speak(chunk.text);
      }
    } else {
      _stopAudio();
    }
  }

  void _speakDirectWeb(String text, int activeSessionId, int chunkIdx, int chunkStartOffset) {
    try {
      final escaped = text
          .replaceAll(r'\', r'\\')
          .replaceAll('"', r'\"')
          .replaceAll("'", r"\'")
          .replaceAll('\n', ' ');
      final rate = _currentRate;

      js.context.callMethod('eval', [
        '''
        (function() {
          if (!('speechSynthesis' in window)) return;
          window.speechSynthesis.cancel();
          window.speechSynthesis.resume();
          
          var utter = new SpeechSynthesisUtterance("$escaped");
          utter.lang = 'es-ES';
          utter.rate = $rate;
          utter.pitch = 1.0;
          
          if (!window._cachedEsVoice) {
            var voices = window.speechSynthesis.getVoices();
            for (var i = 0; i < voices.length; i++) {
              if (voices[i].lang.indexOf('es') !== -1 && voices[i].localService) {
                window._cachedEsVoice = voices[i];
                break;
              }
            }
            if (!window._cachedEsVoice) {
              for (var i = 0; i < voices.length; i++) {
                if (voices[i].lang.indexOf('es') !== -1) {
                  window._cachedEsVoice = voices[i];
                  break;
                }
              }
            }
          }
          if (window._cachedEsVoice) {
            utter.voice = window._cachedEsVoice;
          }
          
          utter.onstart = function() {
            if (window.flutterOnChunkStart) window.flutterOnChunkStart($activeSessionId, $chunkIdx);
          };

          utter.onboundary = function(e) {
            var idx = (e.charIndex !== undefined) ? e.charIndex : 0;
            if (window.flutterOnWordBoundary) {
              window.flutterOnWordBoundary($activeSessionId, $chunkStartOffset + idx);
            }
          };

          utter.onend = function() {
            if (window.flutterOnChunkEnd) window.flutterOnChunkEnd($activeSessionId);
          };

          utter.onerror = function(e) {
            if (e.error !== 'interrupted' && e.error !== 'canceled') {
              if (window.flutterOnChunkEnd) window.flutterOnChunkEnd($activeSessionId);
            }
          };
          
          window.speechSynthesis.speak(utter);
        })();
        '''
      ]);
    } catch (e) {
      debugPrint("Error speak web directo: $e");
    }
  }

  void _speakOrToggle(String rawText) {
    if (rawText.isEmpty) return;

    if (_isPlaying) {
      _pauseAudio();
    } else if (_isPaused) {
      _resumeAudioFromIndex(_currentWordIndex);
    } else {
      _startAudioFromBeginning(rawText);
    }
  }

  void _startAudioFromBeginning(String rawText) {
    _cachedCleanText = rawText;
    _wordMatches = RegExp(r'\S+').allMatches(_cachedCleanText).toList();
    _currentWordIndex = 0;

    _resumeAudioFromIndex(0);
  }

  // Divide el texto preservando offsets globales exactos
  List<_TextChunk> _buildSafeChunks(String fullText, int startOffset) {
    final String text = fullText.substring(startOffset);
    final List<_TextChunk> chunks = [];
    final regex = RegExp(r'(?<=[.?!;\n])\s+');
    int currentLocalIndex = 0;

    final rawParts = text.split(regex);
    for (final part in rawParts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) {
        currentLocalIndex += part.length;
        continue;
      }

      int partStartInSub = text.indexOf(part, currentLocalIndex);
      if (partStartInSub == -1) partStartInSub = currentLocalIndex;
      currentLocalIndex = partStartInSub + part.length;

      int globalStart = startOffset + partStartInSub;

      if (trimmed.length > 160) {
        final words = trimmed.split(' ');
        String currentBuffer = '';
        int bufferStart = globalStart;
        int localWordOffset = 0;

        for (final w in words) {
          if (w.isEmpty) continue;
          int wordPosInPart = trimmed.indexOf(w, localWordOffset);
          if (wordPosInPart == -1) wordPosInPart = localWordOffset;
          localWordOffset = wordPosInPart + w.length;

          if ((currentBuffer.length + w.length + 1) > 160 && currentBuffer.isNotEmpty) {
            final localMatches = RegExp(r'\S+').allMatches(currentBuffer.trim()).toList();
            chunks.add(_TextChunk(currentBuffer.trim(), bufferStart, localMatches));
            currentBuffer = w;
            bufferStart = globalStart + wordPosInPart;
          } else {
            if (currentBuffer.isEmpty) {
              bufferStart = globalStart + wordPosInPart;
              currentBuffer = w;
            } else {
              currentBuffer = '$currentBuffer $w';
            }
          }
        }
        if (currentBuffer.trim().isNotEmpty) {
          final localMatches = RegExp(r'\S+').allMatches(currentBuffer.trim()).toList();
          chunks.add(_TextChunk(currentBuffer.trim(), bufferStart, localMatches));
        }
      } else {
        final localMatches = RegExp(r'\S+').allMatches(trimmed).toList();
        chunks.add(_TextChunk(trimmed, globalStart, localMatches));
      }
    }

    if (chunks.isEmpty && text.trim().isNotEmpty) {
      final localMatches = RegExp(r'\S+').allMatches(text.trim()).toList();
      chunks.add(_TextChunk(text.trim(), startOffset, localMatches));
    }

    return chunks;
  }

  void _resumeAudioFromIndex(int startIndex) {
    final activeText = _firebaseChapterContent ?? widget.todayReading.chapterContent;
    if (_cachedCleanText.isEmpty && activeText != null) {
      _cachedCleanText = activeText;
      _wordMatches = RegExp(r'\S+').allMatches(_cachedCleanText).toList();
    }

    if (_wordMatches.isEmpty) return;

    _playSessionId++;
    final currentSession = _playSessionId;
    _highlightTimer?.cancel();

    if (startIndex >= _wordMatches.length) {
      _stopAudio();
      return;
    }

    final startChar = _wordMatches[startIndex].start;
    final textToSpeak = _cachedCleanText.substring(startChar).trim();

    setState(() {
      _isPlaying = true;
      _isPaused = false;
      _showPlayerBar = true;
      _currentWordIndex = startIndex;
      _draggedWordIndex = null;
      _currentWordStart = _wordMatches[startIndex].start;
      _currentWordEnd = _wordMatches[startIndex].end;
    });

    if (kIsWeb) {
      _textChunks = _buildSafeChunks(_cachedCleanText, startChar);

      if (_textChunks.isNotEmpty) {
        final first = _textChunks[0];
        _currentChunkIndex = 1;
        _speakDirectWeb(first.text, currentSession, 0, first.globalStartOffset);
      } else {
        _stopAudio();
      }
    } else {
      _flutterTts.speak(textToSpeak);
    }
  }

  void _seekToWordIndex(int targetIndex) {
    if (_wordMatches.isEmpty) {
      final activeText = _firebaseChapterContent ?? widget.todayReading.chapterContent;
      if (activeText == null) return;
      _cachedCleanText = activeText;
      _wordMatches = RegExp(r'\S+').allMatches(_cachedCleanText).toList();
    }

    targetIndex = targetIndex.clamp(0, _wordMatches.length - 1);

    setState(() {
      _currentWordIndex = targetIndex;
      _draggedWordIndex = null;
      _currentWordStart = _wordMatches[targetIndex].start;
      _currentWordEnd = _wordMatches[targetIndex].end;
    });

    _resumeAudioFromIndex(targetIndex);
  }

  @override
  void dispose() {
    _stopAudio();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasEvent = widget.todayReading.specialEvent != null && widget.todayReading.specialEvent!.isNotEmpty;
    final hasVerse = widget.todayReading.dailyVerse != null && widget.todayReading.dailyVerse!.isNotEmpty;

    final currentContent = _firebaseChapterContent ?? widget.todayReading.chapterContent;
    final hasContent = currentContent != null && currentContent.isNotEmpty;
    final hasQuiz = widget.todayReading.quiz != null && widget.todayReading.quiz!.isNotEmpty;

    final readingDate = widget.todayReading.date;
    final nombreDia = _diasSemana[readingDate.weekday % 7]; 
    final nombreMes = _meses[readingDate.month - 1];
    final String formattedDate = "$nombreDia, ${readingDate.day} de $nombreMes".toUpperCase();

    return Stack(
      children: [
        SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20.0, 10.0, 20.0, _showPlayerBar ? 120.0 : 20.0),
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
              if (_isLoadingChapter) ...[
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
                const SizedBox(height: 20),
              ]
              else if (hasContent) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Guía del Capítulo",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.primaryColor),
                    ),
                    Row(
                      children: [
                        InkWell(
                          onTap: _cycleSpeed,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: theme.primaryColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _speedLabels[_speedIndex],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: theme.primaryColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: Icon(
                            _isPlaying
                                ? Icons.pause_circle_filled_rounded
                                : Icons.play_circle_fill_rounded,
                            color: _isPlaying ? Colors.orange.shade800 : theme.primaryColor,
                            size: 28,
                          ),
                          tooltip: _isPlaying ? "Pausar" : "Escuchar",
                          onPressed: () => _speakOrToggle(currentContent),
                        ),
                        const SizedBox(width: 4),
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
                          child: _buildHighlightedContent(
                            content: currentContent,
                            primaryColor: theme.primaryColor,
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
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color.fromARGB(255, 253, 203, 138)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.lock_outline_rounded, size: 18, color: Colors.amber.shade900),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  "Debes iniciar sesión para jugar y guardar tu progreso en el ranking.",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF92400E),
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
                            backgroundColor: widget.isLoggedIn ? theme.primaryColor : const Color(0xFFD97706),
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
        ),

        // MINI PLAYER FLOTANTE
        if (_showPlayerBar && _wordMatches.isNotEmpty)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _buildAudioPlayerBar(theme),
          ),
      ],
    );
  }

  Widget _buildAudioPlayerBar(ThemeData theme) {
    final totalWords = _wordMatches.length;
    final double maxVal = (totalWords > 1 ? totalWords - 1 : 1).toDouble();
    final double rawVal = _draggedWordIndex ?? _currentWordIndex.toDouble();
    final double effectiveIndex = rawVal.clamp(0.0, maxVal).toDouble();
    final double percentage = totalWords > 0 ? ((effectiveIndex + 1) / totalWords) * 100 : 0;

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      color: Colors.white,
      shadowColor: Colors.black.withOpacity(0.3),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.primaryColor.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.headphones_rounded, color: theme.primaryColor, size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.todayReading.bookAndChapter,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey.shade900),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  "${percentage.toStringAsFixed(0)}%",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey.shade600),
                ),
                const SizedBox(width: 4),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                  onPressed: _stopAudio,
                ),
              ],
            ),
            const SizedBox(height: 2),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                activeTrackColor: theme.primaryColor,
                inactiveTrackColor: Colors.grey.shade200,
                thumbColor: theme.primaryColor,
              ),
              child: Slider(
                value: effectiveIndex,
                min: 0.0,
                max: maxVal,
                onChanged: (val) {
                  setState(() {
                    _draggedWordIndex = val;
                    final idx = val.round().clamp(0, _wordMatches.length - 1);
                    _currentWordStart = _wordMatches[idx].start;
                    _currentWordEnd = _wordMatches[idx].end;
                  });
                },
                onChangeEnd: (val) {
                  _seekToWordIndex(val.round());
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.replay_10_rounded, size: 22),
                  color: Colors.grey.shade700,
                  tooltip: "Retroceder 15 palabras",
                  onPressed: () => _seekToWordIndex(_currentWordIndex - 15),
                ),
                IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                    size: 34,
                    color: theme.primaryColor,
                  ),
                  onPressed: () => _speakOrToggle(widget.todayReading.chapterContent!),
                ),
                IconButton(
                  icon: const Icon(Icons.forward_10_rounded, size: 22),
                  color: Colors.grey.shade700,
                  tooltip: "Avanzar 15 palabras",
                  onPressed: () => _seekToWordIndex(_currentWordIndex + 15),
                ),
                InkWell(
                  onTap: _cycleSpeed,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _speedLabels[_speedIndex],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightedContent({
    required String content,
    required Color primaryColor,
  }) {
    final defaultStyle = TextStyle(
      fontSize: widget.currentFontSize,
      color: Colors.grey.shade800,
      height: 1.6,
      letterSpacing: 0.2,
    );

    if (!_showPlayerBar || _currentWordEnd <= _currentWordStart || _currentWordEnd > content.length) {
      return Text(
        content,
        textAlign: TextAlign.justify,
        style: defaultStyle,
      );
    }

    final before = content.substring(0, _currentWordStart);
    final highlighted = content.substring(_currentWordStart, _currentWordEnd);
    final after = content.substring(_currentWordEnd);

    return RichText(
      textAlign: TextAlign.justify,
      text: TextSpan(
        style: defaultStyle,
        children: [
          TextSpan(text: before),
          TextSpan(
            text: highlighted,
            style: TextStyle(
              backgroundColor: primaryColor.withOpacity(0.25),
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          TextSpan(text: after),
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