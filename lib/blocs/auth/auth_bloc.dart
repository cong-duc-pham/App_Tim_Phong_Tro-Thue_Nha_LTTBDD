// lib/blocs/auth/auth_bloc.dart

import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../repositories/auth_repository.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({required AuthRepository authRepository})
      : _authRepository = authRepository,
        super(const AuthInitial()) {
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthGoogleLoginRequested>(_onGoogleLoginRequested);
    on<AuthFacebookLoginRequested>(_onFacebookLoginRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthCheckRequested>(_onCheckRequested);
  }

  final AuthRepository _authRepository;

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final session = await _authRepository.signInWithEmailAndPassword(
        email: event.email,
        password: event.password,
      );
      emit(AuthAuthenticated(userId: session.userId, email: session.email));
    } on FirebaseAuthException catch (e) {
      emit(AuthFailure(message: _mapFirebaseAuthException(e)));
    } on FirebaseException catch (e) {
      emit(AuthFailure(message: _mapFirebaseServiceError(e)));
    } catch (e) {
      emit(AuthFailure(message: _authRepository.readBackendMessage(e)));
    }
  }

  Future<void> _onGoogleLoginRequested(
    AuthGoogleLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _signInWithSocialProvider(
      emit,
      () => _authRepository.signInWithGoogle(),
    );
  }

  Future<void> _onFacebookLoginRequested(
    AuthFacebookLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _signInWithSocialProvider(
      emit,
      () => _authRepository.signInWithFacebook(),
    );
  }

  Future<void> _signInWithSocialProvider(
    Emitter<AuthState> emit,
    Future<BackendAuthSession> Function() signIn,
  ) async {
    emit(const AuthLoading());
    try {
      final session = await signIn();
      emit(AuthAuthenticated(userId: session.userId, email: session.email));
    } on FirebaseAuthException catch (e) {
      emit(AuthFailure(message: _mapFirebaseAuthException(e)));
    } on FirebaseException catch (e) {
      emit(AuthFailure(message: _mapFirebaseServiceError(e)));
    } catch (e) {
      emit(AuthFailure(message: _authRepository.readBackendMessage(e)));
    }
  }

  Future<void> _onRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _authRepository.createUserWithEmailAndPassword(
        fullName: event.fullName,
        email: event.email,
        password: event.password,
        phone: event.phone,
      );
      await _authRepository.signOut();
      emit(const AuthRegisterSuccess());
    } on FirebaseAuthException catch (e) {
      emit(AuthFailure(message: _mapFirebaseAuthException(e)));
    } on FirebaseException catch (e) {
      emit(AuthFailure(message: _mapFirebaseServiceError(e)));
    } catch (e) {
      emit(AuthFailure(message: _authRepository.readBackendMessage(e)));
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _authRepository.signOut();
    emit(const AuthUnauthenticated());
  }

  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    final session = await _authRepository.getSavedSession();
    if (session != null) {
      emit(AuthAuthenticated(userId: session.userId, email: session.email));
      return;
    }

    final user = _authRepository.currentUser;
    if (user != null) {
      emit(AuthAuthenticated(userId: user.uid, email: user.email ?? ''));
    } else {
      emit(const AuthUnauthenticated());
    }
  }

  String _mapFirebaseError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Tài khoản không tồn tại.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email hoặc mật khẩu không đúng.';
      case 'email-already-in-use':
        return 'Email nay da duoc su dung.';
      case 'weak-password':
        return 'Mật khẩu quá yếu, tối thiểu 6 ký tự.';
      case 'invalid-email':
        return 'Định dạng email không hợp lệ.';
      case 'too-many-requests':
        return 'Quá nhiều lần thử. Vui lòng thử lại sau.';
      case 'network-request-failed':
        return 'Lỗi kết nối mạng. Kiểm tra internet của bạn.';
      case 'social-login-cancelled':
        return 'Bạn đã hủy đăng nhập.';
      case 'social-login-failed':
        return 'Không thể đăng nhập bằng tài khoản xã hội.';
      case 'google-login-failed':
        return 'Không thể đăng nhập bằng Google.';
      case 'google-missing-id-token':
        return 'Google Sign-In chưa được cấu hình đầy đủ trên Firebase.';
      case 'operation-not-allowed':
        return 'Phương thức đăng nhập này chưa được bật trong Firebase Authentication.';
      case 'configuration-not-found':
        return 'Chưa tìm thấy cấu hình đăng nhập cho ứng dụng này trên Firebase.';
      case 'account-exists-with-different-credential':
        return 'Email này đã được đăng ký bằng phương thức khác.';
      case 'firebase-user-missing':
      case 'firebase-token-missing':
        return 'Không lấy được thông tin đăng nhập Firebase.';
      default:
        return 'Đã xảy ra lỗi. Vui lòng thử lại.';
    }
  }

  String _mapFirebaseAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'social-login-failed':
      case 'google-login-failed':
      case 'google-missing-id-token':
      case 'operation-not-allowed':
      case 'invalid-credential':
      case 'configuration-not-found':
        return e.message ?? _mapFirebaseError(e.code);
      default:
        return _mapFirebaseError(e.code);
    }
  }

  String _mapFirebaseServiceError(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'Không có quyền ghi dữ liệu. Kiểm tra Firestore Rules.';
      case 'unavailable':
        return 'Dịch vụ Firebase tạm thời không khả dụng. Vui lòng thử lại.';
      case 'not-found':
        return 'Chưa tìm thấy cấu hình hoặc dữ liệu Firebase cần thiết.';
      default:
        return e.message ?? 'Lỗi Firebase (${e.code}). Vui lòng thử lại.';
    }
  }
}
