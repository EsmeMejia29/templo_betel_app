class WeeklyVerse {
  final String id;
  final DateTime startDate;
  final String verseText;
  final String verseReference;

  WeeklyVerse({
    required this.id,
    required this.startDate,
    required this.verseText,
    required this.verseReference,
  });

  factory WeeklyVerse.fromJson(Map<String, dynamic> json) {
    return WeeklyVerse(
      id: json['id'],
      startDate: DateTime.parse(json['start_date']),
      verseText: json['verse_text'],
      verseReference: json['verse_reference'],
    );
  }
}