import 'package:flutter/material.dart';
import '../models/reading_model.dart';

class CalendarTab extends StatefulWidget {
  final List<DevotionalReading> readings;
  final Function(DevotionalReading) onToggle;

  const CalendarTab({super.key, required this.readings, required this.onToggle});

  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab> {
  late ScrollController _scrollController;

  // Listas nativas para traducir la fecha de forma manual y segura
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
    _scrollController = ScrollController();

    // Ejecutamos el scroll automático justo después de que se renderice el primer frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentMonth();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentMonth() {
    if (widget.readings.isEmpty) return;

    final now = DateTime.now();
    final groupedReadings = _groupReadingsByMonth();
    final monthKeys = groupedReadings.keys.toList();

    // Buscamos la llave del mes actual (Ejemplo: "2026-6")
    final currentKey = "${now.year}-${now.month}";
    final targetIndex = monthKeys.indexOf(currentKey);

    // Si el mes actual existe en tu lista de Supabase, calculamos la posición aproximada
    if (targetIndex != -1) {
      double targetOffset = 0.0;

      // Estimación de altura por bloque de mes para un scroll suave pero preciso:
      for (int i = 0; i < targetIndex; i++) {
        final readingsInMonth = groupedReadings[monthKeys[i]]!.length;
        final firstDay = groupedReadings[monthKeys[i]]!.first.date;
        final offset = firstDay.weekday % 7;
        
        // Calculamos cuántas filas de 7 días ocupa este mes en particular
        final int rows = ((readingsInMonth + offset) / 7).ceil();
        
        // Sumamos la altura estimada de este mes (Título: ~50px + (Filas * altura de tarjeta ~92px) + espaciados)
        targetOffset += 50.0 + (rows * 92.0) + 16.0;
      }

      // Verificamos que no nos pasemos del límite máximo del scroll
      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        if (targetOffset > maxScroll) targetOffset = maxScroll;

        // Hace el movimiento con una animación sutil y elegante
        _scrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      }
    }
  }

  void _showDayDetailsModal(BuildContext context, DevotionalReading reading, bool isFuture, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, 
      builder: (context) {
        final readingDate = reading.date;
        final nombreDia = _diasSemana[readingDate.weekday % 7];
        final nombreMes = _meses[readingDate.month - 1];
        final formattedDate = "$nombreDia, ${readingDate.day} de $nombreMes";

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                formattedDate,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.primaryColor),
              ),
              const Divider(height: 24, thickness: 1),
              _buildModalSection(
                icon: Icons.menu_book_rounded,
                iconColor: theme.primaryColor,
                title: "Lectura Devocional",
                content: reading.bookAndChapter,
                theme: theme,
              ),
              const SizedBox(height: 16),
              if (reading.specialEvent != null && reading.specialEvent!.isNotEmpty) ...[
                _buildModalSection(
                  icon: Icons.church_rounded,
                  iconColor: theme.colorScheme.secondary,
                  title: "Actividad de la Iglesia",
                  content: reading.specialEvent!,
                  theme: theme,
                ),
                const SizedBox(height: 16),
              ],
              if (reading.dailyVerse != null && reading.dailyVerse!.isNotEmpty) ...[
                _buildModalSection(
                  icon: Icons.auto_stories_rounded,
                  iconColor: theme.colorScheme.tertiary,
                  title: "Versículo Clave",
                  content: '"${reading.dailyVerse!}"\n— ${reading.dailyVerseRef ?? ""}',
                  theme: theme,
                  isItalic: true,
                ),
                const SizedBox(height: 24),
              ],
              if (isFuture)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade200, width: 1)
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lock_outline, size: 20, color: Colors.amber.shade800),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Lectura programada para días futuros. No se puede marcar todavía.",
                          style: TextStyle(color: Colors.amber.shade900, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: reading.isCompleted ? Colors.grey.shade200 : theme.primaryColor,
                      foregroundColor: reading.isCompleted ? Colors.grey.shade700 : Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: Icon(reading.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked),
                    label: Text(
                      reading.isCompleted ? "Lectura Completada" : "Marcar como Completada",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    onPressed: () {
                      Navigator.pop(context); 
                      widget.onToggle(reading);     
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModalSection({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String content,
    required ThemeData theme,
    bool isItalic = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(
                content,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                  fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Map<String, List<DevotionalReading>> _groupReadingsByMonth() {
    final Map<String, List<DevotionalReading>> groups = {};
    for (var reading in widget.readings) {
      final key = "${reading.date.year}-${reading.date.month}";
      if (!groups.containsKey(key)) {
        groups[key] = [];
      }
      groups[key]!.add(reading);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    const weekdays = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];

    final groupedReadings = _groupReadingsByMonth();
    final monthKeys = groupedReadings.keys.toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Calendario Devocional",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.primaryColor),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: weekdays.map((day) => Expanded(
                child: Text(
                  day, 
                  textAlign: TextAlign.center, 
                  style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.secondary, fontSize: 13)
                ),
              )).toList(),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: widget.readings.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: _scrollController, 
                      physics: const BouncingScrollPhysics(),
                      itemCount: monthKeys.length,
                      itemBuilder: (context, monthIndex) {
                        final monthKey = monthKeys[monthIndex];
                        final monthReadings = groupedReadings[monthKey]!;
                        
                        final int monthNum = monthReadings.first.date.month;
                        final String monthName = _meses[monthNum - 1].toUpperCase();

                        final firstDayOfMonth = monthReadings.first.date;
                        final int weekdayOffset = firstDayOfMonth.weekday % 7; 
                        final int totalGridItems = monthReadings.length + weekdayOffset;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14.0),
                              child: Row(
                                children: [
                                  Text(
                                    monthName,
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.primaryColor, letterSpacing: 1.2),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(child: Divider(color: theme.primaryColor.withOpacity(0.2), thickness: 1)),
                                ],
                              ),
                            ),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(), 
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 7, 
                                crossAxisSpacing: 4,
                                mainAxisSpacing: 4,
                                childAspectRatio: 0.72, 
                              ),
                              itemCount: totalGridItems,
                              itemBuilder: (context, index) {
                                if (index < weekdayOffset) {
                                  return const SizedBox.shrink();
                                }

                                final reading = monthReadings[index - weekdayOffset];
                                final readingDate = DateTime(reading.date.year, reading.date.month, reading.date.day);
                                final isFuture = readingDate.isAfter(today);
                                final hasEvent = reading.specialEvent != null && reading.specialEvent!.isNotEmpty;

                                return Opacity(
                                  opacity: isFuture ? 0.4 : 1.0, 
                                  child: Card(
                                    elevation: reading.isCompleted ? 0 : 1,
                                    color: reading.isCompleted 
                                        ? theme.primaryColor.withOpacity(0.1) 
                                        : Colors.white,
                                    shape: RoundedRectangleBorder(
                                      side: BorderSide(
                                        color: readingDate.isAtSameMomentAs(today)
                                            ? theme.colorScheme.tertiary
                                            : theme.colorScheme.secondary.withOpacity(0.2),
                                        width: readingDate.isAtSameMomentAs(today) ? 1.5 : 1,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () => _showDayDetailsModal(context, reading, isFuture, theme),
                                      child: Padding(
                                        padding: const EdgeInsets.all(4.0),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Align(
                                              alignment: Alignment.topLeft,
                                              child: Text(
                                                "${reading.date.day}",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                  color: readingDate.isAtSameMomentAs(today)
                                                      ? theme.colorScheme.tertiary
                                                      : theme.primaryColor,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              reading.bookAndChapter
                                                  .replaceAll("Deuteronomio", "Deut.")
                                                  .replaceAll("Números", "Núm.")
                                                  .replaceAll("Apocalipsis", "Apoc."),
                                              textAlign: TextAlign.center,
                                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                                            ),
                                            if (hasEvent)
                                              Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 1.0),
                                                child: Text(
                                                  reading.specialEvent!,
                                                  textAlign: TextAlign.center,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: theme.colorScheme.secondary),
                                                ),
                                              )
                                            else
                                              const SizedBox(height: 1),
                                            if (reading.isCompleted)
                                              Icon(Icons.check_circle, size: 14, color: theme.primaryColor)
                                            else if (isFuture)
                                              const Icon(Icons.lock_outline, size: 11, color: Colors.grey)
                                            else
                                              const SizedBox(height: 14),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}