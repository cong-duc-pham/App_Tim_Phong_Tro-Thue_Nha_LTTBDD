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
        return 'Tai khoan khong ton tai.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email hoac mat khau khong dung.';
      case 'email-already-in-use':
        return 'Email nay da duoc su dung.';
      case 'weak-password':
        return 'Mat khau qua yeu, toi thieu 6 ky tu.';
      case 'invalid-email':
        return 'Dinh dang email khong hop le.';
      case 'too-many-requests':
        return 'Qua nhieu lan thu. Vui long thu lai sau.';
      case 'network-request-failed':
        return 'Loi ket noi mang. Kiem tra internet cua ban.';
      case 'social-login-cancelled':
        return 'Ban da huy dang nhap.';
      case 'social-login-failed':
        return 'Khong the dang nhap bang tai khoan xa hoi.';
      case 'google-login-failed':
        return 'Khong the dang nhap bang Google.';
      case 'google-missing-id-token':
        return 'Google Sign-In chua duoc cau hinh day du tren Firebase.';
      case 'operation-not-allowed':
        return 'Phuong thuc dang nhap nay chua duoc bat trong Firebase Authentication.';
      case 'configuration-not-found':
        return 'Chua tim thay cau hinh dang nhap cho ung dung nay tren Firebase.';
      case 'account-exists-with-different-credential':
        return 'Email nay da duoc dang ky bang phuong thuc khac.';
      case 'firebase-user-missing':
      case 'firebase-token-missing':
        return 'Khong lay duoc thong tin dang nhap Firebase.';
      default:
        return 'Da xay ra loi. Vui long thu lai.';
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
        return 'Khong co quyen ghi du lieu. Kiem tra Firestore Rules.';
      case 'unavailable':
        return 'Dich vu Firebase tam thoi khong kha dung. Vui long thu lai.';
      case 'not-found':
        return 'Chua tim thay cau hinh hoac du lieu Firebase can thiet.';
      default:
        return e.message ?? 'Loi Firebase (${e.code}). Vui long thu lai.';
    }
  }
}
