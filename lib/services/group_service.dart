import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/group_model.dart';

class GroupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Generate unique 6-character group code
  String _generateGroupCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  // Create a new group
  Future<GroupModel> createGroup({
    required String name,
    required String adminId,
  }) async {
    final code = _generateGroupCode();
    
    final groupData = {
      'name': name,
      'code': code,
      'adminId': adminId,
      'members': [adminId],
      'memberOrder': [adminId],
      'createdAt': FieldValue.serverTimestamp(),
    };

    final docRef = await _firestore.collection('groups').add(groupData);
    final doc = await docRef.get();
    
    return GroupModel.fromMap(doc.data()!, doc.id);
  }

  // Join group by code
  Future<GroupModel?> joinGroup({
    required String code,
    required String userId,
  }) async {
    final snapshot = await _firestore
        .collection('groups')
        .where('code', isEqualTo: code.toUpperCase())
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      throw 'Group not found with this code';
    }

    final doc = snapshot.docs.first;
    final group = GroupModel.fromMap(doc.data(), doc.id);

    if (group.members.contains(userId)) {
      throw 'You are already a member of this group';
    }

    await _firestore.collection('groups').doc(doc.id).update({
      'members': FieldValue.arrayUnion([userId]),
      'memberOrder': FieldValue.arrayUnion([userId]),
    });

    return await getGroupById(doc.id);
  }

  // Get group by ID
  Future<GroupModel?> getGroupById(String groupId) async {
    final doc = await _firestore.collection('groups').doc(groupId).get();
    if (doc.exists) {
      return GroupModel.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  // Get groups for a user
  Stream<List<GroupModel>> getUserGroups(String userId) {
    return _firestore
        .collection('groups')
        .where('members', arrayContains: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => GroupModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Get single group stream
  Stream<GroupModel?> getGroupStream(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .snapshots()
        .map((doc) => doc.exists ? GroupModel.fromMap(doc.data()!, doc.id) : null);
  }

  // Update member order (for reordering rotation)
  Future<void> updateMemberOrder(String groupId, List<String> newOrder) async {
    await _firestore.collection('groups').doc(groupId).update({
      'memberOrder': newOrder,
    });
  }

  // Leave group
  Future<void> leaveGroup(String groupId, String userId) async {
    await _firestore.collection('groups').doc(groupId).update({
      'members': FieldValue.arrayRemove([userId]),
      'memberOrder': FieldValue.arrayRemove([userId]),
    });
  }

  // Remove member (admin only)
  Future<void> removeMember(String groupId, String userId) async {
    await _firestore.collection('groups').doc(groupId).update({
      'members': FieldValue.arrayRemove([userId]),
      'memberOrder': FieldValue.arrayRemove([userId]),
    });
  }

  // Update group name
  Future<void> updateGroup({
    required String groupId,
    required String name,
  }) async {
    await _firestore.collection('groups').doc(groupId).update({
      'name': name,
    });
  }

  // Delete group (admin only)
  Future<void> deleteGroup(String groupId) async {
    await _firestore.collection('groups').doc(groupId).delete();
  }

  // Set reminder time for daily notification
  Future<void> setReminderTime({
    required String groupId,
    required int hour,
    required int minute,
  }) async {
    await _firestore.collection('groups').doc(groupId).update({
      'reminderHour': hour,
      'reminderMinute': minute,
    });
  }

  // Clear reminder time
  Future<void> clearReminderTime(String groupId) async {
    await _firestore.collection('groups').doc(groupId).update({
      'reminderHour': null,
      'reminderMinute': null,
    });
  }

  // Set YouTube channel URL
  Future<void> setYouTubeChannel(String groupId, String channelUrl) async {
    await _firestore.collection('groups').doc(groupId).update({
      'youtubeChannelUrl': channelUrl,
    });
  }

  // Clear YouTube channel URL
  Future<void> clearYouTubeChannel(String groupId) async {
    await _firestore.collection('groups').doc(groupId).update({
      'youtubeChannelUrl': null,
    });
  }
}
