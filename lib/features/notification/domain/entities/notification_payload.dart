import 'package:equatable/equatable.dart';

class NotificationPayload extends Equatable {
  const NotificationPayload({
    required this.title,
    required this.body,
    this.route,
    this.referenceId,
    this.recipientId,
    this.recipientType,
    this.data = const {},
  });

  final String title;
  final String body;
  final String? route;
  final String? referenceId;
  final String? recipientId;
  final String? recipientType;
  final Map<String, dynamic> data;

  factory NotificationPayload.fromFcmData(Map<String, dynamic> data) {
    return NotificationPayload(
      title: data['title'] as String? ?? 'Open Space Parking',
      body: data['body'] as String? ?? data['message'] as String? ?? '',
      route: data['route'] as String?,
      referenceId: data['referenceId'] as String? ?? data['bookingRef'] as String?,
      recipientId: data['recipientId'] as String?,
      recipientType: data['recipientType'] as String?,
      data: data,
    );
  }

  @override
  List<Object?> get props =>
      [title, body, route, referenceId, recipientId, recipientType, data];
}
