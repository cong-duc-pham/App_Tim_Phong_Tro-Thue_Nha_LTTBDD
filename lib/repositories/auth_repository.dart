// lib/repositories/auth_repository.dart

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

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

  /// Dang nhap bang Google qua Firebase Auth.
  Future<UserCredential> signInWithGoogle() async {
    try {
      await GoogleSignIn.instance.initialize();
      final googleUser = await GoogleSignIn.instance.authenticate();
      final googleAuth = googleUser.authentication;

      if (googleAuth.idToken == null) {
        throw FirebaseAuthException(
          code: 'google-missing-id-token',
          message:
              'Google Sign-In chua co idToken. Hay them SHA-1/SHA-256 tren Firebase va tai lai google-services.json.',
        );
      }

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      return _signInWithSocialCredential(credential);
    } on GoogleSignInException catch (e) {
      throw FirebaseAuthException(
        code: e.code.name == 'canceled'
            ? 'social-login-cancelled'
            : 'google-login-failed',
        message: e.description ?? e.toString(),
      );
    }
  }

  /// Dang nhap bang Facebook qua Firebase Auth.
  Future<UserCredential> signInWithFacebook() async {
    final result = await FacebookAuth.instance.login(
      permissions: const ['public_profile'],
    );

    if (result.status == LoginStatus.cancelled) {
      throw FirebaseAuthException(
        code: 'social-login-cancelled',
        message: 'User cancelled Facebook login.',
      );
    }

    if (result.status != LoginStatus.success || result.accessToken == null) {
      throw FirebaseAuthException(
        code: 'social-login-failed',
        message: result.message ??
            'Facebook login failed. Kiem tra app mode, tester, package name va key hash tren Meta Developer.',
      );
    }

    final credential = FacebookAuthProvider.credential(
      result.accessToken!.tokenString,
    );

    return _signInWithSocialCredential(credential);
  }

  Future<UserCredential> _signInWithSocialCredential(
    AuthCredential credential,
  ) async {
    final userCredential = await _auth.signInWithCredential(credential);
    await _syncSocialProfile(userCredential.user);
    return userCredential;
  }

  Future<void> _syncSocialProfile(User? user) async {
    if (user == null) return;

    try {
      final providerId = user.providerData.isNotEmpty
          ? user.providerData.first.providerId
          : 'firebase';
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'fullName': user.displayName ?? '',
        'email': user.email ?? '',
        'phone': user.phoneNumber ?? '',
        'role': 'tenant',
        'avatar': user.photoURL,
        'provider': providerId,
        'lastLoginAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      debugPrint('Firebase social profile sync failed: ${e.code} - ${e.message}');
    }
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
    await GoogleSignIn.instance.signOut();
    await FacebookAuth.instance.logOut();
    await _auth.signOut();
  }

  /// Gui email dat lai mat khau.
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }
}
