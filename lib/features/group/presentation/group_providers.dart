import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lunch_lucky/features/auth/data/auth_repository.dart';
import 'package:lunch_lucky/features/group/data/group_repository.dart';
import 'package:lunch_lucky/features/group/data/restaurant_repository.dart';
import 'package:lunch_lucky/features/group/domain/group.dart';
import 'package:lunch_lucky/features/group/domain/group_member.dart';
import 'package:lunch_lucky/features/group/domain/restaurant.dart';

final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  return GroupRepository(firestore: FirebaseFirestore.instance);
});

final restaurantRepositoryProvider = Provider<RestaurantRepository>((ref) {
  return RestaurantRepository(firestore: FirebaseFirestore.instance);
});

class CurrentGroupIdNotifier extends Notifier<String?> {
  @override
  String? build() {
    // 그룹 목록이 로드되면 자동으로 첫 번째 그룹 선택
    ref.listen<AsyncValue<List<Group>>>(userGroupsProvider, (prev, next) {
      final groups = next.value;
      if (groups == null || groups.isEmpty) return;
      // 현재 선택된 그룹이 없거나, 선택된 그룹이 목록에 없으면 첫 번째 그룹 선택
      if (state == null || !groups.any((g) => g.id == state)) {
        state = groups.first.id;
      }
    });
    return null;
  }

  void setGroupId(String? id) => state = id;
}

final currentGroupIdProvider =
    NotifierProvider<CurrentGroupIdNotifier, String?>(
      () => CurrentGroupIdNotifier(),
    );

final currentGroupProvider = Provider<Group?>((ref) {
  final groupId = ref.watch(currentGroupIdProvider);
  if (groupId == null) return null;
  final groups = ref.watch(userGroupsProvider).value;
  if (groups == null) return null;

  try {
    return groups.firstWhere((g) => g.id == groupId);
  } catch (_) {
    return null;
  }
});

final userGroupsProvider = StreamProvider<List<Group>>((ref) {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) return const Stream.empty();

  return ref.watch(groupRepositoryProvider).watchUserGroups(user.uid);
});

/// 날짜가 바뀌었으면 출석을 자동 리셋하는 provider
final _dailyAttendanceResetProvider = FutureProvider.autoDispose<void>((ref) async {
  final groupId = ref.watch(currentGroupIdProvider);
  if (groupId == null) return;
  await ref.read(groupRepositoryProvider).resetDailyAttendanceIfNeeded(groupId);
});

final currentGroupMembersProvider = StreamProvider<List<GroupMember>>((ref) {
  final groupId = ref.watch(currentGroupIdProvider);
  if (groupId == null) return const Stream.empty();

  // 멤버 목록을 가져오기 전에 일일 출석 리셋 트리거
  ref.watch(_dailyAttendanceResetProvider);

  return ref.watch(groupRepositoryProvider).watchGroupMembers(groupId);
});

final currentGroupRestaurantsProvider = StreamProvider<List<Restaurant>>((ref) {
  final groupId = ref.watch(currentGroupIdProvider);
  if (groupId == null) return const Stream.empty();

  return ref.watch(restaurantRepositoryProvider).watchRestaurants(groupId);
});

// Providers for actions
final createGroupProvider = FutureProvider.autoDispose.family<Group, String>((
  ref,
  name,
) async {
  final user = ref.read(authStateChangesProvider).value!;
  return ref
      .read(groupRepositoryProvider)
      .createGroup(name, user.uid, user.displayName ?? '이름 없음');
});

final joinGroupProvider = FutureProvider.autoDispose.family<Group?, String>((
  ref,
  code,
) async {
  final user = ref.read(authStateChangesProvider).value!;
  return ref
      .read(groupRepositoryProvider)
      .joinGroupByCode(code, user.uid, user.displayName ?? '이름 없음');
});
