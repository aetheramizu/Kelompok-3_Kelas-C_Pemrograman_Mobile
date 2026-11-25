import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nearpace/app.dart';
import 'package:nearpace/config/firebase_bootstrap.dart';
import 'package:nearpace/data/repositories/activity_repository.dart';
import 'package:nearpace/data/repositories/group_repository.dart';
import 'package:nearpace/domain/activity.dart';
import 'package:nearpace/domain/geo_point.dart';
import 'package:nearpace/domain/run_group.dart';
import 'package:nearpace/services/connectivity_service.dart';
import 'package:nearpace/services/pending_sync_storage.dart';
import 'package:nearpace/state/nearpace_controller.dart';
import 'package:nearpace/ui/widgets/nearpace_avatar.dart';
import 'package:nearpace/utils/formatters.dart';

void main() {
  final fixedClock = DateTime(2026, 11, 24, 9, 0);
  final weekKey = NearPaceFormatters.isoWeekKey(fixedClock);

  void usePhoneViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  // ---------------------------------------------------------------------------
  // Domain Models & Invite Code Validation
  // ---------------------------------------------------------------------------

  group('Phase 4 - RunGroup & GroupMemberRank Domain Models', () {
    test(
      'generateInviteCode produces 6-char uppercase codes excluding 0/O/1/I',
      () {
        final rng = math.Random(42);
        const forbidden = {'0', 'O', '1', 'I'};

        for (var i = 0; i < 200; i++) {
          final code = generateInviteCode(random: rng);
          expect(code.length, 6);
          expect(isValidInviteCode(code), isTrue);
          for (final ch in code.split('')) {
            expect(
              forbidden.contains(ch),
              isFalse,
              reason: 'Ambiguous character $ch must not appear in $code',
            );
          }
        }
      },
    );

    test('isValidInviteCode rejects ambiguous chars and invalid lengths', () {
      expect(isValidInviteCode('NDP4CE'), isTrue);
      expect(isValidInviteCode(' ndp4ce '), isTrue);
      expect(isValidInviteCode('NDP0CE'), isFalse);
      expect(isValidInviteCode('NDPOCE'), isFalse);
      expect(isValidInviteCode('NDP1CE'), isFalse);
      expect(isValidInviteCode('NDPICE'), isFalse);
      expect(isValidInviteCode('SHORT'), isFalse);
      expect(isValidInviteCode('TOOLONG'), isFalse);
    });

    test('RunGroup round-trips toMap/fromMap and helpers', () {
      final group = RunGroup(
        id: 'grp_1',
        name: 'Makassar Dawn',
        description: 'Early morning 5K crew',
        inviteCode: 'MKS5KM',
        ownerUid: 'u1',
        memberUids: const ['u1', 'u2'],
        weeklyGoalKm: 25.0,
        maxMembers: 2,
        createdAt: DateTime.utc(2026, 11, 20, 6, 0),
      );

      expect(group.memberCount, 2);
      expect(group.isFull, isTrue);
      expect(group.isOwner('u1'), isTrue);
      expect(group.isOwner('u2'), isFalse);
      expect(group.hasMember('u2'), isTrue);

      final restored = RunGroup.fromMap('grp_1', group.toMap());
      expect(restored.id, 'grp_1');
      expect(restored.name, 'Makassar Dawn');
      expect(restored.description, 'Early morning 5K crew');
      expect(restored.inviteCode, 'MKS5KM');
      expect(restored.weeklyGoalKm, 25.0);
      expect(restored.maxMembers, 2);
      expect(restored.memberUids, ['u1', 'u2']);
    });

    test(
      'GroupMemberRank round-trips optional avatarId and avgPaceSecPerKm',
      () {
        final rank = GroupMemberRank(
          uid: 'u1',
          displayName: 'Alief Pratama',
          avatarId: 'volt_sprinter',
          weekKey: weekKey,
          distanceM: 12450,
          runCount: 3,
          avgPaceSecPerKm: 318.5,
          updatedAt: DateTime.utc(2026, 11, 24, 7, 0),
        );

        final restored = GroupMemberRank.fromMap(rank.toMap());
        expect(restored.uid, 'u1');
        expect(restored.displayName, 'Alief Pratama');
        expect(restored.avatarId, 'volt_sprinter');
        expect(restored.distanceM, 12450);
        expect(restored.runCount, 3);
        expect(restored.avgPaceSecPerKm, 318.5);

        final legacy = GroupMemberRank.fromMap({
          'displayName': 'Legacy Runner',
          'weekKey': weekKey,
          'distanceM': 5000,
          'runCount': 1,
          'updatedAt': '2026-11-24T07:00:00.000Z',
        }, fallbackUid: 'legacy_uid');
        expect(legacy.uid, 'legacy_uid');
        expect(legacy.avatarId, isNull);
        expect(legacy.avgPaceSecPerKm, isNull);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // MockGroupRepository Behavior & Validations
  // ---------------------------------------------------------------------------

  group('Phase 4 - MockGroupRepository', () {
    test(
      'creates, joins, validates errors, leaves, and deletes circles',
      () async {
        final repo = MockGroupRepository(random: math.Random(7));
        addTearDown(repo.dispose);

        // Create group
        final created = await repo.createGroup(
          ownerUid: 'u_owner',
          ownerDisplayName: 'Owner Runner',
          ownerAvatarId: 'pace_queen',
          name: 'Weekend Pacers',
          description: 'Long Sunday runs',
          weeklyGoalKm: 30,
          weekKey: weekKey,
          initialDistanceM: 10000,
          initialRunCount: 2,
          initialAvgPaceSecPerKm: 320,
          maxMembers: 2,
        );
        expect(isValidInviteCode(created.inviteCode), isTrue);
        expect(created.memberUids, ['u_owner']);

        // Invalid code format
        await expectLater(
          () => repo.joinGroupByCode(
            inviteCode: 'BAD01',
            uid: 'u_friend',
            displayName: 'Friend',
            weekKey: weekKey,
            initialDistanceM: 5000,
            initialRunCount: 1,
          ),
          throwsA(
            isA<GroupRepositoryException>().having(
              (e) => e.code,
              'code',
              GroupErrorCode.invalidCode,
            ),
          ),
        );

        // Not found
        await expectLater(
          () => repo.joinGroupByCode(
            inviteCode: 'ZZZZZZ',
            uid: 'u_friend',
            displayName: 'Friend',
            weekKey: weekKey,
            initialDistanceM: 5000,
            initialRunCount: 1,
          ),
          throwsA(
            isA<GroupRepositoryException>().having(
              (e) => e.code,
              'code',
              GroupErrorCode.notFound,
            ),
          ),
        );

        // Already a member
        await expectLater(
          () => repo.joinGroupByCode(
            inviteCode: created.inviteCode.toLowerCase(),
            uid: 'u_owner',
            displayName: 'Owner Runner',
            weekKey: weekKey,
            initialDistanceM: 10000,
            initialRunCount: 2,
          ),
          throwsA(
            isA<GroupRepositoryException>().having(
              (e) => e.code,
              'code',
              GroupErrorCode.alreadyMember,
            ),
          ),
        );

        // Join successfully with lowercase code
        final joined = await repo.joinGroupByCode(
          inviteCode: created.inviteCode.toLowerCase(),
          uid: 'u_friend',
          displayName: 'Friend Runner',
          avatarId: 'apex_wolf',
          weekKey: weekKey,
          initialDistanceM: 15000,
          initialRunCount: 3,
          initialAvgPaceSecPerKm: 305,
        );
        expect(joined.memberUids, containsAll(['u_owner', 'u_friend']));

        // Group full (maxMembers = 2)
        await expectLater(
          () => repo.joinGroupByCode(
            inviteCode: created.inviteCode,
            uid: 'u_third',
            displayName: 'Third Runner',
            weekKey: weekKey,
            initialDistanceM: 2000,
            initialRunCount: 1,
          ),
          throwsA(
            isA<GroupRepositoryException>().having(
              (e) => e.code,
              'code',
              GroupErrorCode.groupFull,
            ),
          ),
        );

        // Ranking sorted by distance descending
        final members = await repo.watchGroupMembers(created.id, weekKey).first;
        expect(members.map((m) => m.uid).toList(), ['u_friend', 'u_owner']);

        // Owner cannot leave; must delete
        await expectLater(
          () => repo.leaveGroup(groupId: created.id, uid: 'u_owner'),
          throwsA(
            isA<GroupRepositoryException>().having(
              (e) => e.code,
              'code',
              GroupErrorCode.permissionDenied,
            ),
          ),
        );

        // Non-owner cannot delete
        await expectLater(
          () => repo.deleteGroup(groupId: created.id, ownerUid: 'u_friend'),
          throwsA(
            isA<GroupRepositoryException>().having(
              (e) => e.code,
              'code',
              GroupErrorCode.permissionDenied,
            ),
          ),
        );

        // Non-owner leaves cleanly
        await repo.leaveGroup(groupId: created.id, uid: 'u_friend');
        final afterLeave = await repo
            .watchGroupMembers(created.id, weekKey)
            .first;
        expect(afterLeave.map((m) => m.uid).toList(), ['u_owner']);

        // Owner deletes cleanly
        await repo.deleteGroup(groupId: created.id, ownerUid: 'u_owner');
        final remaining = await repo.watchUserGroups('u_owner').first;
        expect(remaining, isEmpty);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // NearPaceController Auto-Sync Weekly Stats to Circles
  // ---------------------------------------------------------------------------

  group('Phase 4 - Controller Auto-Sync Weekly Circle Stats', () {
    test('auto-syncs circle weekly stats on online saveActivity and after offline SyncCoordinator flush', () async {
      final groupRepo = MockGroupRepository(random: math.Random(11));
      final actRepo = MockActivityRepository();
      final pendingStorage = InMemoryPendingSyncStorage();
      final connService = MockConnectivityService(initialOnline: true);

      final controller = NearPaceController(
        firebaseStatus: const FirebaseUnconfigured({}),
        startSignedIn: true,
        isLocalPreview: true,
        clockNow: fixedClock,
        activityRepository: actRepo,
        groupRepository: groupRepo,
        pendingSyncStorage: pendingStorage,
        connectivityService: connService,
      );
      addTearDown(() {
        controller.dispose();
        groupRepo.dispose();
        actRepo.dispose();
        connService.dispose();
      });

      final circleA = await controller.createGroup(
        name: 'Morning Crew A',
        weeklyGoalKm: 30,
      );
      final circleB = await controller.createGroup(name: 'Night Crew B');

      final initialDist = controller.weeklyDistanceMeters;
      final initialRuns = controller.weeklyActivities.length;

      // 1. Save a run online -> both circles update immediately
      final onlineRun = Activity(
        id: 'run_online_1',
        startedAt: fixedClock.subtract(const Duration(minutes: 30)),
        endedAt: fixedClock,
        distanceM: 5000,
        durationS: 1500,
        avgPaceSecPerKm: 300,
        route: const [GeoPointLite(latitude: -5.14, longitude: 119.41)],
      );
      await controller.saveActivity(onlineRun);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final membersA1 = await groupRepo
          .watchGroupMembers(circleA.id, weekKey)
          .first;
      final membersB1 = await groupRepo
          .watchGroupMembers(circleB.id, weekKey)
          .first;

      expect(membersA1.single.distanceM, closeTo(initialDist + 5000, 0.1));
      expect(membersA1.single.runCount, initialRuns + 1);
      expect(membersB1.single.distanceM, closeTo(initialDist + 5000, 0.1));

      // 2. Go offline, save run -> queued pendingSync, circle NOT yet updated
      connService.setOnline(false);
      controller.setOffline(true);

      final offlineRun = Activity(
        id: 'run_offline_2',
        startedAt: fixedClock.subtract(const Duration(minutes: 20)),
        endedAt: fixedClock,
        distanceM: 3200,
        durationS: 1024,
        avgPaceSecPerKm: 320,
        route: const [GeoPointLite(latitude: -5.14, longitude: 119.41)],
      );
      await controller.saveActivity(offlineRun);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final membersBeforeFlush = await groupRepo
          .watchGroupMembers(circleA.id, weekKey)
          .first;
      expect(
        membersBeforeFlush.single.distanceM,
        closeTo(initialDist + 5000, 0.1),
      );

      // 3. Come back online -> SyncCoordinator flushes pending run and auto-syncs all circles
      connService.setOnline(true);
      controller.setOffline(false);
      final flushed = await controller.syncPendingActivities();
      expect(flushed, 1);

      final membersA2 = await groupRepo
          .watchGroupMembers(circleA.id, weekKey)
          .first;
      final membersB2 = await groupRepo
          .watchGroupMembers(circleB.id, weekKey)
          .first;

      expect(
        membersA2.single.distanceM,
        closeTo(initialDist + 5000 + 3200, 0.1),
      );
      expect(membersA2.single.runCount, initialRuns + 2);
      expect(
        membersB2.single.distanceM,
        closeTo(initialDist + 5000 + 3200, 0.1),
      );

      // 4. Updating avatar propagates to circle members
      await controller.updateAvatar('trail_explorer');
      final membersA3 = await groupRepo
          .watchGroupMembers(circleA.id, weekKey)
          .first;
      expect(membersA3.single.avatarId, 'trail_explorer');
    });
  });

  // ---------------------------------------------------------------------------
  // Widget Tests: Kota | Circles Switch, Create, Join, Detail, Leave/Delete
  // ---------------------------------------------------------------------------

  group('Phase 4 - Circles UI Flows', () {
    testWidgets(
      'keeps 4 bottom nav tabs, switches Kota | Circles, creates & deletes circle',
      (tester) async {
        usePhoneViewport(tester);

        await tester.pumpWidget(
          NearPaceApp(startSignedIn: true, clockNow: fixedClock),
        );
        await tester.pumpAndSettle();

        // Bottom Navigation Bar stays at 4 tabs (Home, History, Ranks, Profile)
        expect(find.text('Home'), findsOneWidget);
        expect(find.text('History'), findsOneWidget);
        expect(find.text('Ranks'), findsOneWidget);
        expect(find.text('Profile'), findsOneWidget);

        // Open Ranks tab
        await tester.tap(find.text('Ranks'));
        await tester.pumpAndSettle();

        // Segmented switch Kota | Circles is visible
        expect(
          find.byKey(const ValueKey('leaderboard-tab-kota')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('leaderboard-tab-circles')),
          findsOneWidget,
        );

        // Switch to Circles -> friendly empty state with Create & Join CTAs
        await tester.tap(find.byKey(const ValueKey('leaderboard-tab-circles')));
        await tester.pumpAndSettle();

        expect(find.text('Run stronger with a Circle'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('empty-create-circle')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('empty-join-circle')), findsOneWidget);

        // Create a circle
        await tester.tap(find.byKey(const ValueKey('empty-create-circle')));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('create-circle-name')),
          'Unhas Track Club',
        );
        await tester.enterText(
          find.byKey(const ValueKey('create-circle-description')),
          'Weekly 20km pace target',
        );
        await tester.enterText(
          find.byKey(const ValueKey('create-circle-goal')),
          '20',
        );
        await tester.tap(find.byKey(const ValueKey('create-circle-submit')));
        await tester.pumpAndSettle();

        // My Circles list shows created circle with rank #1 and progress
        expect(find.text('My Circles'), findsOneWidget);
        expect(find.text('Unhas Track Club'), findsOneWidget);
        expect(find.text('#1'), findsOneWidget);

        // Tap card -> CircleDetailScreen
        await tester.tap(find.text('Unhas Track Club'));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('circle-invite-code')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('copy-invite-code')), findsOneWidget);
        expect(find.byKey(const ValueKey('share-invite-code')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('circle-weekly-goal-bar')),
          findsOneWidget,
        );
        expect(find.text('Weekly Standings'), findsOneWidget);
        expect(find.text('OWNER'), findsOneWidget);
        expect(find.byType(NearPaceAvatar), findsWidgets);

        // Owner sees Delete Circle (not Leave Circle)
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('delete-circle-button')),
          200,
          scrollable: find
              .descendant(
                of: find.byKey(const ValueKey('circle-detail-scroll')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(
          find.byKey(const ValueKey('delete-circle-button')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('leave-circle-button')), findsNothing);

        await tester.ensureVisible(
          find.byKey(const ValueKey('delete-circle-button')),
        );
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('delete-circle-button')));
        await tester.pumpAndSettle();
        expect(find.text('Delete circle?'), findsOneWidget);

        await tester.tap(find.widgetWithText(FilledButton, 'Delete Circle'));
        await tester.pumpAndSettle();

        // Back on Circles empty state
        expect(find.text('Run stronger with a Circle'), findsOneWidget);
      },
    );

    testWidgets(
      'joins seeded preview circle by lowercase code, shows Top-3 & leaves cleanly',
      (tester) async {
        usePhoneViewport(tester);

        await tester.pumpWidget(
          NearPaceApp(startSignedIn: true, clockNow: fixedClock),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Ranks'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('leaderboard-tab-circles')));
        await tester.pumpAndSettle();

        // Open Join Circle sheet
        await tester.tap(find.byKey(const ValueKey('empty-join-circle')));
        await tester.pumpAndSettle();

        // Wrong code shows clear error message
        await tester.enterText(
          find.byKey(const ValueKey('join-circle-code')),
          'zzzzzz',
        );
        await tester.tap(find.byKey(const ValueKey('join-circle-submit')));
        await tester.pumpAndSettle();
        expect(find.textContaining('Circle code not found'), findsOneWidget);

        // Valid seeded code (entered lowercase -> auto-uppercased) joins circle
        await tester.enterText(
          find.byKey(const ValueKey('join-circle-code')),
          'ndp4ce',
        );
        await tester.tap(find.byKey(const ValueKey('join-circle-submit')));
        await tester.pumpAndSettle();

        expect(find.text('Losari Sunrise Crew'), findsOneWidget);
        expect(find.textContaining('4 members'), findsOneWidget);

        // Open detail screen
        await tester.tap(find.text('Losari Sunrise Crew'));
        await tester.pumpAndSettle();

        expect(find.text('NDP4CE'), findsOneWidget);
        expect(find.text('Nadia Rahman'), findsOneWidget);
        expect(find.text('Rafli Hidayat'), findsOneWidget);
        expect(find.text('Alief Pratama'), findsOneWidget);
        expect(find.text('You'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('circle-weekly-goal-bar')),
          findsOneWidget,
        );

        // Non-owner sees Leave Circle (not Delete Circle)
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('leave-circle-button')),
          200,
          scrollable: find
              .descendant(
                of: find.byKey(const ValueKey('circle-detail-scroll')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(
          find.byKey(const ValueKey('leave-circle-button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('delete-circle-button')),
          findsNothing,
        );

        await tester.ensureVisible(
          find.byKey(const ValueKey('leave-circle-button')),
        );
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('leave-circle-button')));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Leave'));
        await tester.pumpAndSettle();

        expect(find.text('Run stronger with a Circle'), findsOneWidget);
      },
    );

    testWidgets(
      'Circles tab renders cleanly without overflow on 360px phone at 1.6x text scale',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 640),
              textScaler: TextScaler.linear(1.6),
            ),
            child: NearPaceApp(startSignedIn: true, clockNow: fixedClock),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Ranks'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.tap(find.byKey(const ValueKey('leaderboard-tab-circles')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  });
}
