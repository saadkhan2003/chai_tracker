class DebtModel {
  final String id;
  final String fromUserId;
  final String toUserId;
  final String groupId;
  final double amount;
  final String reason;
  final String status; // 'pending', 'accepted', 'settled', 'rejected'
  final DateTime createdAt;

  DebtModel({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.groupId,
    required this.amount,
    required this.reason,
    required this.status,
    required this.createdAt,
  });

  factory DebtModel.fromMap(Map<String, dynamic> map, String id) {
    return DebtModel(
      id: id,
      fromUserId: map['fromUserId'] ?? '',
      toUserId: map['toUserId'] ?? '',
      groupId: map['groupId'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      reason: map['reason'] ?? '',
      status: map['status'] ?? 'pending',
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'groupId': groupId,
      'amount': amount,
      'reason': reason,
      'status': status,
      'createdAt': createdAt,
    };
  }

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isSettled => status == 'settled';
  bool get isRejected => status == 'rejected';
}
