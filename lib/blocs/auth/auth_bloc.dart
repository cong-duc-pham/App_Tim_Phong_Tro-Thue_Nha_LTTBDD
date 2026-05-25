// lib/blocs/auth/auth_bloc.dart

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../repositories/auth_repository.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;

  AuthBloc({required AuthRepository authRepository})
      : _authRepository = authRepository,
        super(const AuthInitial()) {
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthCheckRequested>(_onCheckRequested);
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final credential = await _authRepository.signInWithEmailAndPassword(
        email: event.email,
        password: event.password,
      );
      emit(AuthAuthenticated(
        userId: credential.user!.uid,
        email: credential.user!.email ?? '',
      ));
    } on FirebaseAuthException catch (e) {
      emit(AuthFailure(message: _mapFirebaseError(e.code)));
    } on FirebaseException catch (e) {
      emit(AuthFailure(message: _mapFirebaseServiceError(e)));
    } catch (_) {
      emit(const AuthFailure(message: 'Đã xảy ra lỗi. Vui lòng thử lại.'));
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
      emit(AuthFailure(message: _mapFirebaseError(e.code)));
    } on FirebaseException catch (e) {
      emit(AuthFailure(message: _mapFirebaseServiceError(e)));
    } catch (_) {
      emit(const AuthFailure(message: 'Đã xảy ra lỗi. Vui lòng thử lại.'));
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
        return 'Mật khẩu không đúng.';
      case 'invalid-credential':
        return 'Email hoặc mật khẩu không đúng.';
      case 'email-already-in-use':
        return 'Email này đã được sử dụng.';
      case 'weak-password':
        return 'Mật khẩu quá yếu (tối thiểu 6 ký tự).';
      case 'invalid-email':
        return 'Định dạng email không hợp lệ.';
      case 'too-many-requests':
        return 'Quá nhiều lần thử. Vui lòng thử lại sau.';
      case 'network-request-failed':
        return 'Lỗi kết nối mạng. Kiểm tra internet của bạn.';
      default:
        return 'Đã xảy ra lỗi. Vui lòng thử lại.';
    }
  }

  String _mapFirebaseServiceError(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'Không có quyền ghi dữ liệu. Kiểm tra Firestore Rules.';
      case 'unavailable':
        return 'Dịch vụ Firebase tạm thời không khả dụng. Vui lòng thử lại.';
      case 'not-found':
        return 'Chưa tìm thấy cấu hình/dữ liệu Firebase cần thiết.';
      default:
        return e.message ?? 'Lỗi Firebase (${e.code}). Vui lòng thử lại.';
    }
  }
}
