class NotificationModel {
  final String notificationId;
  final String orderId;
  final String recipientDepartment;
  final String notificationType;
  final String message;
  final String status; // 'read' or 'unread'
  final DateTime? createdAt;
  final String? relatedUserId;

  NotificationModel({
    required this.notificationId,
    required this.orderId,
    required this.recipientDepartment,
    required this.notificationType,
    required this.message,
    required this.status,
    this.createdAt,
    this.relatedUserId,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      notificationId: json['notification_id']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      recipientDepartment: json['recipient_department']?.toString() ?? '',
      notificationType: json['notification_type']?.toString() ?? 'ORDER_CREATED',
      message: json['message']?.toString() ?? '',
      status: json['status']?.toString() ?? 'unread',
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      relatedUserId: json['related_user_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'notification_id': notificationId,
      'order_id': orderId,
      'recipient_department': recipientDepartment,
      'notification_type': notificationType,
      'message': message,
      'status': status,
      'created_at': createdAt?.toIso8601String(),
      'related_user_id': relatedUserId,
    };
  }

  bool get isRead => status.toLowerCase() == 'read';
  bool get isUnread => !isRead;
}

