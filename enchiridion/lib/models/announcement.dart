class Announcement {
  final String id;
  final String title;
  final String body;
  final bool isImportant;

  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.isImportant,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      isImportant: json['is_important'] as bool? ?? false,
    );
  }
}
