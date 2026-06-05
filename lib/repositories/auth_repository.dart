// lib/repositories/auth_repository.dart

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import '../services/api_service.dart';

class BackendAuthSession {
  const BackendAuthSession({
    required this.userId,
    required this.email,
    required this.fullName,
    required this.accessToken,
    this.refreshToken,
    this.role,
    this.isPhoneVerified = false,
    this.phoneNumber,
    this.isEmailVerified = false,
    this.firebaseProvider,
  });

  final String userId;
  final String email;
  final String fullName;
  final String accessToken;
  final String? refreshToken;
  final String? role;
  final bool isPhoneVerified;
  final String? phoneNumber;
  final bool isEmailVerified;
  final String? firebaseProvider;
}

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final ApiService _apiService;

  AuthRepository({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    ApiService? apiService,
  })  : _auth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _apiService = apiService ?? ApiService();

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// Đăng nhập bằng email + password.
  Future<BackendAuthSession> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final response = await _apiService.dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {
        'email': email.trim(),
        'password': password,
      },
    );

    final session = _sessionFromBackendResponse(
      response.data,
      fallbackEmail: email.trim(),
    );
    await _saveBackendSession(session);
    await _auth.signOut();
    return session;
  }

  /// Đăng nhập bằng Google qua Firebase Auth.
  Future<BackendAuthSession> signInWithGoogle() async {
    try {
      await GoogleSignIn.instance.initialize().timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw TimeoutException(
              'Google Sign-In khởi tạo quá lâu.',
            ),
          );
      final googleUser = await GoogleSignIn.instance.authenticate().timeout(
            const Duration(seconds: 60),
            onTimeout: () => throw TimeoutException(
              'Google Sign-In không phản hồi. Vui lòng thử lại.',
            ),
          );
      final googleAuth = googleUser.authentication;

      if (googleAuth.idToken == null) {
        throw FirebaseAuthException(
          code: 'google-missing-id-token',
          message:
              'Google Sign-In chưa có idToken. Hãy thêm SHA-1/SHA-256 trên Firebase và tải lại google-services.json.',
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
    } on TimeoutException catch (e) {
      throw FirebaseAuthException(
        code: 'google-login-timeout',
        message: e.message,
      );
    }
  }

  /// Đăng nhập bằng Facebook qua Firebase Auth.
  Future<BackendAuthSession> signInWithFacebook() async {
    final result = await FacebookAuth.instance.login(
      permissions: const ['public_profile'],
    ).timeout(
      const Duration(seconds: 60),
      onTimeout: () => throw TimeoutException(
        'Facebook Login không phản hồi. Vui lòng thử lại.',
      ),
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
            'Facebook login failed. Kiểm tra app mode, tester, package name và key hash trên Meta Developer.',
      );
    }

    final credential = FacebookAuthProvider.credential(
      result.accessToken!.tokenString,
    );

    return _signInWithSocialCredential(credential);
  }

  Future<BackendAuthSession> _signInWithSocialCredential(
    AuthCredential credential,
  ) async {
    final userCredential = await _auth.signInWithCredential(credential);
    unawaited(_syncSocialProfile(userCredential.user));
    try {
      final session = await _loginBackendWithFirebase(userCredential.user);
      await _saveBackendSession(session);
      return session;
    } catch (_) {
      await signOut();
      rethrow;
    }
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
    } catch (e) {
      debugPrint('Firebase social profile sync failed: $e');
    }
  }

  /// Đăng ký tài khoản mới.
  Future<BackendAuthSession> createUserWithEmailAndPassword({
    required String fullName,
    required String email,
    required String password,
    required String phone,
  }) async {
    final response = await _apiService.dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: {
        'fullName': fullName.trim(),
        'email': email.trim(),
        'password': password,
        'phone': phone.trim(),
      },
    );

    final session = _sessionFromBackendResponse(
      response.data,
      fallbackEmail: email.trim(),
      fallbackFullName: fullName.trim(),
    );
    await _saveBackendSession(session);
    return session;
  }

  /// Đổi mật khẩu tài khoản người dùng hiện tại trên backend.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.keyUserToken);
    if (token == null || token.isEmpty) {
      throw Exception('Bạn cần đăng nhập để thực hiện đổi mật khẩu.');
    }

    try {
      await _apiService.dio.post(
        '/auth/change-password',
        data: {
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } on DioException catch (e) {
      throw Exception(readBackendMessage(e));
    }
  }

  /// Cập nhật thông tin cá nhân trên backend.
  Future<void> updateProfile({
    required String fullName,
    required String phone,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.keyUserToken);
    if (token == null || token.isEmpty) {
      throw Exception('Bạn cần đăng nhập để thực hiện cập nhật.');
    }

    try {
      await _apiService.dio.put(
        '/auth/profile',
        data: {
          'fullName': fullName.trim(),
          'phone': phone.trim(),
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      // Cập nhật lại SharedPreferences nội bộ
      await prefs.setString('user_full_name', fullName.trim());
    } on DioException catch (e) {
      throw Exception(readBackendMessage(e));
    }
  }

  /// Đăng xuất.
  Future<void> deactivateAccount() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.keyUserToken);
    if (token == null || token.isEmpty) {
      throw Exception('Bạn cần đăng nhập để vô hiệu hóa tài khoản.');
    }

    try {
      await _apiService.dio.post(
        '/auth/deactivate-account',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } on DioException catch (e) {
      throw Exception(readBackendMessage(e));
    }
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}

    try {
      await FacebookAuth.instance.logOut();
    } catch (_) {}

    try {
      await _auth.signOut();
    } finally {
      await clearBackendSession();
    }
  }

  /// Gửi email đặt lại mật khẩu.
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<BackendAuthSession?> getSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.keyUserToken);
    final userId = prefs.getString(AppConstants.keyUserId);
    if (token == null || token.isEmpty || userId == null || userId.isEmpty) {
      return null;
    }

    return BackendAuthSession(
      userId: userId,
      email: prefs.getString('user_email') ?? '',
      fullName: prefs.getString('user_full_name') ?? '',
      accessToken: token,
      refreshToken: prefs.getString('refresh_token'),
      role: prefs.getString(AppConstants.keyUserRole),
      isPhoneVerified: prefs.getBool('verify_phone_status') ?? false,
      phoneNumber: prefs.getString('verify_phone_number'),
      isEmailVerified: prefs.getBool('verify_email_status') ?? false,
      firebaseProvider: prefs.getString('firebase_provider'),
    );
  }

  Future<void> clearBackendSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.keyUserToken);
    await prefs.remove(AppConstants.keyUserId);
    await prefs.remove(AppConstants.keyUserRole);
    await prefs.remove('refresh_token');
    await prefs.remove('user_email');
    await prefs.remove('user_full_name');
    await prefs.remove('verify_phone_status');
    await prefs.remove('verify_phone_number');
    await prefs.remove('verify_email_status');
    await prefs.remove('firebase_provider');
  }

  Future<BackendAuthSession> _loginBackendWithFirebase(User? user) async {
    if (user == null) {
      throw FirebaseAuthException(
        code: 'firebase-user-missing',
        message: 'Không lấy được thông tin Firebase user.',
      );
    }

    final firebaseToken = await user.getIdToken(true);
    if (firebaseToken == null || firebaseToken.isEmpty) {
      throw FirebaseAuthException(
        code: 'firebase-token-missing',
        message: 'Không lấy được Firebase token.',
      );
    }

    final response = await _apiService.dio.post<Map<String, dynamic>>(
      '/auth/firebase-login',
      data: {'firebaseToken': firebaseToken},
    );

    return _sessionFromBackendResponse(
      response.data,
      fallbackEmail: user.email ?? '',
      fallbackFullName: user.displayName ?? '',
    );
  }

  BackendAuthSession _sessionFromBackendResponse(
    Map<String, dynamic>? body, {
    required String fallbackEmail,
    String fallbackFullName = '',
  }) {
    final data = body?['data'] ?? body?['Data'];
    if (data is! Map) {
      throw Exception('Backend không trả về thông tin đăng nhập.');
    }

    final accessToken = data['accessToken'] ?? data['AccessToken'];
    if (accessToken is! String || accessToken.isEmpty) {
      throw Exception('Backend không trả về access token.');
    }

    final userId = data['userId'] ?? data['UserId'];
    final fullName = data['fullName'] ?? data['FullName'];
    final refreshToken = data['refreshToken'] ?? data['RefreshToken'];
    final role = data['role'] ?? data['Role'];
    final isPhoneVerified =
        data['isPhoneVerified'] ?? data['IsPhoneVerified'] ?? false;
    final phoneNumber = data['phoneNumber'] ?? data['PhoneNumber'];
    final isEmailVerified =
        data['isEmailVerified'] ?? data['IsEmailVerified'] ?? false;
    final firebaseProvider =
        data['firebaseProvider'] ?? data['FirebaseProvider'];
    final emailVal = data['email'] ?? data['Email'] ?? fallbackEmail;

    return BackendAuthSession(
      userId: userId?.toString() ?? '',
      email: emailVal.toString(),
      fullName: fullName?.toString() ?? fallbackFullName,
      accessToken: accessToken,
      refreshToken: refreshToken?.toString(),
      role: role?.toString(),
      isPhoneVerified: isPhoneVerified is bool ? isPhoneVerified : false,
      phoneNumber: phoneNumber?.toString(),
      isEmailVerified: isEmailVerified is bool ? isEmailVerified : false,
      firebaseProvider: firebaseProvider?.toString(),
    );
  }

  Future<void> _saveBackendSession(BackendAuthSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyUserToken, session.accessToken);
    await prefs.setString(AppConstants.keyUserId, session.userId);
    await prefs.setString('user_email', session.email);
    await prefs.setString('user_full_name', session.fullName);
    await prefs.setBool('verify_phone_status', session.isPhoneVerified);
    await prefs.setString('verify_phone_number', session.phoneNumber ?? '');
    await prefs.setBool('verify_email_status', session.isEmailVerified);
    await prefs.setString('firebase_provider', session.firebaseProvider ?? '');
    if (session.refreshToken != null) {
      await prefs.setString('refresh_token', session.refreshToken!);
    }
    if (session.role != null) {
      await prefs.setString(AppConstants.keyUserRole, session.role!);
    }
  }

  String readBackendMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final message = data['message'] ?? data['Message'];
        if (message != null) return message.toString();
      }
      if (data is String && data.trim().isNotEmpty) {
        return data;
      }
      return error.message ?? 'Không kết nối được backend.';
    }

    final message = error.toString();
    return message.startsWith('Exception: ')
        ? message.substring('Exception: '.length)
        : message;
  }

  /// Gửi mã OTP xác minh số điện thoại về số điện thoại thực.
  Future<String?> sendPhoneOtp(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.keyUserToken);
    if (token == null || token.isEmpty) {
      throw Exception('Bạn cần đăng nhập để thực hiện xác thực.');
    }

    try {
      final response = await _apiService.dio.post<Map<String, dynamic>>(
        '/auth/send-phone-otp',
        data: {
          'phone': phone.trim(),
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final devOtp = response.data?['devOtp'] ?? response.data?['DevOtp'];
      return devOtp?.toString();
    } catch (e) {
      throw Exception(readBackendMessage(e));
    }
  }

  /// Xác minh mã OTP số điện thoại.
  Future<void> verifyPhoneOtp(String phone, String otpCode) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.keyUserToken);
    if (token == null || token.isEmpty) {
      throw Exception('Bạn cần đăng nhập để thực hiện xác thực.');
    }

    try {
      await _apiService.dio.post<Map<String, dynamic>>(
        '/auth/verify-phone-otp',
        data: {
          'phone': phone.trim(),
          'otpCode': otpCode.trim(),
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      // Lưu vào local
      await prefs.setBool('verify_phone_status', true);
      await prefs.setString('verify_phone_number', phone.trim());
    } catch (e) {
      throw Exception(readBackendMessage(e));
    }
  }

  Future<void> verifyPhoneWithFirebase({
    required String phone,
    required String firebaseIdToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.keyUserToken);
    if (token == null || token.isEmpty) {
      throw Exception('Bạn cần đăng nhập để thực hiện xác thực.');
    }

    try {
      await _apiService.dio.post<Map<String, dynamic>>(
        '/auth/verify-phone-firebase',
        data: {
          'phone': phone.trim(),
          'firebaseIdToken': firebaseIdToken,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      await prefs.setBool('verify_phone_status', true);
      await prefs.setString('verify_phone_number', phone.trim());
    } catch (e) {
      throw Exception(readBackendMessage(e));
    }
  }

  /// Gửi mã OTP xác minh email.
  Future<void> sendEmailOtp(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.keyUserToken);
    if (token == null || token.isEmpty) {
      throw Exception('Bạn cần đăng nhập để thực hiện xác thực.');
    }

    try {
      await _apiService.dio.post<Map<String, dynamic>>(
        '/auth/send-email-otp',
        data: {
          'email': email.trim(),
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } catch (e) {
      throw Exception(readBackendMessage(e));
    }
  }

  /// Xác minh mã OTP email.
  Future<void> verifyEmailOtp(String email, String otpCode) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.keyUserToken);
    if (token == null || token.isEmpty) {
      throw Exception('Bạn cần đăng nhập để thực hiện xác thực.');
    }

    try {
      await _apiService.dio.post<Map<String, dynamic>>(
        '/auth/verify-email-otp',
        data: {
          'email': email.trim(),
          'otpCode': otpCode.trim(),
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      // Lưu vào local
      await prefs.setBool('verify_email_status', true);
      await prefs.setString('user_email', email.trim());
    } catch (e) {
      throw Exception(readBackendMessage(e));
    }
  }
}
