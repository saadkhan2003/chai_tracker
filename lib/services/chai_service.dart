import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chai_record_model.dart';

class ChaiService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get today's date without time
  DateTime _getToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  // Get or create today's chai record
  Future<ChaiRecordModel> getOrCreateTodayRecord({
    required String groupId,
    required String assignedTo,
  }) async {
    final today = _getToday();
    final startOfDay = today;
    final endOfDay = today.add(const Duration(days: 1));

    // Check if record exists for today
    final snapshot = await _firestore
        .collection('chaiRecords')
        .where('groupId', isEqualTo: groupId)
        .where('assignedDate', isGreaterThanOrEqualTo: startOfDay)
        .where('assignedDate', isLessThan: endOfDay)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return ChaiRecordModel.fromMap(snapshot.docs.first.data(), snapshot.docs.first.id);
    }

    // Create new record
    final recordData = {
      'groupId': groupId,
      'assignedDate': today,
      'assignedTo': assignedTo,
      'broughtBy': null,
      'status': 'pending',
      'markedAt': null,
    };

    final docRef = await _firestore.collection('chaiRecords').add(recordData);
    final doc = await docRef.get();
    
    return ChaiRecordModel.fromMap(doc.data()!, doc.id);
  }

  // Mark chai as done
  Future<void> markAsDone({
    required String recordId,
    required String broughtBy,
  }) async {
    await _firestore.collection('chaiRecords').doc(recordId).update({
      'status': 'done',
      'broughtBy': broughtBy,
      'markedAt': FieldValue.serverTimestamp(),
    });
  }

  // Mark chai as pending (undo done)
  Future<void> markAsPending(String recordId) async {
    await _firestore.collection('chaiRecords').doc(recordId).update({
      'status': 'pending',
      'broughtBy': null,
      'markedAt': null,
    });
  }

  // Update chai record (change assigned person)
  Future<void> updateRecord({
    required String recordId,
    required String assignedTo,
  }) async {
    await _firestore.collection('chaiRecords').doc(recordId).update({
      'assignedTo': assignedTo,
    });
  }

  // Delete a chai record
  Future<void> deleteRecord(String recordId) async {
    await _firestore.collection('chaiRecords').doc(recordId).delete();
  }

  // Get chai record stream for today
  Stream<ChaiRecordModel?> getTodayRecordStream(String groupId) {
    final today = _getToday();
    final endOfDay = today.add(const Duration(days: 1));

    return _firestore
        .collection('chaiRecords')
        .where('groupId', isEqualTo: groupId)
        .where('assignedDate', isGreaterThanOrEqualTo: today)
        .where('assignedDate', isLessThan: endOfDay)
        .limit(1)
        .snapshots()
        .map((snapshot) => snapshot.docs.isNotEmpty
            ? ChaiRecordModel.fromMap(snapshot.docs.first.data(), snapshot.docs.first.id)
            : null);
  }

  // Get history (past records) - simple query, sort client-side
  Stream<List<ChaiRecordModel>> getHistory({
    required String groupId,
    int? month,
    int? year,
  }) {
    return _firestore
        .collection('chaiRecords')
        .where('groupId', isEqualTo: groupId)
        .snapshots()
        .map((snapshot) {
          var records = snapshot.docs
              .map((doc) => ChaiRecordModel.fromMap(doc.data(), doc.id))
              .toList();
          
          // Filter by month/year if specified
          if (month != null && year != null) {
            records = records.where((r) {
              return r.assignedDate.month == month && r.assignedDate.year == year;
            }).toList();
          }
          
          // Sort by date descending
          records.sort((a, b) => b.assignedDate.compareTo(a.assignedDate));
          return records;
        });
  }

  // Get pending records (for showing who still owes chai) - simple query
  Stream<List<ChaiRecordModel>> getPendingRecords(String groupId) {
    return _firestore
        .collection('chaiRecords')
        .where('groupId', isEqualTo: groupId)
        .snapshots()
        .map((snapshot) {
          var records = snapshot.docs
              .map((doc) => ChaiRecordModel.fromMap(doc.data(), doc.id))
              .where((r) => r.status == 'pending')
              .toList();
          records.sort((a, b) => a.assignedDate.compareTo(b.assignedDate));
          return records;
        });
  }
}
