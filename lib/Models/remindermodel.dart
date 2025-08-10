class Reminder {
  String id;
  String title;
  DateTime date;

  Reminder({required this.id, required this.title, required this.date});

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'date': date.toIso8601String(),
  };

  factory Reminder.fromJson(Map<String, dynamic> json) {
    return Reminder(
      id: json['id'],
      title: json['title'],
      date: DateTime.parse(json['date']),
    );
  }
}
