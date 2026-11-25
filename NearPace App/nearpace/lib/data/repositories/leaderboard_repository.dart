import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/leaderboard_entry.dart';

/// Contract for public weekly leaderboard aggregates at `leaderboard/{weekKey}_{uid}`.
abstract interface class LeaderboardRepository {
  Stream<List<LeaderboardEntry>> watchWeeklyLeaderboard(String weekKey);
  Future<void> upsertEntry(LeaderboardEntry entry);
  Future<void> deleteEntry({required String weekKey, required String uid});
}

/// Cloud Firestore implementation of [LeaderboardRepository].
class FirestoreLeaderboardRepository implements LeaderboardRepository {
  FirestoreLeaderboardRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _leaderboardCol =>
      _firestore.collection('leaderboard');

  @override
  Stream<List<LeaderboardEntry>> watchWeeklyLeaderboard(String weekKey) {
    return _leaderboardCol.where('weekKey', isEqualTo: weekKey).snapshots().map(
      (snapshot) {
        final list = snapshot.docs
            .map((doc) => _entryFromFirestore(doc.data()))
            .toList(growable: true);
        list.sort((a, b) => b.distanceM.compareTo(a.distanceM));
        return list;
      },
    );
  }

  @override
  Future<void> upsertEntry(LeaderboardEntry entry) async {
    final docId = '${entry.weekKey}_${entry.uid}';
    final data = <String, dynamic>{
      'uid': entry.uid,
      'displayName': entry.displayName.trim().isEmpty
          ? 'Runner'
          : entry.displayName.trim(),
      'city': entry.city.trim(),
      'weekKey': entry.weekKey,
      'distanceM': entry.distanceM,
      'runCount': entry.runCount,
      'updatedAt': Timestamp.fromDate(entry.updatedAt.toUtc()),
      if (entry.avatarId != null) 'avatarId': entry.avatarId,
    };
    await _leaderboardCol
        .doc(docId)
        .set(data)
        .timeout(const Duration(seconds: 6));
  }

  @override
  Future<void> deleteEntry({
    required String weekKey,
    required String uid,
  }) async {
    final docId = '${weekKey}_$uid';
    await _leaderboardCol.doc(docId).delete();
  }

  static LeaderboardEntry _entryFromFirestore(Map<String, dynamic> map) {
    final rawUpdated = map['updatedAt'];
    final DateTime updatedAt;
    if (rawUpdated is Timestamp) {
      updatedAt = rawUpdated.toDate().toLocal();
    } else if (rawUpdated is String) {
      updatedAt = DateTime.tryParse(rawUpdated)?.toLocal() ?? DateTime.now();
    } else {
      updatedAt = DateTime.now();
    }

    return LeaderboardEntry(
      uid: map['uid'] as String? ?? '',
      displayName: map['displayName'] as String? ?? 'Runner',
      city: map['city'] as String? ?? '',
      weekKey: map['weekKey'] as String? ?? '',
      distanceM: (map['distanceM'] as num?)?.toDouble() ?? 0.0,
      runCount: (map['runCount'] as num?)?.toInt() ?? 0,
      updatedAt: updatedAt,
      avatarId: map['avatarId'] as String?,
    );
  }
}

/// In-memory mock implementation of [LeaderboardRepository] for tests and local preview.
class MockLeaderboardRepository implements LeaderboardRepository {
  MockLeaderboardRepository({List<LeaderboardEntry>? initialEntries})
    : _entries = List<LeaderboardEntry>.from(initialEntries ?? const []),
      _controller = StreamController<List<LeaderboardEntry>>.broadcast();

  final List<LeaderboardEntry> _entries;
  final StreamController<List<LeaderboardEntry>> _controller;

  @override
  Stream<List<LeaderboardEntry>> watchWeeklyLeaderboard(String weekKey) {
    scheduleMicrotask(() {
      if (!_controller.isClosed) {
        final filtered = _entries.where((e) => e.weekKey == weekKey).toList()
          ..sort((a, b) => b.distanceM.compareTo(a.distanceM));
        _controller.add(List.unmodifiable(filtered));
      }
    });
    return _controller.stream;
  }

  @override
  Future<void> upsertEntry(LeaderboardEntry entry) async {
    final index = _entries.indexWhere((e) => e.documentId == entry.documentId);
    if (index >= 0) {
      _entries[index] = entry;
    } else {
      _entries.add(entry);
    }
    _notify(entry.weekKey);
  }

  @override
  Future<void> deleteEntry({
    required String weekKey,
    required String uid,
  }) async {
    final docId = '${weekKey}_$uid';
    _entries.removeWhere((e) => e.documentId == docId);
    _notify(weekKey);
  }

  void _notify(String weekKey) {
    final filtered = _entries.where((e) => e.weekKey == weekKey).toList()
      ..sort((a, b) => b.distanceM.compareTo(a.distanceM));
    _controller.add(List.unmodifiable(filtered));
  }

  void dispose() {
    _controller.close();
  }
}
