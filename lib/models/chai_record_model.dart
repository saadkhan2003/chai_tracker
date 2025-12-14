class ChaiRecordModel {
  final String id;
  final String groupId;
  final DateTime assignedDate;
  final String assignedTo;
  final String? broughtBy;
  final String status; // 'pending', 'done'
  final DateTime? markedAt;

  ChaiRecordModel({
    required this.id,
    required this.groupId,
    required this.assignedDate,
    required this.assignedTo,
    this.broughtBy,
    required this.status,
    this.markedAt,
  });

  factory ChaiRecordModel.fromMap(Map<String, dynamic> map, String id) {
    return ChaiRecordModel(
      id: id,
      groupId: map['groupId'] ?? '',
      assignedDate: map['assignedDate']?.toDate() ?? DateTime.now(),
      assignedTo: map['assignedTo'] ?? '',
      broughtBy: map['broughtBy'],
      status: map['status'] ?? 'pending',
      markedAt: map['markedAt']?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'assignedDate': assignedDate,
      'assignedTo': assignedTo,
      'broughtBy': broughtBy,
      'status': status,
      'markedAt': markedAt,
    };
  }

  bool get isDone => status == 'done';
  bool get isPending => status == 'pending';
}
