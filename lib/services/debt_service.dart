import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/debt_model.dart';

class DebtService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create a debt request
  Future<DebtModel> createDebt({
    required String fromUserId,
    required String toUserId,
    required String groupId,
    required double amount,
    required String reason,
  }) async {
    final debtData = {
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'groupId': groupId,
      'amount': amount,
      'reason': reason,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    };

    final docRef = await _firestore.collection('debts').add(debtData);
    final doc = await docRef.get();
    
    return DebtModel.fromMap(doc.data()!, doc.id);
  }

  // Accept a debt request
  Future<void> acceptDebt(String debtId) async {
    await _firestore.collection('debts').doc(debtId).update({
      'status': 'accepted',
    });
  }

  // Reject a debt request
  Future<void> rejectDebt(String debtId) async {
    await _firestore.collection('debts').doc(debtId).update({
      'status': 'rejected',
    });
  }

  // Mark debt as settled
  Future<void> settleDebt(String debtId) async {
    await _firestore.collection('debts').doc(debtId).update({
      'status': 'settled',
    });
  }

  // Update debt amount and reason
  Future<void> updateDebt({
    required String debtId,
    required double amount,
    required String reason,
  }) async {
    await _firestore.collection('debts').doc(debtId).update({
      'amount': amount,
      'reason': reason,
    });
  }

  // Delete a debt
  Future<void> deleteDebt(String debtId) async {
    await _firestore.collection('debts').doc(debtId).delete();
  }

  // Get debts where user is the creditor (money owed TO user) - simple query
  Stream<List<DebtModel>> getDebtsOwedToUser(String userId) {
    return _firestore
        .collection('debts')
        .where('fromUserId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DebtModel.fromMap(doc.data(), doc.id))
            .where((d) => d.status == 'pending' || d.status == 'accepted')
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
  }

  // Get debts where user owes money (money owed BY user) - simple query
  Stream<List<DebtModel>> getDebtsOwedByUser(String userId) {
    return _firestore
        .collection('debts')
        .where('toUserId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DebtModel.fromMap(doc.data(), doc.id))
            .where((d) => d.status == 'pending' || d.status == 'accepted')
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
  }

  // Get pending debt requests for user (requests sent TO user) - simple query
  Stream<List<DebtModel>> getPendingDebtRequests(String userId) {
    return _firestore
        .collection('debts')
        .where('toUserId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DebtModel.fromMap(doc.data(), doc.id))
            .where((d) => d.status == 'pending')
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
  }

  // Get all debts for a group - simple query
  Stream<List<DebtModel>> getGroupDebts(String groupId) {
    return _firestore
        .collection('debts')
        .where('groupId', isEqualTo: groupId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DebtModel.fromMap(doc.data(), doc.id))
            .where((d) => d.status == 'pending' || d.status == 'accepted')
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
  }

  // Get debt history (settled and rejected) for a user
  Stream<List<DebtModel>> getDebtHistory(String userId) {
    return _firestore
        .collection('debts')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DebtModel.fromMap(doc.data(), doc.id))
            .where((d) => 
                (d.fromUserId == userId || d.toUserId == userId) &&
                (d.status == 'settled' || d.status == 'rejected'))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
  }
}
