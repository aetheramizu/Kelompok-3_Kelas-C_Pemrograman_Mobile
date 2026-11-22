import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

/// Contract for authentication operations.
abstract interface class AuthRepository {
  Stream<String?> authStateChanges();
  String? get currentUid;
  Future<String> signIn({required String email, required String password});
  Future<String> signUp({required String email, required String password});
  Future<void> signOut();
}

/// Firebase Authentication implementation of [AuthRepository].
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  Stream<String?> authStateChanges() =>
      _auth.authStateChanges().map((user) => user?.uid);

  @override
  String? get currentUid => _auth.currentUser?.uid;

  @override
  Future<String> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = credential.user?.uid;
      if (uid == null) {
        throw const AuthException('Sign in failed: no user ID returned.');
      }
      return uid;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e));
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException(e.toString());
    }
  }

  @override
  Future<String> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = credential.user?.uid;
      if (uid == null) {
        throw const AuthException('Sign up failed: no user ID returned.');
      }
      return uid;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e));
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException(e.toString());
    }
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
  }

  static String _mapFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password. Please verify your credentials.';
      case 'email-already-in-use':
        return 'An account already exists with this email address. Please sign in.';
      case 'invalid-email':
        return 'The email address format is invalid.';
      case 'weak-password':
        return 'Password is too weak. Please use at least 6 characters.';
      case 'network-request-failed':
        return 'Network connection error. Check your internet connection and try again.';
      case 'operation-not-allowed':
        return 'Email/Password sign-in is disabled in Firebase Console. Please enable it in Authentication > Sign-in method.';
      case 'too-many-requests':
        return 'Too many unsuccessful attempts. Please try again later.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      default:
        return e.message ?? 'Authentication failed (${e.code}).';
    }
  }
}

/// In-memory mock implementation of [AuthRepository] for tests and local preview.
class MockAuthRepository implements AuthRepository {
  MockAuthRepository({
    String? initialUid,
    StreamController<String?>? controller,
  }) : _currentUid = initialUid,
       _controller = controller ?? StreamController<String?>.broadcast();

  String? _currentUid;
  final StreamController<String?> _controller;

  @override
  Stream<String?> authStateChanges() => _controller.stream;

  @override
  String? get currentUid => _currentUid;

  @override
  Future<String> signIn({
    required String email,
    required String password,
  }) async {
    final uid = 'mock-${email.hashCode.abs()}';
    _currentUid = uid;
    _controller.add(uid);
    return uid;
  }

  @override
  Future<String> signUp({
    required String email,
    required String password,
  }) async {
    final uid = 'mock-${email.hashCode.abs()}';
    _currentUid = uid;
    _controller.add(uid);
    return uid;
  }

  @override
  Future<void> signOut() async {
    _currentUid = null;
    _controller.add(null);
  }

  void dispose() {
    _controller.close();
  }
}

/// User-facing typed exception for auth failures.
class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
