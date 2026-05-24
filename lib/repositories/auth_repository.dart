// lib/repositories/auth_repository.dart

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthRepository({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  })  : _auth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// Dang nhap bang email + password.
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Dang ky tai khoan moi.
  Future<UserCredential> createUserWithEmailAndPassword({
    required String fullName,
    required String email,
    required String password,
    required String phone,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    // The Auth user has already been created. If profile sync fails,
    // registration should still be treated as successful.
    try {
      await credential.user?.updateDisplayName(fullName);
      await _firestore.collection('users').doc(credential.user!.uid).set({
        'uid': credential.user!.uid,
        'fullName': fullName.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        'role': 'tenant',
        'createdAt': FieldValue.serverTimestamp(),
        'avatar': null,
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      debugPrint('Firebase profile sync failed: ${e.code} - ${e.message}');
    }

    return credential;
  }

  /// Dang xuat.
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Gui email dat lai mat khau.
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }
}
