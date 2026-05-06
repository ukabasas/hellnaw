import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nova3d_frontend/features/auth/data/auth_service.dart';
import 'package:nova3d_frontend/shared/models/user_model.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

// ── Auth state ────────────────────────────────────────────────────────────────

enum AuthStatus { loading, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? error;

  const AuthState({
    required this.status,
    this.user,
    this.error,
  });

  const AuthState.loading()
      : status = AuthStatus.loading,
        user = null,
        error = null;

  const AuthState.unauthenticated([String? err])
      : status = AuthStatus.unauthenticated,
        user = null,
        error = err;

  const AuthState.authenticated(UserModel u)
      : status = AuthStatus.authenticated,
        user = u,
        error = null;
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _service;

  AuthNotifier(this._service) : super(const AuthState.loading()) {
    _init();
  }

  Future<void> _init() async {
    try {
      final user = await _service.getCurrentUser();
      state = AuthState.authenticated(user);
    } catch (_) {
      state = const AuthState.unauthenticated();
    }
  }

  Future<void> signIn(String email, String password) async {
    state = const AuthState.loading();
    try {
      await _service.signIn(email, password);
      final user = await _service.getCurrentUser();
      state = AuthState.authenticated(user);
    } on AuthException catch (e) {
      state = AuthState.unauthenticated(e.message);
      rethrow;
    }
  }

  Future<UserModel> signUp(String email, String password) async {
    try {
      return await _service.signUp(email, password);
    } on AuthException {
      rethrow;
    }
  }

  Future<void> handleOAuthCallback(String token) async {
    state = const AuthState.loading();
    try {
      await _service.handleOAuthCallback(token);
      final user = await _service.getCurrentUser();
      state = AuthState.authenticated(user);
    } on AuthException catch (e) {
      state = AuthState.unauthenticated(e.message);
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _service.signOut();
    state = const AuthState.unauthenticated();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authServiceProvider));
});
