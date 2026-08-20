class DevotionalReading {
  final String id;
  final DateTime date;
  final String bookAndChapter;
  final String? specialEvent;
  final String? dailyVerse;
  final String? dailyVerseRef;
  final String? chapterContent;
  final List<dynamic>? quiz;
  bool isCompleted;

  DevotionalReading({
    required this.id,
    required this.date,
    required this.bookAndChapter,
    this.specialEvent,
    this.dailyVerse,
    this.dailyVerseRef,
    this.chapterContent,
    this.quiz,
    this.isCompleted = false,
  });

  factory DevotionalReading.fromJson(Map<String, dynamic> json) {
    return DevotionalReading(
      id: json['id']?.toString() ?? '',
      date: DateTime.parse(json['date']),
      bookAndChapter: json['book_and_chapter'] ?? '',
      specialEvent: json['special_event'],
      dailyVerse: json['daily_verse'],
      dailyVerseRef: json['daily_verse_ref'],
      chapterContent: json['chapter_content'],
      quiz: json['quiz'] is List ? json['quiz'] : null,
      isCompleted: false,
    );
  }
}