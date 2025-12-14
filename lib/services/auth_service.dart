import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Current user
  User? get currentUser => _auth.currentUser;
  
  // Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Register with email and password
  Future<UserModel?> register({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        final user = UserModel(
          id: credential.user!.uid,
          name: name,
          email: email,
          phone: phone,
          createdAt: DateTime.now(),
        );

        await _firestore
            .collection('users')
            .doc(credential.user!.uid)
            .set(user.toMap());

        return user;
      }
    } catch (e) {
      throw e.toString();
    }
    return null;
  }

  // Login with email and password
  Future<UserModel?> login({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Try to get existing user document
        var user = await getUserById(credential.user!.uid);
        
        // If user doc doesn't exist, create it
        if (user == null) {
          user = UserModel(
            id: credential.user!.uid,
            name: credential.user!.displayName ?? email.split('@')[0],
            email: email,
            phone: '',
            createdAt: DateTime.now(),
          );
          
          await _firestore
              .collection('users')
              .doc(credential.user!.uid)
              .set(user.toMap());
        }
        
        return user;
      }
    } catch (e) {
      throw e.toString();
    }
    return null;
  }

  // Get user by ID
  Future<UserModel?> getUserById(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (doc.exists) {
      return UserModel.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  // Get user stream
  Stream<UserModel?> getUserStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromMap(doc.data()!, doc.id) : null);
  }

  // Logout
  Future<void> logout() async {
    await _auth.signOut();
  }

  // Get multiple users by IDs
  Future<Map<String, UserModel>> getUsersByIds(List<String> userIds) async {
    if (userIds.isEmpty) return {};
    
    final Map<String, UserModel> users = {};
    
    // Firestore whereIn has a limit of 10, so we batch the requests
    for (var i = 0; i < userIds.length; i += 10) {
      final batch = userIds.sublist(i, i + 10 > userIds.length ? userIds.length : i + 10);
      final snapshot = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      
      for (var doc in snapshot.docs) {
        users[doc.id] = UserModel.fromMap(doc.data(), doc.id);
      }
    }
    
    return users;
  }

  // Update user profile
  Future<void> updateProfile({
    required String userId,
    required String name,
    required String phone,
  }) async {
    await _firestore.collection('users').doc(userId).update({
      'name': name,
      'phone': phone,
    });
  }
}
