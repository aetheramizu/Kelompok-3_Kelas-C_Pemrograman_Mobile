import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Alphabet for 6-character circle invite codes (uppercase letters and digits,
/// excluding ambiguous characters `0`, `O`, `1`, and `I`).
const String kInviteCodeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

/// Default member capacity for a NearPace running circle.
const int kDefaultGroupMaxMembers = 50;

/// Normalizes a user-entered invite code by trimming whitespace and uppercasing.
String normalizeInviteCode(String raw) => raw.trim().toUpperCase();

/// Returns true if [raw] is a valid 6-character NearPace invite code.
bool isValidInviteCode(String raw) {
  final code = normalizeInviteCode(raw);
  if (code.length != 6) return false;
  for (var i = 0; i < code.length; i++) {
    if (!kInviteCodeAlphabet.contains(code[i])) return false;
  }
  return true;
}

/// Generates a random 6-character invite code using [kInviteCodeAlphabet].
String generateInviteCode({math.Random? random, int length = 6}) {
  final rng = random ?? math.Random.secure();
  final buffer = StringBuffer();
  for (var i = 0; i < length; i++) {
    buffer.write(kInviteCodeAlphabet[rng.nextInt(kInviteCodeAlphabet.length)]);
  }
  return buffer.toString();
}

/// Private running group / circle that tracks weekly distance rankings among
/// its members.
@immutable
class RunGroup {
  const RunGroup({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.ownerUid,
    required this.memberUids,
    required this.createdAt,
    this.description,
    this.weeklyGoalKm,
    this.maxMembers = kDefaultGroupMaxMembers,
  });

  final String id;
  final String name;
  final String? description;
  final String inviteCode;
  final String ownerUid;
  final List<String> memberUids;
  final double? weeklyGoalKm;
  final int maxMembers;
  final DateTime createdAt;

  int get memberCount => memberUids.length;
  bool get isFull => memberUids.length >= maxMembers;
  bool isOwner(String uid) => ownerUid == uid;
  bool hasMember(String uid) => memberUids.contains(uid);

  RunGroup copyWith({
    String? id,
    String? name,
    String? description,
    bool clearDescription = false,
    String? inviteCode,
    String? ownerUid,
    List<String>? memberUids,
    double? weeklyGoalKm,
    bool clearWeeklyGoal = false,
    int? maxMembers,
    DateTime? createdAt,
  }) {
    return RunGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      description: clearDescription ? null : (description ?? this.description),
      inviteCode: inviteCode ?? this.inviteCode,
      ownerUid: ownerUid ?? this.ownerUid,
      memberUids: memberUids ?? this.memberUids,
      weeklyGoalKm: clearWeeklyGoal
          ? null
          : (weeklyGoalKm ?? this.weeklyGoalKm),
      maxMembers: maxMembers ?? this.maxMembers,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name,
      if (description != null && description!.trim().isNotEmpty)
        'description': description!.trim(),
      'inviteCode': inviteCode,
      'ownerUid': ownerUid,
      'memberUids': memberUids,
      if (weeklyGoalKm != null && weeklyGoalKm! > 0)
        'weeklyGoalKm': weeklyGoalKm,
      'maxMembers': maxMembers,
      'createdAt': createdAt.toUtc().toIso8601String(),
    };
  }

  factory RunGroup.fromMap(String id, Map<String, dynamic> map) {
    final rawCreated = map['createdAt'];
    final DateTime createdAt;
    if (rawCreated is DateTime) {
      createdAt = rawCreated.toLocal();
    } else if (rawCreated is String) {
      createdAt = DateTime.tryParse(rawCreated)?.toLocal() ?? DateTime.now();
    } else {
      createdAt = DateTime.now();
    }

    final rawMembers = map['memberUids'];
    final memberUids = rawMembers is Iterable
        ? rawMembers.map((e) => e.toString()).toList(growable: false)
        : const <String>[];

    final rawDesc = map['description'] as String?;
    final rawGoal = (map['weeklyGoalKm'] as num?)?.toDouble();

    return RunGroup(
      id: id,
      name: (map['name'] as String? ?? '').trim(),
      description: (rawDesc != null && rawDesc.trim().isNotEmpty)
          ? rawDesc.trim()
          : null,
      inviteCode: normalizeInviteCode(map['inviteCode'] as String? ?? ''),
      ownerUid: map['ownerUid'] as String? ?? '',
      memberUids: memberUids,
      weeklyGoalKm: (rawGoal != null && rawGoal > 0) ? rawGoal : null,
      maxMembers:
          (map['maxMembers'] as num?)?.toInt() ?? kDefaultGroupMaxMembers,
      createdAt: createdAt,
    );
  }
}

/// Member's weekly aggregate standing inside a [RunGroup] (`groups/{groupId}/members/{uid}`).
@immutable
class GroupMemberRank {
  const GroupMemberRank({
    required this.uid,
    required this.displayName,
    required this.weekKey,
    required this.distanceM,
    required this.runCount,
    required this.updatedAt,
    this.avatarId,
    this.avgPaceSecPerKm,
  });

  final String uid;
  final String displayName;
  final String? avatarId;
  final String weekKey;
  final double distanceM;
  final int runCount;
  final double? avgPaceSecPerKm;
  final DateTime updatedAt;

  GroupMemberRank copyWith({
    String? uid,
    String? displayName,
    String? avatarId,
    String? weekKey,
    double? distanceM,
    int? runCount,
    double? avgPaceSecPerKm,
    bool clearAvgPace = false,
    DateTime? updatedAt,
  }) {
    return GroupMemberRank(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      avatarId: avatarId ?? this.avatarId,
      weekKey: weekKey ?? this.weekKey,
      distanceM: distanceM ?? this.distanceM,
      runCount: runCount ?? this.runCount,
      avgPaceSecPerKm: clearAvgPace
          ? null
          : (avgPaceSecPerKm ?? this.avgPaceSecPerKm),
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'uid': uid,
      'displayName': displayName.trim().isEmpty ? 'Runner' : displayName.trim(),
      if (avatarId != null) 'avatarId': avatarId,
      'weekKey': weekKey,
      'distanceM': distanceM,
      'runCount': runCount,
      if (avgPaceSecPerKm != null &&
          avgPaceSecPerKm! > 0 &&
          !avgPaceSecPerKm!.isNaN &&
          !avgPaceSecPerKm!.isInfinite)
        'avgPaceSecPerKm': avgPaceSecPerKm,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }

  factory GroupMemberRank.fromMap(
    Map<String, dynamic> map, {
    String? fallbackUid,
  }) {
    final rawUpdated = map['updatedAt'];
    final DateTime updatedAt;
    if (rawUpdated is DateTime) {
      updatedAt = rawUpdated.toLocal();
    } else if (rawUpdated is String) {
      updatedAt = DateTime.tryParse(rawUpdated)?.toLocal() ?? DateTime.now();
    } else {
      updatedAt = DateTime.now();
    }

    final rawPace = (map['avgPaceSecPerKm'] as num?)?.toDouble();

    return GroupMemberRank(
      uid: (map['uid'] as String?) ?? fallbackUid ?? '',
      displayName: (map['displayName'] as String?)?.trim().isNotEmpty == true
          ? (map['displayName'] as String).trim()
          : 'Runner',
      avatarId: map['avatarId'] as String?,
      weekKey: map['weekKey'] as String? ?? '',
      distanceM: (map['distanceM'] as num?)?.toDouble() ?? 0.0,
      runCount: (map['runCount'] as num?)?.toInt() ?? 0,
      avgPaceSecPerKm: (rawPace != null && rawPace > 0) ? rawPace : null,
      updatedAt: updatedAt,
    );
  }
}
