import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/run_group.dart';

export '../../domain/run_group.dart'
    show GroupErrorCode, GroupRepositoryException;

/// Contract for running circles / groups at `groups/{groupId}` and weekly
/// member rankings at `groups/{groupId}/members/{uid}`.
abstract interface class GroupRepository {
  Stream<List<RunGroup>> watchUserGroups(String uid);
  Stream<RunGroup?> watchGroup(String groupId);
  Stream<List<GroupMemberRank>> watchGroupMembers(
    String groupId,
    String weekKey,
  );

  Future<RunGroup> createGroup({
    required String ownerUid,
    required String ownerDisplayName,
    String? ownerAvatarId,
    required String name,
    String? description,
    double? weeklyGoalKm,
    required String weekKey,
    required double initialDistanceM,
    required int initialRunCount,
    double? initialAvgPaceSecPerKm,
    int maxMembers = kDefaultGroupMaxMembers,
  });

  Future<RunGroup> joinGroupByCode({
    required String inviteCode,
    required String uid,
    required String displayName,
    String? avatarId,
    required String weekKey,
    required double initialDistanceM,
    required int initialRunCount,
    double? initialAvgPaceSecPerKm,
  });

  Future<void> leaveGroup({required String groupId, required String uid});

  Future<void> deleteGroup({required String groupId, required String ownerUid});

  Future<void> upsertMemberStats({
    required String groupId,
    required GroupMemberRank member,
  });
}

/// Cloud Firestore implementation of [GroupRepository].
class FirestoreGroupRepository implements GroupRepository {
  FirestoreGroupRepository({FirebaseFirestore? firestore, this.random})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final math.Random? random;

  CollectionReference<Map<String, dynamic>> get _groupsCol =>
      _firestore.collection('groups');

  CollectionReference<Map<String, dynamic>> _membersCol(String groupId) =>
      _groupsCol.doc(groupId).collection('members');

  @override
  Stream<List<RunGroup>> watchUserGroups(String uid) {
    return _groupsCol.where('memberUids', arrayContains: uid).snapshots().map((
      snapshot,
    ) {
      final groups = snapshot.docs
          .map((doc) => _groupFromFirestore(doc.id, doc.data()))
          .toList(growable: true);
      groups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return groups;
    });
  }

  @override
  Stream<RunGroup?> watchGroup(String groupId) {
    return _groupsCol.doc(groupId).snapshots().map((doc) {
      final data = doc.data();
      if (!doc.exists || data == null) return null;
      return _groupFromFirestore(doc.id, data);
    });
  }

  @override
  Stream<List<GroupMemberRank>> watchGroupMembers(
    String groupId,
    String weekKey,
  ) {
    return _membersCol(groupId).snapshots().map((snapshot) {
      final members = snapshot.docs
          .map((doc) => _memberFromFirestore(doc.id, doc.data(), weekKey))
          .toList(growable: true);
      _sortMembers(members);
      return members;
    });
  }

  @override
  Future<RunGroup> createGroup({
    required String ownerUid,
    required String ownerDisplayName,
    String? ownerAvatarId,
    required String name,
    String? description,
    double? weeklyGoalKm,
    required String weekKey,
    required double initialDistanceM,
    required int initialRunCount,
    double? initialAvgPaceSecPerKm,
    int maxMembers = kDefaultGroupMaxMembers,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty || trimmedName.length > 50) {
      throw const GroupRepositoryException(
        GroupErrorCode.invalidInput,
        'Circle name must be between 1 and 50 characters.',
      );
    }
    final trimmedDesc = description?.trim();
    if (trimmedDesc != null && trimmedDesc.length > 160) {
      throw const GroupRepositoryException(
        GroupErrorCode.invalidInput,
        'Description must be 160 characters or fewer.',
      );
    }

    final inviteCode = await _generateUniqueInviteCode();
    final now = DateTime.now().toUtc();
    final docRef = _groupsCol.doc();

    final groupData = <String, dynamic>{
      'name': trimmedName,
      if (trimmedDesc != null && trimmedDesc.isNotEmpty)
        'description': trimmedDesc,
      'inviteCode': inviteCode,
      'ownerUid': ownerUid,
      'memberUids': <String>[ownerUid],
      if (weeklyGoalKm != null && weeklyGoalKm > 0)
        'weeklyGoalKm': weeklyGoalKm,
      'maxMembers': maxMembers,
      'createdAt': Timestamp.fromDate(now),
    };

    await docRef.set(groupData).timeout(const Duration(seconds: 8));

    final ownerMember = GroupMemberRank(
      uid: ownerUid,
      displayName: ownerDisplayName,
      avatarId: ownerAvatarId,
      weekKey: weekKey,
      distanceM: initialDistanceM,
      runCount: initialRunCount,
      avgPaceSecPerKm: initialAvgPaceSecPerKm,
      updatedAt: now.toLocal(),
    );
    await upsertMemberStats(groupId: docRef.id, member: ownerMember);

    return RunGroup(
      id: docRef.id,
      name: trimmedName,
      description: (trimmedDesc != null && trimmedDesc.isNotEmpty)
          ? trimmedDesc
          : null,
      inviteCode: inviteCode,
      ownerUid: ownerUid,
      memberUids: <String>[ownerUid],
      weeklyGoalKm: (weeklyGoalKm != null && weeklyGoalKm > 0)
          ? weeklyGoalKm
          : null,
      maxMembers: maxMembers,
      createdAt: now.toLocal(),
    );
  }

  @override
  Future<RunGroup> joinGroupByCode({
    required String inviteCode,
    required String uid,
    required String displayName,
    String? avatarId,
    required String weekKey,
    required double initialDistanceM,
    required int initialRunCount,
    double? initialAvgPaceSecPerKm,
  }) async {
    final code = normalizeInviteCode(inviteCode);
    if (!isValidInviteCode(code)) {
      throw const GroupRepositoryException(
        GroupErrorCode.invalidCode,
        'Enter a valid 6-character invite code.',
      );
    }

    final query = await _groupsCol
        .where('inviteCode', isEqualTo: code)
        .limit(1)
        .get()
        .timeout(const Duration(seconds: 8));

    if (query.docs.isEmpty) {
      throw const GroupRepositoryException(
        GroupErrorCode.notFound,
        'Circle code not found. Double-check the 6-character code.',
      );
    }

    final doc = query.docs.first;
    final group = _groupFromFirestore(doc.id, doc.data());

    if (group.hasMember(uid)) {
      throw const GroupRepositoryException(
        GroupErrorCode.alreadyMember,
        'You are already a member of this circle.',
      );
    }
    if (group.isFull) {
      throw GroupRepositoryException(
        GroupErrorCode.groupFull,
        'This circle is already full (${group.maxMembers} members).',
      );
    }

    try {
      await _groupsCol
          .doc(group.id)
          .update(<String, dynamic>{
            'memberUids': FieldValue.arrayUnion(<String>[uid]),
          })
          .timeout(const Duration(seconds: 8));
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw GroupRepositoryException(
          GroupErrorCode.groupFull,
          'Could not join this circle — it may have reached its member limit.',
        );
      }
      throw _mapFirebaseException(e, fallback: 'Could not join circle.');
    } on TimeoutException {
      throw const GroupRepositoryException(
        GroupErrorCode.unknown,
        'Joining circle timed out. Check your connection and try again.',
      );
    }

    final member = GroupMemberRank(
      uid: uid,
      displayName: displayName,
      avatarId: avatarId,
      weekKey: weekKey,
      distanceM: initialDistanceM,
      runCount: initialRunCount,
      avgPaceSecPerKm: initialAvgPaceSecPerKm,
      updatedAt: DateTime.now(),
    );
    await upsertMemberStats(groupId: group.id, member: member);

    return group.copyWith(memberUids: [...group.memberUids, uid]);
  }

  @override
  Future<void> leaveGroup({
    required String groupId,
    required String uid,
  }) async {
    final doc = await _groupsCol
        .doc(groupId)
        .get()
        .timeout(const Duration(seconds: 8));
    if (!doc.exists || doc.data() == null) {
      throw const GroupRepositoryException(
        GroupErrorCode.notFound,
        'Circle no longer exists.',
      );
    }
    final group = _groupFromFirestore(doc.id, doc.data()!);
    if (group.isOwner(uid)) {
      throw const GroupRepositoryException(
        GroupErrorCode.permissionDenied,
        'Circle owners cannot leave. Delete the circle instead.',
      );
    }

    try {
      await _membersCol(groupId)
          .doc(uid)
          .delete()
          .timeout(const Duration(seconds: 6));
    } catch (_) {
      // Proceed to remove membership even if member doc was missing.
    }

    await _groupsCol
        .doc(groupId)
        .update(<String, dynamic>{
          'memberUids': FieldValue.arrayRemove(<String>[uid]),
        })
        .timeout(const Duration(seconds: 8));
  }

  @override
  Future<void> deleteGroup({
    required String groupId,
    required String ownerUid,
  }) async {
    final doc = await _groupsCol
        .doc(groupId)
        .get()
        .timeout(const Duration(seconds: 8));
    if (!doc.exists || doc.data() == null) return;

    final group = _groupFromFirestore(doc.id, doc.data()!);
    if (!group.isOwner(ownerUid)) {
      throw const GroupRepositoryException(
        GroupErrorCode.permissionDenied,
        'Only the circle owner can delete this circle.',
      );
    }

    try {
      final memberDocs = await _membersCol(groupId)
          .get()
          .timeout(const Duration(seconds: 8));
      final batch = _firestore.batch();
      for (final memberDoc in memberDocs.docs) {
        batch.delete(memberDoc.reference);
      }
      batch.delete(_groupsCol.doc(groupId));
      await batch.commit().timeout(const Duration(seconds: 8));
    } on FirebaseException catch (e) {
      throw _mapFirebaseException(e, fallback: 'Could not delete circle.');
    } on TimeoutException {
      throw const GroupRepositoryException(
        GroupErrorCode.unknown,
        'Deleting circle timed out. Check your connection and try again.',
      );
    }
  }

  @override
  Future<void> upsertMemberStats({
    required String groupId,
    required GroupMemberRank member,
  }) async {
    final data = <String, dynamic>{
      'uid': member.uid,
      'displayName': _sanitizeDisplayName(member.displayName),
      if (member.avatarId != null) 'avatarId': member.avatarId,
      'weekKey': member.weekKey,
      'distanceM': member.distanceM,
      'runCount': member.runCount,
      if (member.avgPaceSecPerKm != null &&
          member.avgPaceSecPerKm! > 0 &&
          !member.avgPaceSecPerKm!.isNaN &&
          !member.avgPaceSecPerKm!.isInfinite)
        'avgPaceSecPerKm': member.avgPaceSecPerKm,
      'updatedAt': Timestamp.fromDate(member.updatedAt.toUtc()),
    };

    await _membersCol(groupId)
        .doc(member.uid)
        .set(data)
        .timeout(const Duration(seconds: 6));
  }

  Future<String> _generateUniqueInviteCode() async {
    for (var attempt = 0; attempt < 8; attempt++) {
      final candidate = generateInviteCode(random: random);
      final existing = await _groupsCol
          .where('inviteCode', isEqualTo: candidate)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 6));
      if (existing.docs.isEmpty) {
        return candidate;
      }
    }
    return generateInviteCode(random: random);
  }

  static RunGroup _groupFromFirestore(String id, Map<String, dynamic> map) {
    final rawCreated = map['createdAt'];
    final DateTime createdAt;
    if (rawCreated is Timestamp) {
      createdAt = rawCreated.toDate().toLocal();
    } else if (rawCreated is String) {
      createdAt = DateTime.tryParse(rawCreated)?.toLocal() ?? DateTime.now();
    } else {
      createdAt = DateTime.now();
    }

    return RunGroup.fromMap(id, <String, dynamic>{
      ...map,
      'createdAt': createdAt,
    });
  }

  static GroupMemberRank _memberFromFirestore(
    String docId,
    Map<String, dynamic> map,
    String targetWeekKey,
  ) {
    final rawUpdated = map['updatedAt'];
    final DateTime updatedAt;
    if (rawUpdated is Timestamp) {
      updatedAt = rawUpdated.toDate().toLocal();
    } else if (rawUpdated is String) {
      updatedAt = DateTime.tryParse(rawUpdated)?.toLocal() ?? DateTime.now();
    } else {
      updatedAt = DateTime.now();
    }

    final parsed = GroupMemberRank.fromMap(<String, dynamic>{
      ...map,
      'updatedAt': updatedAt,
    }, fallbackUid: docId);

    if (parsed.weekKey != targetWeekKey) {
      return parsed.copyWith(
        weekKey: targetWeekKey,
        distanceM: 0,
        runCount: 0,
        clearAvgPace: true,
      );
    }
    return parsed;
  }
}

/// In-memory mock implementation of [GroupRepository] for local preview and tests.
class MockGroupRepository implements GroupRepository {
  MockGroupRepository({
    List<RunGroup>? initialGroups,
    Map<String, List<GroupMemberRank>>? initialMembers,
    this.random,
  }) {
    if (initialGroups != null) {
      for (final group in initialGroups) {
        _groups[group.id] = group;
        _members.putIfAbsent(group.id, () => <String, GroupMemberRank>{});
      }
    }
    if (initialMembers != null) {
      initialMembers.forEach((groupId, list) {
        final map = _members.putIfAbsent(
          groupId,
          () => <String, GroupMemberRank>{},
        );
        for (final member in list) {
          map[member.uid] = member;
        }
      });
    }
  }

  final math.Random? random;
  final Map<String, RunGroup> _groups = <String, RunGroup>{};
  final Map<String, Map<String, GroupMemberRank>> _members =
      <String, Map<String, GroupMemberRank>>{};

  final StreamController<void> _changesController =
      StreamController<void>.broadcast();
  int _idCounter = 1;

  List<RunGroup> _groupsForUser(String uid) {
    final list = _groups.values
        .where((g) => g.hasMember(uid))
        .toList(growable: true);
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(list);
  }

  List<GroupMemberRank> _membersForGroup(String groupId, String weekKey) {
    final map = _members[groupId];
    if (map == null) return const <GroupMemberRank>[];
    final list = map.values
        .map((m) {
          if (m.weekKey != weekKey) {
            return m.copyWith(
              weekKey: weekKey,
              distanceM: 0,
              runCount: 0,
              clearAvgPace: true,
            );
          }
          return m;
        })
        .toList(growable: true);
    _sortMembers(list);
    return List.unmodifiable(list);
  }

  void _emitChange() {
    if (!_changesController.isClosed) {
      _changesController.add(null);
    }
  }

  @override
  Stream<List<RunGroup>> watchUserGroups(String uid) {
    late StreamController<List<RunGroup>> controller;
    StreamSubscription<void>? sub;
    controller = StreamController<List<RunGroup>>.broadcast(
      onListen: () {
        controller.add(_groupsForUser(uid));
        sub = _changesController.stream.listen((_) {
          if (!controller.isClosed) {
            controller.add(_groupsForUser(uid));
          }
        });
      },
      onCancel: () {
        sub?.cancel();
      },
    );
    return controller.stream;
  }

  @override
  Stream<RunGroup?> watchGroup(String groupId) {
    late StreamController<RunGroup?> controller;
    StreamSubscription<void>? sub;
    controller = StreamController<RunGroup?>.broadcast(
      onListen: () {
        controller.add(_groups[groupId]);
        sub = _changesController.stream.listen((_) {
          if (!controller.isClosed) {
            controller.add(_groups[groupId]);
          }
        });
      },
      onCancel: () {
        sub?.cancel();
      },
    );
    return controller.stream;
  }

  @override
  Stream<List<GroupMemberRank>> watchGroupMembers(
    String groupId,
    String weekKey,
  ) {
    late StreamController<List<GroupMemberRank>> controller;
    StreamSubscription<void>? sub;
    controller = StreamController<List<GroupMemberRank>>.broadcast(
      onListen: () {
        controller.add(_membersForGroup(groupId, weekKey));
        sub = _changesController.stream.listen((_) {
          if (!controller.isClosed) {
            controller.add(_membersForGroup(groupId, weekKey));
          }
        });
      },
      onCancel: () {
        sub?.cancel();
      },
    );
    return controller.stream;
  }

  @override
  Future<RunGroup> createGroup({
    required String ownerUid,
    required String ownerDisplayName,
    String? ownerAvatarId,
    required String name,
    String? description,
    double? weeklyGoalKm,
    required String weekKey,
    required double initialDistanceM,
    required int initialRunCount,
    double? initialAvgPaceSecPerKm,
    int maxMembers = kDefaultGroupMaxMembers,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty || trimmedName.length > 50) {
      throw const GroupRepositoryException(
        GroupErrorCode.invalidInput,
        'Circle name must be between 1 and 50 characters.',
      );
    }
    final trimmedDesc = description?.trim();
    if (trimmedDesc != null && trimmedDesc.length > 160) {
      throw const GroupRepositoryException(
        GroupErrorCode.invalidInput,
        'Description must be 160 characters or fewer.',
      );
    }

    var inviteCode = generateInviteCode(random: random);
    var attempts = 0;
    while (_groups.values.any((g) => g.inviteCode == inviteCode) &&
        attempts < 20) {
      inviteCode = generateInviteCode(random: random);
      attempts++;
    }

    final id = 'circle_${_idCounter++}';
    final now = DateTime.now();
    final group = RunGroup(
      id: id,
      name: trimmedName,
      description: (trimmedDesc != null && trimmedDesc.isNotEmpty)
          ? trimmedDesc
          : null,
      inviteCode: inviteCode,
      ownerUid: ownerUid,
      memberUids: <String>[ownerUid],
      weeklyGoalKm: (weeklyGoalKm != null && weeklyGoalKm > 0)
          ? weeklyGoalKm
          : null,
      maxMembers: maxMembers,
      createdAt: now,
    );

    _groups[id] = group;
    _members[id] = <String, GroupMemberRank>{
      ownerUid: GroupMemberRank(
        uid: ownerUid,
        displayName: ownerDisplayName,
        avatarId: ownerAvatarId,
        weekKey: weekKey,
        distanceM: initialDistanceM,
        runCount: initialRunCount,
        avgPaceSecPerKm: initialAvgPaceSecPerKm,
        updatedAt: now,
      ),
    };
    _emitChange();
    return group;
  }

  @override
  Future<RunGroup> joinGroupByCode({
    required String inviteCode,
    required String uid,
    required String displayName,
    String? avatarId,
    required String weekKey,
    required double initialDistanceM,
    required int initialRunCount,
    double? initialAvgPaceSecPerKm,
  }) async {
    final code = normalizeInviteCode(inviteCode);
    if (!isValidInviteCode(code)) {
      throw const GroupRepositoryException(
        GroupErrorCode.invalidCode,
        'Enter a valid 6-character invite code.',
      );
    }

    RunGroup? found;
    for (final group in _groups.values) {
      if (group.inviteCode == code) {
        found = group;
        break;
      }
    }
    if (found == null) {
      throw const GroupRepositoryException(
        GroupErrorCode.notFound,
        'Circle code not found. Double-check the 6-character code.',
      );
    }
    if (found.hasMember(uid)) {
      throw const GroupRepositoryException(
        GroupErrorCode.alreadyMember,
        'You are already a member of this circle.',
      );
    }
    if (found.isFull) {
      throw GroupRepositoryException(
        GroupErrorCode.groupFull,
        'This circle is already full (${found.maxMembers} members).',
      );
    }

    final updated = found.copyWith(memberUids: [...found.memberUids, uid]);
    _groups[found.id] = updated;
    final memberMap = _members.putIfAbsent(
      found.id,
      () => <String, GroupMemberRank>{},
    );
    memberMap[uid] = GroupMemberRank(
      uid: uid,
      displayName: displayName,
      avatarId: avatarId,
      weekKey: weekKey,
      distanceM: initialDistanceM,
      runCount: initialRunCount,
      avgPaceSecPerKm: initialAvgPaceSecPerKm,
      updatedAt: DateTime.now(),
    );
    _emitChange();
    return updated;
  }

  @override
  Future<void> leaveGroup({
    required String groupId,
    required String uid,
  }) async {
    final group = _groups[groupId];
    if (group == null) {
      throw const GroupRepositoryException(
        GroupErrorCode.notFound,
        'Circle no longer exists.',
      );
    }
    if (group.isOwner(uid)) {
      throw const GroupRepositoryException(
        GroupErrorCode.permissionDenied,
        'Circle owners cannot leave. Delete the circle instead.',
      );
    }

    _groups[groupId] = group.copyWith(
      memberUids: group.memberUids
          .where((id) => id != uid)
          .toList(growable: false),
    );
    _members[groupId]?.remove(uid);
    _emitChange();
  }

  @override
  Future<void> deleteGroup({
    required String groupId,
    required String ownerUid,
  }) async {
    final group = _groups[groupId];
    if (group == null) return;
    if (!group.isOwner(ownerUid)) {
      throw const GroupRepositoryException(
        GroupErrorCode.permissionDenied,
        'Only the circle owner can delete this circle.',
      );
    }
    _groups.remove(groupId);
    _members.remove(groupId);
    _emitChange();
  }

  @override
  Future<void> upsertMemberStats({
    required String groupId,
    required GroupMemberRank member,
  }) async {
    if (!_groups.containsKey(groupId)) return;
    final map = _members.putIfAbsent(
      groupId,
      () => <String, GroupMemberRank>{},
    );
    map[member.uid] = member;
    _emitChange();
  }

  void dispose() {
    _changesController.close();
  }
}

void _sortMembers(List<GroupMemberRank> members) {
  members.sort((a, b) {
    final distCmp = b.distanceM.compareTo(a.distanceM);
    if (distCmp != 0) return distCmp;
    return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
  });
}

String _sanitizeDisplayName(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return 'Runner';
  return trimmed.length <= 40 ? trimmed : trimmed.substring(0, 40);
}

GroupRepositoryException _mapFirebaseException(
  FirebaseException e, {
  required String fallback,
}) {
  if (e.code == 'permission-denied') {
    return const GroupRepositoryException(
      GroupErrorCode.permissionDenied,
      'You do not have permission to perform this circle action.',
    );
  }
  if (e.code == 'not-found') {
    return const GroupRepositoryException(
      GroupErrorCode.notFound,
      'Circle no longer exists.',
    );
  }
  return GroupRepositoryException(
    GroupErrorCode.unknown,
    e.message?.isNotEmpty == true ? e.message! : fallback,
  );
}
