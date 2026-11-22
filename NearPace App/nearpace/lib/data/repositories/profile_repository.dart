import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/user_profile.dart';

/// Contract for runner profile storage at `users/{uid}`.
abstract interface class ProfileRepository {
  Stream<UserProfile?> watchProfile(String uid);
  Future<UserProfile?> getProfile(String uid);
  Future<void> upsertProfile(UserProfile profile, {bool isNew = false});
  Future<void> updateIdentity(
    String uid, {
    required String displayName,
    required String city,
  });
  Future<void> setShowOnLeaderboard(String uid, bool show);
  Future<void> updateFcmToken(String uid, String? token);
}

/// Cloud Firestore implementation of [ProfileRepository].
class FirestoreProfileRepository implements ProfileRepository {
  FirestoreProfileRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _firestore.collection('users').doc(uid);

  @override
  Stream<UserProfile?> watchProfile(String uid) {
    return _userDoc(uid).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (!snapshot.exists || data == null) return null;
      return UserProfile.fromMap(uid, data);
    });
  }

  @override
  Future<UserProfile?> getProfile(String uid) async {
    final snapshot = await _userDoc(uid)
        .get()
        .timeout(const Duration(seconds: 6));
    final data = snapshot.data();
    if (!snapshot.exists || data == null) return null;
    return UserProfile.fromMap(uid, data);
  }

  @override
  Future<void> upsertProfile(UserProfile profile, {bool isNew = false}) async {
    final data = profile.toMap();
    if (isNew) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _userDoc(profile.uid)
        .set(data, SetOptions(merge: true))
        .timeout(const Duration(seconds: 6));
  }

  @override
  Future<void> updateIdentity(
    String uid, {
    required String displayName,
    required String city,
  }) async {
    await _userDoc(uid).set({
      'displayName': displayName.trim(),
      'city': city.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> setShowOnLeaderboard(String uid, bool show) async {
    await _userDoc(uid).set({
      'showOnLeaderboard': show,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> updateFcmToken(String uid, String? token) async {
    await _userDoc(uid).set({
      'fcmToken': token,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

/// In-memory mock implementation of [ProfileRepository] for tests and local preview.
class MockProfileRepository implements ProfileRepository {
  MockProfileRepository({UserProfile? initialProfile})
    : _profile = initialProfile,
      _controller = StreamController<UserProfile?>.broadcast();

  UserProfile? _profile;
  final StreamController<UserProfile?> _controller;

  @override
  Stream<UserProfile?> watchProfile(String uid) {
    // Emit current value asynchronously so initial stream listener receives it.
    scheduleMicrotask(() {
      if (!_controller.isClosed) {
        _controller.add(_profile);
      }
    });
    return _controller.stream;
  }

  @override
  Future<UserProfile?> getProfile(String uid) async => _profile;

  @override
  Future<void> upsertProfile(UserProfile profile, {bool isNew = false}) async {
    _profile = profile;
    _controller.add(profile);
  }

  @override
  Future<void> updateIdentity(
    String uid, {
    required String displayName,
    required String city,
  }) async {
    if (_profile != null) {
      _profile = _profile!.copyWith(
        displayName: displayName.trim(),
        city: city.trim(),
      );
      _controller.add(_profile);
    }
  }

  @override
  Future<void> setShowOnLeaderboard(String uid, bool show) async {
    if (_profile != null) {
      _profile = _profile!.copyWith(showOnLeaderboard: show);
      _controller.add(_profile);
    }
  }

  @override
  Future<void> updateFcmToken(String uid, String? token) async {
    if (_profile != null) {
      _profile = _profile!.copyWith(fcmToken: token);
      _controller.add(_profile);
    }
  }

  void dispose() {
    _controller.close();
  }
}
