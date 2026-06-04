import 'package:flutter/material.dart';
import '../models/reading_model.dart';

class TodayTab extends StatelessWidget {
  final DevotionalReading todayReading;
  final Function(DevotionalReading) onToggle;
  final int streakCount;

  const TodayTab({
    super.key,
    required this.todayReading,
    required this.onToggle,
    required this.streakCount,
  });

  // Listas nativas para traducir la fecha de forma manual y segura sin depender de intl
  static const List<String> _meses = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];

  static const List<String> _diasSemana = [
    'Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasEvent = todayReading.specialEvent != null && todayReading.specialEvent!.isNotEmpty;
    final hasVerse = todayReading.dailyVerse != null && todayReading.dailyVerse!.isNotEmpty;
    final hasContent = todayReading.chapterContent != null && todayReading.chapterContent!.isNotEmpty;

    // Construimos la fecha de hoy de forma manual: "JUEVES, 4 DE JUNIO"
    final readingDate = todayReading.date;
    final nombreDia = _diasSemana[readingDate.weekday % 7]; // Ajuste seguro de indexación de días
    final nombreMes = _meses[readingDate.month - 1];
    final String formattedDate = "$nombreDia, ${readingDate.day} de $nombreMes".toUpperCase();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Encabezado de Racha y Día
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
                      "$streakCount ${streakCount == 1 ? 'DÍA' : 'DÍAS'}",
                      // 👈 CORREGIDO: color nativo válido de Flutter
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 2. Tarjeta Principal: Lectura del Día
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
                    todayReading.bookAndChapter,
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                  ),
                  if (hasEvent) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        todayReading.specialEvent!,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: todayReading.isCompleted ? Colors.green.shade600 : Colors.white,
                      foregroundColor: todayReading.isCompleted ? Colors.white : theme.primaryColor,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: () => onToggle(todayReading),
                    icon: Icon(todayReading.isCompleted ? Icons.check_circle : Icons.bookmark_add_outlined),
                    label: Text(
                      todayReading.isCompleted ? "¡COMPLETADO!" : "MARCAR COMO LEÍDO",
                      style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 3. Sección: Versículo Diario (Abajo de la tarjeta principal)
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
                      "\"${todayReading.dailyVerse}\"",
                      style: TextStyle(fontSize: 15, fontStyle: FontStyle.italic, color: Colors.grey.shade800, height: 1.4),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        todayReading.dailyVerseRef ?? "",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.primaryColor),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // 4. NUEVA SECCIÓN: Contenido o Detalles del Capítulo (Abajo del versículo)
          if (hasContent) ...[
            Text(
              "Guía del Capítulo",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.primaryColor),
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
                        todayReading.chapterContent!,
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade800, height: 1.5),
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