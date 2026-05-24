// lib/blocs/auth/auth_state.dart

part of 'auth_bloc.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  final String userId;
  final String email;

  const AuthAuthenticated({required this.userId, required this.email});

  @override
  List<Object?> get props => [userId, email];
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthLoginSuccess extends AuthState {
  const AuthLoginSuccess();
}

class AuthRegisterSuccess extends AuthState {
  const AuthRegisterSuccess();
}

class AuthFailure extends AuthState {
  final String message;

  const AuthFailure({required this.message});

  @override
  List<Object?> get props => [message];
}
