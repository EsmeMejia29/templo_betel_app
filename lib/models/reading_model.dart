class DevotionalReading {
  final String id;
  final DateTime date;
  final String bookAndChapter;
  final String? specialEvent;
  final String? dailyVerse;
  final String? dailyVerseRef;
  bool isCompleted;

  DevotionalReading({
    required this.id,
    required this.date,
    required this.bookAndChapter,
    this.specialEvent,
    this.dailyVerse,
    this.dailyVerseRef,
    this.isCompleted = false,
  });

  /// Transforma el JSON que viene de Supabase a un Objeto de Dart nativo
  factory DevotionalReading.fromJson(Map<String, dynamic> json) {
    return DevotionalReading(
      // Forzamos el ID a String para capturar el UUID sin problemas
      id: json['id']?.toString() ?? '',
      
      // Parseo seguro de la fecha de la base de datos
      date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      
      // Mapea el nombre del libro y capítulo (Ej: "Rut 1" o "1 Samuel 1")
      bookAndChapter: json['book_and_chapter'] ?? json['details'] ?? 'Lectura Vacía',
      
      // Captura eventos o actividades de la iglesia (Ej: "Culto en Filiales" o "Vigilia")
      specialEvent: json['special_event'] ?? json['event'],
      
      // Campos opcionales por si en el futuro añades el versículo clave del día
      dailyVerse: json['daily_verse'],
      dailyVerseRef: json['daily_verse_ref'],
      
      // El estado de completado se inicializa en falso y se evalúa dinámicamente en la UI
      isCompleted: false,
    );
  }

  /// Convierte el objeto de Dart de vuelta a un mapa JSON (Útil si necesitas hacer updates manuales)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'book_and_chapter': bookAndChapter,
      'special_event': specialEvent,
      'daily_verse': dailyVerse,
      'daily_verse_ref': dailyVerseRef,
    };
  }
}