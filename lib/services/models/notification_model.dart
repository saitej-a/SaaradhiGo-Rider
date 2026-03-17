class NotificationModel {
  final int id;
  final String title;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as int,
      title: json['title'] as String? ?? 'No Title',
      message: json['message'] as String? ?? 'No Message',
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at']) 
    );
  }
}
