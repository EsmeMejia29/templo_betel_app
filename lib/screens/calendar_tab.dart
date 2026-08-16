import 'package:flutter/material.dart';
import '../models/reading_model.dart';

class CalendarTab extends StatefulWidget {
  final List<DevotionalReading> readings;
  final Function(DevotionalReading) onToggle;

  const CalendarTab({
    super.key,
    required this.readings,
    required this.onToggle,
  });

  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab> {
  late DateTime _currentMonth;

  static const List<String> _meses = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];

  static const List<String> _diasSemana = [
    'Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'
  ];

  static const List<String> _diasCortos = [
    'DOM', 'LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB'
  ];

  static const Color _primaryGreen = Color(0xFF0C3D23);
  static const Color _completedGreen = Color(0xFFE2EFE4);
  static const Color _goldAccent = Color(0xFF997D3C);
  static const Color _bgColor = Color(0xFFF3F6F1);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month, 1);
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
  }

  void _showDayDetailsModal(BuildContext context, DevotionalReading reading, bool isFuture) {
    final readingDate = reading.date;
    final nombreDia = _diasSemana[readingDate.weekday % 7];
    final nombreMes = _meses[readingDate.month - 1];
    final formattedDate = "$nombreDia, ${readingDate.day} de $nombreMes";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 550),
            child: Container(
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
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _primaryGreen,
                    ),
                  ),
                  const Divider(height: 24, thickness: 1),
                  _buildModalSection(
                    icon: Icons.menu_book_rounded,
                    iconColor: _primaryGreen,
                    title: "Lectura Devocional",
                    content: reading.bookAndChapter,
                  ),
                  const SizedBox(height: 16),
                  if (reading.specialEvent != null && reading.specialEvent!.isNotEmpty) ...[
                    _buildModalSection(
                      icon: Icons.church_rounded,
                      iconColor: _goldAccent,
                      title: "Actividad de la Iglesia",
                      content: reading.specialEvent!,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (reading.dailyVerse != null && reading.dailyVerse!.isNotEmpty) ...[
                    _buildModalSection(
                      icon: Icons.auto_stories_rounded,
                      iconColor: _primaryGreen,
                      title: "Versículo Clave",
                      content: '"${reading.dailyVerse!}"\n— ${reading.dailyVerseRef ?? ""}',
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
                        border: Border.all(color: Colors.amber.shade200, width: 1),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lock_outline, size: 20, color: Colors.amber.shade800),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Lectura programada para días futuros. No se puede marcar todavía.",
                              style: TextStyle(
                                color: Colors.amber.shade900,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
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
                          backgroundColor: reading.isCompleted ? Colors.grey.shade200 : _primaryGreen,
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
            ),
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
              Text(
                title,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
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

  Widget _buildCalendarSection({
    required String currentMonthName,
    required List<String> weekdaysHeader,
    required int totalGridCells,
    required int firstDayWeekday,
    required DateTime today,
    required Map<int, DevotionalReading> dayReadingMap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            InkWell(
              onTap: _previousMonth,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.chevron_left, color: _primaryGreen, size: 24),
              ),
            ),
            Text(
              currentMonthName,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: _primaryGreen,
              ),
            ),
            InkWell(
              onTap: _nextMonth,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.chevron_right, color: _primaryGreen, size: 24),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: weekdaysHeader.map((day) => Expanded(
            child: Text(
              day,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: _goldAccent,
                fontSize: 13,
              ),
            ),
          )).toList(),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: totalGridCells,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
            childAspectRatio: 0.95,
          ),
          itemBuilder: (context, index) {
            if (index < firstDayWeekday) {
              return const SizedBox.shrink();
            }

            final dayNum = index - firstDayWeekday + 1;
            final cellDate = DateTime(_currentMonth.year, _currentMonth.month, dayNum);
            final isToday = cellDate.isAtSameMomentAs(today);
            final isFuture = cellDate.isAfter(today);
            final reading = dayReadingMap[dayNum];
            final isCompleted = reading != null && reading.isCompleted;
            final hasEvent = reading != null && reading.specialEvent != null && reading.specialEvent!.isNotEmpty;
            final hasDot = isCompleted || hasEvent;

            Color backgroundColor = Colors.white;
            if (isCompleted) {
              backgroundColor = _completedGreen;
            } else if (isToday) {
              backgroundColor = const Color(0xFFE5EDE6);
            }

            return InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: reading != null
                  ? () => _showDayDetailsModal(context, reading, isFuture)
                  : null,
              child: Container(
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(10),
                  border: isToday
                      ? Border.all(color: _primaryGreen, width: 1.6)
                      : null,
                ),
                padding: const EdgeInsets.all(4),
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        "$dayNum",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isFuture
                              ? Colors.grey.shade400
                              : ((isToday || isCompleted) ? _primaryGreen : Colors.black87),
                        ),
                      ),
                    ),
                    if (isFuture)
                      Align(
                        alignment: Alignment.topRight,
                        child: Icon(
                          Icons.lock_outline,
                          size: 12,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    if (hasDot)
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          width: 4.5,
                          height: 4.5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (isToday || isCompleted) ? _primaryGreen : _goldAccent,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActivitiesSection({
    required List<DevotionalReading> activitiesThisMonth,
    required DateTime today,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Actividades del mes",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: _primaryGreen,
          ),
        ),
        const SizedBox(height: 12),
        if (activitiesThisMonth.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              "No hay próximas actividades este mes.",
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: activitiesThisMonth.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = activitiesThisMonth[index];
              final itemDate = DateTime(item.date.year, item.date.month, item.date.day);
              final isFuture = itemDate.isAfter(today);
              final weekdayIndex = itemDate.weekday % 7;
              final weekdayShort = _diasCortos[weekdayIndex];

              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _showDayDetailsModal(context, item, isFuture),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 36,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              weekdayShort,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isFuture ? Colors.grey.shade400 : _goldAccent,
                              ),
                            ),
                            Text(
                              "${item.date.day}",
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: isFuture ? Colors.grey.shade400 : _primaryGreen,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          item.specialEvent ?? "",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isFuture ? Colors.grey.shade500 : _primaryGreen,
                          ),
                        ),
                      ),
                      Icon(
                        isFuture ? Icons.lock_outline : Icons.chevron_right,
                        color: isFuture ? Colors.grey.shade400 : Colors.grey.shade600,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final weekdaysHeader = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];
    final currentMonthName = "${_meses[_currentMonth.month - 1]} ${_currentMonth.year}";

    final monthReadings = widget.readings.where((r) =>
      r.date.year == _currentMonth.year && r.date.month == _currentMonth.month
    ).toList();

    monthReadings.sort((a, b) => a.date.compareTo(b.date));

    final Map<int, DevotionalReading> dayReadingMap = {
      for (var r in monthReadings) r.date.day: r
    };

    final daysInMonth = DateUtils.getDaysInMonth(_currentMonth.year, _currentMonth.month);
    final firstDayWeekday = _currentMonth.weekday % 7;
    final totalGridCells = daysInMonth + firstDayWeekday;

    final activitiesThisMonth = monthReadings.where((r) {
      if (r.specialEvent == null || r.specialEvent!.trim().isEmpty) {
        return false;
      }
      final rDate = DateTime(r.date.year, r.date.month, r.date.day);
      return !rDate.isBefore(today);
    }).toList();

    return Container(
      color: _bgColor,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 800;

            if (isDesktop) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: _buildCalendarSection(
                            currentMonthName: currentMonthName,
                            weekdaysHeader: weekdaysHeader,
                            totalGridCells: totalGridCells,
                            firstDayWeekday: firstDayWeekday,
                            today: today,
                            dayReadingMap: dayReadingMap,
                          ),
                        ),
                        const SizedBox(width: 32),
                        Expanded(
                          flex: 2,
                          child: _buildActivitiesSection(
                            activitiesThisMonth: activitiesThisMonth,
                            today: today,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCalendarSection(
                    currentMonthName: currentMonthName,
                    weekdaysHeader: weekdaysHeader,
                    totalGridCells: totalGridCells,
                    firstDayWeekday: firstDayWeekday,
                    today: today,
                    dayReadingMap: dayReadingMap,
                  ),
                  const SizedBox(height: 28),
                  _buildActivitiesSection(
                    activitiesThisMonth: activitiesThisMonth,
                    today: today,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}