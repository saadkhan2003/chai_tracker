class GroupModel {
  final String id;
  final String name;
  final String code;
  final String adminId;
  final List<String> members;
  final List<String> memberOrder;
  final DateTime createdAt;
  final int? reminderHour;   // Hour for daily reminder (0-23)
  final int? reminderMinute; // Minute for daily reminder (0-59)
  final String? youtubeChannelUrl; // YouTube channel URL for video feed

  GroupModel({
    required this.id,
    required this.name,
    required this.code,
    required this.adminId,
    required this.members,
    required this.memberOrder,
    required this.createdAt,
    this.reminderHour,
    this.reminderMinute,
    this.youtubeChannelUrl,
  });

  factory GroupModel.fromMap(Map<String, dynamic> map, String id) {
    return GroupModel(
      id: id,
      name: map['name'] ?? '',
      code: map['code'] ?? '',
      adminId: map['adminId'] ?? '',
      members: List<String>.from(map['members'] ?? []),
      memberOrder: List<String>.from(map['memberOrder'] ?? []),
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
      reminderHour: map['reminderHour'],
      reminderMinute: map['reminderMinute'],
      youtubeChannelUrl: map['youtubeChannelUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'code': code,
      'adminId': adminId,
      'members': members,
      'memberOrder': memberOrder,
      'createdAt': createdAt,
      'reminderHour': reminderHour,
      'reminderMinute': reminderMinute,
      'youtubeChannelUrl': youtubeChannelUrl,
    };
  }

  // Check if reminder is set
  bool get hasReminder => reminderHour != null && reminderMinute != null;

  // Get formatted reminder time
  String get reminderTimeFormatted {
    if (!hasReminder) return 'Not set';
    final hour = reminderHour! > 12 ? reminderHour! - 12 : reminderHour!;
    final amPm = reminderHour! >= 12 ? 'PM' : 'AM';
    return '${hour == 0 ? 12 : hour}:${reminderMinute!.toString().padLeft(2, '0')} $amPm';
  }

  /// Get today's assigned person based on rotation
  String getTodayAssignee() {
    if (memberOrder.isEmpty) return '';
    
    final daysSinceCreation = DateTime.now().difference(createdAt).inDays;
    final index = daysSinceCreation % memberOrder.length;
    return memberOrder[index];
  }

  /// Get assignee for a specific date
  String getAssigneeForDate(DateTime date) {
    if (memberOrder.isEmpty) return '';
    
    final daysSinceCreation = date.difference(createdAt).inDays;
    final index = daysSinceCreation.abs() % memberOrder.length;
    return memberOrder[index];
  }
}
