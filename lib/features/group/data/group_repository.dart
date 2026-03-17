import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lunch_lucky/features/group/domain/group.dart';
import 'package:lunch_lucky/features/group/domain/group_member.dart';

class GroupRepository {
  final FirebaseFirestore _firestore;

  GroupRepository({required FirebaseFirestore firestore})
    : _firestore = firestore;

  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(
        6,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }

  Future<Group> createGroup(
    String name,
    String userId,
    String userName, {
    double? centerLat,
    double? centerLng,
    double maxRadiusM = 500,
    String? areaName,
  }) async {
    final groupDoc = _firestore.collection('groups').doc();
    final inviteCode = _generateInviteCode();

    final group = Group(
      id: groupDoc.id,
      name: name,
      inviteCode: inviteCode,
      createdBy: userId,
      createdAt: DateTime.now(),
      centerLat: centerLat,
      centerLng: centerLng,
      maxRadiusM: maxRadiusM,
      areaName: areaName,
    );

    // Create group
    await groupDoc.set(group.toMap());

    // Add creator as a member
    final memberDoc = groupDoc.collection('members').doc(userId);
    final member = GroupMember(
      userId: userId,
      displayName: userName,
      joinedAt: DateTime.now(),
    );
    await memberDoc.set(member.toMap());

    // Add group reference to user document
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('userGroups')
        .doc(groupDoc.id)
        .set({
          'groupId': groupDoc.id,
          'joinedAt': DateTime.now().toIso8601String(),
        });

    return group;
  }

  Future<Group?> joinGroupByCode(
    String inviteCode,
    String userId,
    String userName,
  ) async {
    final querySnapshot = await _firestore
        .collection('groups')
        .where('inviteCode', isEqualTo: inviteCode)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) return null;

    final groupDoc = querySnapshot.docs.first;
    final group = Group.fromMap(groupDoc.data(), groupDoc.id);

    // Check if user is already a member
    final memberDoc = groupDoc.reference.collection('members').doc(userId);
    final memberSnapshot = await memberDoc.get();

    if (!memberSnapshot.exists) {
      final member = GroupMember(
        userId: userId,
        displayName: userName,
        joinedAt: DateTime.now(),
      );
      await memberDoc.set(member.toMap());

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('userGroups')
          .doc(group.id)
          .set({
            'groupId': group.id,
            'joinedAt': DateTime.now().toIso8601String(),
          });
    }

    return group;
  }

  Stream<List<Group>> watchUserGroups(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('userGroups')
        .snapshots()
        .asyncMap((snapshot) async {
          final futures = snapshot.docs.map((doc) async {
            final groupId = doc.data()['groupId'] as String;
            final groupDocSnapshot = await _firestore
                .collection('groups')
                .doc(groupId)
                .get();
            if (groupDocSnapshot.exists) {
              return Group.fromMap(
                groupDocSnapshot.data()!,
                groupDocSnapshot.id,
              );
            }
            return null; // Group might have been deleted but userGroup wasn't cleaned up
          });

          final groupsWithNulls = await Future.wait(futures);
          return groupsWithNulls.whereType<Group>().toList();
        });
  }

  Stream<List<GroupMember>> watchGroupMembers(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('members')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => GroupMember.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<void> toggleAttendance(
    String groupId,
    String userId,
    bool isAttending, {
    String? mustEatRestaurantId,
    String? mustEatRestaurantName,
  }) async {
    final updateData = <String, dynamic>{
      'isAttendingToday': isAttending,
    };
    if (isAttending) {
      updateData['mustEatRestaurantId'] = mustEatRestaurantId;
      updateData['mustEatRestaurantName'] = mustEatRestaurantName;
    } else {
      updateData['mustEatRestaurantId'] = null;
      updateData['mustEatRestaurantName'] = null;
    }

    await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('members')
        .doc(userId)
        .update(updateData);
  }

  Future<void> updateGroupLocation(
    String groupId, {
    required double centerLat,
    required double centerLng,
    required double maxRadiusM,
    required String areaName,
  }) async {
    await _firestore.collection('groups').doc(groupId).update({
      'centerLat': centerLat,
      'centerLng': centerLng,
      'maxRadiusM': maxRadiusM,
      'areaName': areaName,
    });
  }

  Future<void> updateGroupName(String groupId, String newName) async {
    await _firestore.collection('groups').doc(groupId).update({
      'name': newName,
    });
  }

  Future<void> updateGroupSettings(
    String groupId,
    double vetoWeightMultiplier,
  ) async {
    await _firestore.collection('groups').doc(groupId).update({
      'vetoWeightMultiplier': vetoWeightMultiplier,
    });
  }

  Future<void> updateGroupDrawMode(String groupId, String drawMode) async {
    await _firestore.collection('groups').doc(groupId).update({
      'drawMode': drawMode,
    });
  }

  Future<void> updateMemberWeight(
    String groupId,
    String userId,
    double baseWeight,
  ) async {
    await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('members')
        .doc(userId)
        .update({'baseWeight': baseWeight});
  }

  Future<void> incrementDessertWins(String groupId, String userId) async {
    await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('members')
        .doc(userId)
        .update({'dessertWins': FieldValue.increment(1)});
  }

  Future<void> deleteGroup(String groupId, String userId) async {
    // 1. Remove the group reference from the current user's document
    // This ensures it disappears from the My Groups list immediately
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('userGroups')
        .doc(groupId)
        .delete();

    // 2. Check if this user is the owner (creator)
    final groupDoc = await _firestore.collection('groups').doc(groupId).get();
    if (groupDoc.exists) {
      final ownerId = groupDoc.data()?['createdBy'] as String?;

      if (ownerId == userId) {
        // If owner deletes it, we delete the entire group doc
        await _firestore.collection('groups').doc(groupId).delete();
      }
    }
  }

  Future<void> updateUseSchedule(
    String groupId,
    String userId,
    bool useSchedule,
  ) async {
    await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('members')
        .doc(userId)
        .update({'useSchedule': useSchedule});
  }

  Future<void> updateAttendanceSchedule(
    String groupId,
    String userId,
    List<int> schedule,
  ) async {
    await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('members')
        .doc(userId)
        .update({'attendanceSchedule': schedule});
  }

  /// 날짜가 바뀌었으면 스케줄 기반으로 isAttendingToday를 설정
  Future<void> resetDailyAttendanceIfNeeded(String groupId) async {
    final groupDoc = await _firestore.collection('groups').doc(groupId).get();
    if (!groupDoc.exists) return;

    final data = groupDoc.data()!;
    final lastReset = data['lastAttendanceResetDate'] as String?;
    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    if (lastReset == todayStr) return;

    final todayWeekday = today.weekday; // 1=월 ~ 7=일

    final membersSnap = await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('members')
        .get();

    final batch = _firestore.batch();
    for (final memberDoc in membersSnap.docs) {
      final data = memberDoc.data();
      final useSchedule = data['useSchedule'] ?? false;
      if (useSchedule) {
        final schedule = List<int>.from(data['attendanceSchedule'] ?? []);
        final shouldAttend = schedule.contains(todayWeekday);
        batch.update(memberDoc.reference, {
          'isAttendingToday': shouldAttend,
          'mustEatRestaurantId': null,
          'mustEatRestaurantName': null,
        });
      } else {
        batch.update(memberDoc.reference, {
          'isAttendingToday': false,
          'mustEatRestaurantId': null,
          'mustEatRestaurantName': null,
        });
      }
    }
    batch.update(
      _firestore.collection('groups').doc(groupId),
      {'lastAttendanceResetDate': todayStr},
    );
    await batch.commit();
  }

  Future<void> leaveGroup(String groupId, String userId) async {
    // 멤버 문서 삭제
    await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('members')
        .doc(userId)
        .delete();

    // 유저의 그룹 참조 삭제
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('userGroups')
        .doc(groupId)
        .delete();
  }

  /// 그룹 전체 멤버의 vetoCount를 0으로 초기화 (매 세션 시작/취소 시 호출)
  Future<void> resetGroupVetoCounts(String groupId) async {
    final membersSnap = await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('members')
        .get();

    final batch = _firestore.batch();
    for (final memberDoc in membersSnap.docs) {
      final userId = memberDoc.id;
      final userRef = _firestore.collection('users').doc(userId);
      batch.update(userRef, {'vetoCount': 0});
    }
    await batch.commit();
  }

  /// 룰렛 완료 후 모든 멤버의 당일 참여 상태를 초기화
  Future<void> clearAllAttendance(String groupId) async {
    final membersSnap = await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('members')
        .get();

    final batch = _firestore.batch();
    for (final memberDoc in membersSnap.docs) {
      batch.update(memberDoc.reference, {
        'isAttendingToday': false,
        'mustEatRestaurantId': null,
        'mustEatRestaurantName': null,
      });
    }
    await batch.commit();
  }
}
