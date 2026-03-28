import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lunch_lucky/features/auth/data/auth_repository.dart';
import 'package:lunch_lucky/features/group/domain/restaurant.dart';
import 'package:lunch_lucky/features/group/data/geocoding_service.dart';
import 'package:lunch_lucky/features/group/presentation/restaurant_detail_sheet.dart';
import 'package:lunch_lucky/features/group/presentation/group_providers.dart';
import 'package:lunch_lucky/features/session/presentation/session_providers.dart';
import 'package:lunch_lucky/features/session/domain/session.dart';
import 'package:lunch_lucky/features/roulette/presentation/roulette_providers.dart';
import 'package:lunch_lucky/features/roulette/domain/roulette_state.dart';
import 'package:lunch_lucky/features/roulette/presentation/coffee_game_launcher.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

class GroupHomeScreen extends ConsumerStatefulWidget {
  const GroupHomeScreen({super.key});

  @override
  ConsumerState<GroupHomeScreen> createState() => _GroupHomeScreenState();
}

class _GroupHomeScreenState extends ConsumerState<GroupHomeScreen> {
  int _currentIndex = 1;

  @override
  Widget build(BuildContext context) {
    final currentGroupId = ref.watch(currentGroupIdProvider);

    ref.listen(currentGroupIdProvider, (prev, next) {
      if (next != null && _currentIndex == 0) {
        setState(() => _currentIndex = 1);
      }
      if (next == null && (_currentIndex == 1 || _currentIndex == 2)) {
        setState(() => _currentIndex = 0);
      }
    });

    return Scaffold(
      appBar: _buildAppBar(currentGroupId),
      body: _buildBody(currentGroupId),
      floatingActionButton: _buildFab(currentGroupId),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          if (currentGroupId == null && (index == 1 || index == 2)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('먼저 그룹을 선택해주세요.')),
            );
            return;
          }
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.group), label: '그룹'),
          NavigationDestination(icon: Icon(Icons.home), label: '홈'),
          NavigationDestination(
              icon: Icon(Icons.restaurant_menu), label: '식당'),
          NavigationDestination(icon: Icon(Icons.person), label: 'MY'),
        ],
      ),
    );
  }

  Widget _buildGroupSwitcher() {
    final groups = ref.watch(userGroupsProvider).value ?? [];
    final currentGroup = ref.watch(currentGroupProvider);

    if (groups.isEmpty || currentGroup == null) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return PopupMenuButton<String>(
      onSelected: (id) {
        ref.read(currentGroupIdProvider.notifier).setGroupId(id);
      },
      itemBuilder: (context) => groups.map((g) {
        final isSelected = g.id == currentGroup.id;
        return PopupMenuItem<String>(
          value: g.id,
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.check_circle : Icons.circle_outlined,
                size: 18,
                color: isSelected ? Colors.orange : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(
                g.name,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        );
      }).toList(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            currentGroup.name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_drop_down, size: 20),
        ],
      ),
    );
  }

  Widget _buildAttendanceFab(String groupId) {
    final members = ref.watch(currentGroupMembersProvider).value ?? [];
    final user = ref.watch(authStateChangesProvider).value;
    final me = members.where((m) => m.userId == user?.uid).toList();
    if (me.isEmpty) return const SizedBox.shrink();

    final isAttending = me.first.isAttendingToday;
    final hasMustEat = me.first.mustEatRestaurantId != null;
    final attendingCount = members.where((m) => m.isAttendingToday).length;

    final activeSession = ref.watch(activeSessionProvider).value;
    final hasSelectedMenu = activeSession?.menuSelections.containsKey(user?.uid) ?? false;

    return FloatingActionButton.extended(
      heroTag: 'attendance',
      onPressed: () {
        if (isAttending) {
          if (hasSelectedMenu) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('메뉴를 이미 선택하여 참여를 취소할 수 없습니다.'),
                backgroundColor: Colors.redAccent,
              ),
            );
            return;
          }
          ref.read(groupRepositoryProvider).toggleAttendance(
                groupId,
                user!.uid,
                false,
              );
        } else {
          _showAttendanceOptionsDialog(context, ref, groupId, user!.uid);
        }
      },
      backgroundColor: hasMustEat ? Colors.deepOrange : Colors.orange,
      foregroundColor: Colors.white,
      icon: Icon(
        isAttending
            ? (hasMustEat ? Icons.local_fire_department : Icons.lunch_dining)
            : Icons.add,
      ),
      label: Text(
        isAttending
            ? (hasMustEat
                ? '🔥 $attendingCount명 참여 중'
                : '$attendingCount명 참여 중')
            : '점심 참여',
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(String? groupId) {
    switch (_currentIndex) {
      case 0:
        return AppBar(title: const Text('그룹 관리'));
      case 1:
        return AppBar(
          title: _buildGroupSwitcher(),
          actions: [
            if (groupId != null)
              IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () =>
                    _showGroupDetailSheet(context, ref, groupId),
              ),
          ],
        );
      case 2:
        return AppBar(
          title: _buildGroupSwitcher(),
          actions: [
            if (groupId != null)
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: Colors.grey),
                onPressed: () =>
                    _showManageRestaurantsBottomSheet(context, ref, groupId),
                tooltip: '식당 관리',
              ),
          ],
        );
      case 3:
        return AppBar(title: const Text('MY'));
      default:
        return AppBar();
    }
  }

  Widget _buildBody(String? groupId) {
    final isLoading = ref.watch(userGroupsProvider).isLoading;
    const loadingWidget = Center(child: CircularProgressIndicator());

    switch (_currentIndex) {
      case 0:
        return const _GroupListBody();
      case 1:
        if (groupId != null) return _HomeTabBody(groupId: groupId);
        return isLoading ? loadingWidget : const _NeedGroupPlaceholder();
      case 2:
        if (groupId != null) return _RestaurantListBody(groupId: groupId);
        return isLoading ? loadingWidget : const _NeedGroupPlaceholder();
      case 3:
        return const _MyTabBody();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget? _buildFab(String? groupId) {
    Widget? actionFab;
    switch (_currentIndex) {
      case 0:
        actionFab = FloatingActionButton.extended(
          heroTag: 'action',
          onPressed: () => _showJoinOrCreateDialog(context, ref),
          icon: const Icon(Icons.group_add),
          label: const Text('그룹 추가'),
        );
        break;
      case 2:
        if (groupId != null) {
          actionFab = FloatingActionButton.extended(
            heroTag: 'action',
            onPressed: () =>
                _showAddRestaurantDialog(context, ref, groupId),
            icon: const Icon(Icons.add),
            label: const Text('식당 추가'),
          );
        }
        break;
    }

    final attendanceFab =
        groupId != null ? _buildAttendanceFab(groupId) : null;

    if (actionFab == null && attendanceFab == null) return null;
    if (actionFab == null) return attendanceFab;
    if (attendanceFab == null) return actionFab;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        attendanceFab,
        const SizedBox(height: 12),
        actionFab,
      ],
    );
  }
}

class _GroupListBody extends ConsumerWidget {
  const _GroupListBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(userGroupsProvider);

    return groupsAsync.when(
        data: (groups) {
          if (groups.isEmpty) {
            return const Center(
              child: Text('참여 중인 그룹이 없습니다.\n새 그룹을 만들거나 초대 코드로 참여하세요.'),
            );
          }
          return AnimationLimiter(
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final group = groups[index];
                final user = ref.read(authStateChangesProvider).value;

                return AnimationConfiguration.staggeredList(
                  position: index,
                  duration: const Duration(milliseconds: 375),
                  child: SlideAnimation(
                    verticalOffset: 50.0,
                    child: FadeInAnimation(
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () {
                            ref
                                .read(currentGroupIdProvider.notifier)
                                .setGroupId(group.id);
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Colors.orange.shade100,
                                  child: const Icon(
                                    Icons.group,
                                    color: Colors.orange,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        group.name,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '초대 코드: ${group.inviteCode}',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    color: Colors.blueAccent,
                                  ),
                                  onPressed: () => _showEditGroupNameDialog(
                                    context,
                                    ref,
                                    group.id,
                                    group.name,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: () => _showDeleteGroupDialog(
                                    context,
                                    ref,
                                    group.id,
                                    group.name,
                                    user?.uid ?? '',
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.chevron_right,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () {
                                    ref
                                        .read(currentGroupIdProvider.notifier)
                                        .setGroupId(group.id);
                                    _showGroupDetailSheet(
                                        context, ref, group.id);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('오류 발생: $e')),
    );
  }
}

void _showAttendanceOptionsDialog(
  BuildContext context,
  WidgetRef ref,
  String groupId,
  String userId,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return _buildGlassBottomModal(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '점심 참여',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.blue,
                child: Icon(Icons.check, color: Colors.white),
              ),
              title: const Text('그냥 참여하기', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('오늘 점심에 일반 멤버로 참여합니다.'),
              onTap: () {
                Navigator.of(context).pop();
                ref.read(groupRepositoryProvider).toggleAttendance(
                      groupId,
                      userId,
                      true,
                    );
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.orange.shade100,
                child: const Icon(Icons.restaurant, color: Colors.orange),
              ),
              title: const Text('꼭 가고 싶은 식당 선택하기', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('선택한 식당이 무조건 추천 후보에 들어갑니다.\n(결제 룰렛 확률 2배 패널티 위험)'),
              onTap: () {
                Navigator.of(context).pop();
                _showMustEatSelectionDialog(context, ref, groupId, userId);
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      );
    },
  );
}

void _showMustEatSelectionDialog(
  BuildContext context,
  WidgetRef ref,
  String groupId,
  String userId,
) {
  showDialog(
    context: context,
    builder: (context) {
      return Consumer(
        builder: (context, ref, _) {
          final restaurantsAsync = ref.watch(currentGroupRestaurantsProvider);

          return restaurantsAsync.when(
            data: (restaurants) {
              if (restaurants.isEmpty) {
                return AlertDialog(
                  title: const Text('식당 없음'),
                  content: const Text('등록된 식당이 없습니다. 식당을 먼저 추가해주세요.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('확인'),
                    ),
                  ],
                );
              }

              return AlertDialog(
                title: const Text('가고 싶은 식당 선택',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                content: SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: restaurants.length,
                    itemBuilder: (context, index) {
                      final r = restaurants[index];
                      final isDisabled = r.isDisabled;
                      return ListTile(
                        title: Text(
                          r.name,
                          style: TextStyle(
                            decoration:
                                isDisabled ? TextDecoration.lineThrough : null,
                            color: isDisabled ? Colors.grey : null,
                          ),
                        ),
                        subtitle: Text(r.category ?? '카테고리 없음'),
                        leading:
                            const CircleAvatar(child: Icon(Icons.restaurant)),
                        onTap: isDisabled
                            ? null
                            : () {
                                Navigator.of(context).pop();
                                ref
                                    .read(groupRepositoryProvider)
                                    .toggleAttendance(
                                      groupId,
                                      userId,
                                      true,
                                      mustEatRestaurantId: r.id,
                                      mustEatRestaurantName: r.name,
                                    );
                              },
                      );
                    },
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('취소'),
                  ),
                ],
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(40.0),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => AlertDialog(
              title: const Text('오류'),
              content: Text('식당 목록을 불러오지 못했습니다: $e'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('확인'),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

void _showJoinOrCreateDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return _buildGlassBottomModal(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '그룹 추가',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.black,
                  child: Icon(Icons.add, color: Colors.white),
                ),
                title: const Text(
                  '새 그룹 만들기',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('팀원들을 초대할 새로운 구역을 생성합니다.'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showCreateGroupDialog(context, ref);
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.orange.shade100,
                  child: const Icon(Icons.link, color: Colors.orange),
                ),
                title: const Text(
                  '초대 코드로 참여하기',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('기존 그룹의 초대 코드를 입력해 입장합니다.'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showJoinGroupDialog(context, ref);
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGlassBottomModal({required Widget child}) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white, // Opaque white base from bottomSheetTheme
        ),
        padding: const EdgeInsets.only(
          top: 24,
          left: 24,
          right: 24,
          bottom: 24,
        ),
        child: SafeArea(child: child),
      ),
    );
  }

  void _showCreateGroupDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final areaNameController = TextEditingController();
    double radiusM = 500;
    double? resolvedLat;
    double? resolvedLng;
    String? locationStatus;
    bool isSearching = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: _buildGlassBottomModal(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '새 그룹 만들기',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: '그룹 이름',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      autofocus: true,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '지역 설정 (선택)',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: areaNameController,
                            decoration: InputDecoration(
                              labelText: '지역명 (예: 신논현역, 판교역)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade800,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: isSearching
                                ? null
                                : () async {
                                    final query =
                                        areaNameController.text.trim();
                                    if (query.isEmpty) return;
                                    setState(() {
                                      isSearching = true;
                                      locationStatus = '검색 중...';
                                    });
                                    final results =
                                        await GeocodingService.searchLocations(
                                            query);
                                    setState(() => isSearching = false);
                                    if (results.isEmpty) {
                                      setState(() {
                                        resolvedLat = null;
                                        resolvedLng = null;
                                        locationStatus = '위치를 찾을 수 없습니다';
                                      });
                                      return;
                                    }
                                    if (results.length == 1) {
                                      setState(() {
                                        resolvedLat = results[0].lat;
                                        resolvedLng = results[0].lng;
                                        locationStatus =
                                            results[0].displayName.split(',').take(3).join(',');
                                      });
                                      return;
                                    }
                                    if (!context.mounted) return;
                                    final selected =
                                        await _showLocationPicker(
                                            context, results);
                                    if (selected != null) {
                                      setState(() {
                                        resolvedLat = selected.lat;
                                        resolvedLng = selected.lng;
                                        locationStatus =
                                            selected.displayName.split(',').take(3).join(',');
                                      });
                                    }
                                  },
                            child: isSearching
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('검색'),
                          ),
                        ),
                      ],
                    ),
                    if (locationStatus != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        locationStatus!,
                        style: TextStyle(
                          fontSize: 13,
                          color: resolvedLat != null
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      '검색 반경: ${radiusM.toInt()}m',
                      style: const TextStyle(fontSize: 13),
                    ),
                    Slider(
                      value: radiusM,
                      min: 300,
                      max: 1000,
                      divisions: 14,
                      label: '${radiusM.toInt()}m',
                      onChanged: (v) => setState(() => radiusM = v),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () async {
                        final name = nameController.text.trim();
                        if (name.isEmpty) return;

                        final user =
                            ref.read(authStateChangesProvider).value!;
                        final area = areaNameController.text.trim();

                        await ref.read(groupRepositoryProvider).createGroup(
                              name,
                              user.uid,
                              user.displayName ?? '이름 없음',
                              centerLat: resolvedLat,
                              centerLng: resolvedLng,
                              maxRadiusM: radiusM,
                              areaName: area.isNotEmpty ? area : null,
                            );
                        ref.invalidate(userGroupsProvider);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                      child:
                          const Text('만들기', style: TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showJoinGroupDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: _buildGlassBottomModal(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '초대 코드로 참여하기',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: '초대 코드 (6자리)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () async {
                    final code = controller.text.trim();
                    if (code.isNotEmpty) {
                      final group = await ref.read(
                        joinGroupProvider(code).future,
                      );
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        if (group == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('유효하지 않은 초대 코드입니다.')),
                          );
                        }
                      }
                    }
                  },
                  child: const Text('참여', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDeleteGroupDialog(
    BuildContext context,
    WidgetRef ref,
    String groupId,
    String groupName,
    String userId,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('그룹 나가기/삭제'),
        content: Text(
          '"$groupName" 그룹을 나가시겠습니까?\n(본인이 생성한 그룹인 경우 그룹 자체가 삭제됩니다.)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              await ref
                  .read(groupRepositoryProvider)
                  .deleteGroup(groupId, userId);
              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('그룹 처리가 완료되었습니다.')),
                );
              }
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _showEditGroupNameDialog(
    BuildContext context,
    WidgetRef ref,
    String groupId,
    String currentName,
  ) {
    final controller = TextEditingController(text: currentName);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: const BoxDecoration(color: Colors.white),
              padding: const EdgeInsets.all(24),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '그룹 이름 수정',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        labelText: '새 그룹 이름',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      autofocus: true,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('취소'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final name = controller.text.trim();
                            if (name.isNotEmpty && name != currentName) {
                              await ref
                                  .read(groupRepositoryProvider)
                                  .updateGroupName(groupId, name);
                              ref.invalidate(userGroupsProvider);
                              if (context.mounted) {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('그룹 이름이 수정되었습니다.'),
                                  ),
                                );
                              }
                            } else {
                              Navigator.of(context).pop();
                            }
                          },
                          child: const Text('수정'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

class _HomeTabBody extends ConsumerWidget {
  final String groupId;

  const _HomeTabBody({required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Auto-navigate to session screen if a session is active
    ref.listen<AsyncValue<Session?>>(activeSessionProvider, (previous, next) {
      final prevSession = previous?.value;
      final nextSession = next.value;

      if (nextSession != null &&
          (nextSession.status == 'vetoing' ||
              nextSession.status == 'menu_selecting')) {
        // Only auto-navigate for truly NEW sessions (not when user manually joins)
        final isNewSession = prevSession == null || prevSession.id != nextSession.id;
        final isStatusChange = prevSession != null &&
            prevSession.id == nextSession.id &&
            prevSession.status != nextSession.status &&
            (prevSession.status != 'vetoing' && prevSession.status != 'menu_selecting');
        if (isNewSession || isStatusChange) {
          final router = GoRouter.of(context);
          final currentTopRoute = router.routerDelegate.currentConfiguration.uri
              .toString();
          if (!currentTopRoute.contains('session') &&
              !currentTopRoute.contains('roulette')) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                context.push('/session');
              }
            });
          }
        }
      }
    });

    // Auto-navigate to roulette screen if someone starts spinning or enters it
    ref.listen<AsyncValue<RouletteState>>(rouletteStateProvider, (
      previous,
      next,
    ) {
      final prevStatus = previous?.value?.status;
      final nextStatus = next.value?.status;
      // 상태 변화가 없으면 무시 (최초 로드 시 오래된 Firestore 상태로 인한 이동 방지)
      if (prevStatus == nextStatus) return;

      if (next.hasValue &&
          (nextStatus == 'spinning' || nextStatus == 'ready')) {
        // spinning 상태는 최근 10초 이내에 시작된 것만 처리
        if (nextStatus == 'spinning') {
          final spinStartedAt = next.value?.spinStartedAt;
          if (spinStartedAt == null) return;
          final elapsed = DateTime.now().difference(spinStartedAt);
          if (elapsed.inSeconds > 10) return;
        }

        // GoRouter의 실제 현재 최상위 라우트를 확인
        final router = GoRouter.of(context);
        final currentTopRoute = router.routerDelegate.currentConfiguration.uri
            .toString();
        if (!currentTopRoute.contains('roulette')) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              context.push('/roulette');
            }
          });
        }
      }
    });

    // Auto-navigate to Lucky Latte when gameUrl is set by another member
    ref.listen<AsyncValue<RouletteState>>(rouletteStateProvider, (
      previous,
      next,
    ) {
      final prevGameUrl = previous?.value?.gameUrl;
      final nextGameUrl = next.value?.gameUrl;
      // Only react to NEW gameUrl (not already set)
      if (nextGameUrl != null &&
          nextGameUrl.isNotEmpty &&
          prevGameUrl != nextGameUrl) {
        // Skip if this user is the one who set the URL
        final currentUser = ref.read(authStateChangesProvider).value;
        final setBy = next.value?.gameUrlSetBy;
        if (currentUser != null && setBy == currentUser.uid) {
          return;
        }

        // Check staleness: only navigate if set within last 60 seconds
        final setAt = next.value?.gameUrlSetAt;
        if (setAt != null) {
          final elapsed = DateTime.now().difference(setAt);
          if (elapsed.inSeconds > 60) return;
        }

        // Build personal URL with current user's nickname
        final user = ref.read(authStateChangesProvider).value;
        final myNickname = user?.displayName ?? '게스트';
        final myUrl = buildPersonalGameUrl(nextGameUrl, myNickname);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            launchUrl(myUrl, mode: LaunchMode.externalApplication);
          }
        });
      }
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Consumer(
            builder: (context, ref, child) {
              final activeSessionAsync = ref.watch(activeSessionProvider);
              final isSessionActiveOrLoading =
                  activeSessionAsync.isLoading ||
                  (activeSessionAsync.value != null &&
                      (activeSessionAsync.value!.status == 'vetoing' ||
                          activeSessionAsync.value!.status == 'menu_selecting'));

              final recentSessionsAsync = ref.watch(recentSessionsProvider);
              bool hasCompletedSessionToday = false;
              if (recentSessionsAsync.value != null &&
                  recentSessionsAsync.value!.isNotEmpty) {
                final lastSession = recentSessionsAsync.value!.first;
                final now = DateTime.now();
                // 오늘 '완료(completed)'된 세션만 카운트 (취소/실패 제외)
                if (lastSession.status == 'completed' &&
                    lastSession.createdAt.year == now.year &&
                    lastSession.createdAt.month == now.month &&
                    lastSession.createdAt.day == now.day) {
                  hasCompletedSessionToday = true;
                }
              }

              final rouletteStateAsync = ref.watch(rouletteStateProvider);
              // 룰렛 상태가 'completed'이면 오늘 이미 후식을 뽑은 것으로 간주
              // (새 점심 세션 시작 시 resetRoulette()으로 idle로 초기화됨)
              final hasCompletedRouletteToday =
                  rouletteStateAsync.value?.status == 'completed';

              final shouldShowDessertDraw =
                  hasCompletedSessionToday && !hasCompletedRouletteToday;

              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    if (!isSessionActiveOrLoading)
                      BoxShadow(
                        color: Colors.orange.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                  ],
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor:
                        shouldShowDessertDraw && !isSessionActiveOrLoading
                        ? Colors.blue.shade500
                        : Colors.orange.shade500,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    disabledForegroundColor: Colors.grey.shade600,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  onPressed: activeSessionAsync.isLoading
                      ? null
                      : () async {
                          if (isSessionActiveOrLoading) {
                            // If a session is already active, just join it
                            context.push('/session');
                            return;
                          }

                          if (shouldShowDessertDraw) {
                            // Sync all users to roulette screen
                            await ref
                                .read(rouletteRepositoryProvider)
                                .readyRoulette(groupId);

                            if (context.mounted) {
                              _showGameChoiceDialog(context, ref);
                            }
                            return;
                          }

                          final members =
                              ref.read(currentGroupMembersProvider).value ?? [];
                          final restaurants =
                              ref.read(currentGroupRestaurantsProvider).value ??
                              [];

                          final attendingMembers =
                              members.where((m) => m.isAttendingToday).toList();
                          final attendingUserIds =
                              attendingMembers.map((m) => m.userId).toList();
                          final mustEatRestaurantIds = attendingMembers
                              .map((m) => m.mustEatRestaurantId)
                              .where((id) => id != null)
                              .cast<String>()
                              .toList();

                          if (attendingUserIds.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('참여 중인 멤버가 없습니다. 하단에서 참여를 눌러주세요.')),
                            );
                            return;
                          }

                          if (restaurants.where((r) => !r.isDisabled).isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('활성화된 리뷰/식당이 없습니다.'),
                              ),
                            );
                            return;
                          }

                          try {
                            await ref
                                .read(sessionRepositoryProvider)
                                .startSession(
                                  groupId,
                                  attendingUserIds,
                                  restaurants,
                                  mustEatRestaurantIds: mustEatRestaurantIds,
                                );
                            try {
                              await ref
                                  .read(rouletteRepositoryProvider)
                                  .resetRoulette(groupId);
                              await ref
                                  .read(groupRepositoryProvider)
                                  .resetGroupVetoCounts(groupId);
                            } catch (_) {}
                            if (context.mounted) {
                              context.push('/session');
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('세션 시작 실패: $e')),
                              );
                            }
                          }
                        },
                  child: activeSessionAsync.isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          isSessionActiveOrLoading
                              ? '진행 중인 세션 참여하기'
                              : shouldShowDessertDraw
                              ? '☕ 오늘의 후식 룰렛 돌리기'
                              : '🚀 점심 세션 시작',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          _RecentHistoryWidget(groupId: groupId),
          const SizedBox(height: 24),
          _DessertHallOfFameWidget(),
          const SizedBox(height: 32),
          _TodayMenuSelectionsWidget(groupId: groupId),
        ],
      ),
    );
  }
}

void _showAddRestaurantDialog(
  BuildContext context,
  WidgetRef ref,
  String groupId,
) {
  final nameController = TextEditingController();
  final categoryController = TextEditingController();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: const BoxDecoration(color: Colors.white),
            padding: const EdgeInsets.all(24),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '식당 추가',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: '식당 이름',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: categoryController,
                    decoration: InputDecoration(
                      labelText: '카테고리 (예: 한식, 중식)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('취소'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          final name = nameController.text.trim();
                          final category = categoryController.text.trim();
                          if (name.isNotEmpty) {
                            final user = ref
                                .read(authStateChangesProvider)
                                .value;
                            final restaurant = Restaurant(
                              id: '',
                              name: name,
                              category: category.isNotEmpty ? category : null,
                              createdAt: DateTime.now(),
                              addedBy: user?.uid,
                            );
                            await ref
                                .read(restaurantRepositoryProvider)
                                .addRestaurant(groupId, restaurant);
                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          }
                        },
                        child: const Text('추가'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

void _showEditRestaurantDialog(
  BuildContext context,
  WidgetRef ref,
  String groupId,
  Restaurant restaurant,
) {
  final nameController = TextEditingController(text: restaurant.name);
  final categoryController = TextEditingController(
    text: restaurant.category ?? '',
  );

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: const BoxDecoration(color: Colors.white),
            padding: const EdgeInsets.all(24),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '식당 정보 수정',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: () {
                          Navigator.of(context).pop(); // Close edit dialog
                          _showDeleteRestaurantConfirmation(
                            context,
                            ref,
                            groupId,
                            restaurant,
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: '식당 이름',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: categoryController,
                    decoration: InputDecoration(
                      labelText: '카테고리 (예: 한식, 중식)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('취소'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          final name = nameController.text.trim();
                          final category = categoryController.text.trim();
                          if (name.isNotEmpty) {
                            final updatedRestaurant = restaurant.copyWith(
                              name: name,
                              category: category.isNotEmpty ? category : null,
                            );
                            await ref
                                .read(restaurantRepositoryProvider)
                                .updateRestaurant(groupId, updatedRestaurant);
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                          }
                        },
                        child: const Text('수정'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

void _showDeleteRestaurantConfirmation(
  BuildContext context,
  WidgetRef ref,
  String groupId,
  Restaurant restaurant,
) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('식당 삭제'),
      content: Text('"${restaurant.name}"을(를) 리스트에서 정말 삭제하시겠습니까?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          onPressed: () async {
            await ref
                .read(restaurantRepositoryProvider)
                .deleteRestaurant(groupId, restaurant.id);
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: const Text('삭제'),
        ),
      ],
    ),
  );
}

void _showGroupDetailSheet(
  BuildContext context,
  WidgetRef ref,
  String groupId,
) {
  final group = ref.read(currentGroupProvider);
  if (group == null) return;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return Consumer(
        builder: (context, ref, _) {
          final members = ref.watch(currentGroupMembersProvider).value ?? [];
          final attending = members.where((m) => m.isAttendingToday).toList();

          return DraggableScrollableSheet(
            initialChildSize: 0.55,
            minChildSize: 0.3,
            maxChildSize: 0.85,
            expand: false,
            builder: (context, scrollController) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ListView(
                  controller: scrollController,
                  children: [
                    const SizedBox(height: 8),
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // 그룹명
                    Text(
                      group.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 초대 코드
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.vpn_key_outlined,
                              color: Colors.orange.shade700, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '초대 코드',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  group.inviteCode,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 20),
                            tooltip: '복사',
                            onPressed: () {
                              Clipboard.setData(
                                  ClipboardData(text: group.inviteCode));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('초대 코드가 복사되었습니다.')),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 지역 정보
                    if (group.areaName != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.location_on_outlined,
                                color: Colors.grey.shade700, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '지역',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${group.areaName} (반경 ${group.maxRadiusM.toInt()}m)',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // 멤버 목록
                    Row(
                      children: [
                        const Text(
                          '멤버',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${members.length}명 (${attending.length}명 참여)',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...members.map((m) {
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundImage: m.photoUrl != null
                              ? NetworkImage(m.photoUrl!)
                              : null,
                          child:
                              m.photoUrl == null ? const Icon(Icons.person) : null,
                        ),
                        title: Text(m.displayName),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: m.isAttendingToday
                                ? Colors.green.shade100
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            m.isAttendingToday ? '참여' : '불참',
                            style: TextStyle(
                              fontSize: 12,
                              color: m.isAttendingToday
                                  ? Colors.green.shade800
                                  : Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    // 설정 버튼
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _showGroupSettingsDialog(
                            context, ref, groupId);
                      },
                      icon: const Icon(Icons.settings),
                      label: const Text('그룹 설정'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          );
        },
      );
    },
  );
}

void _showGroupSettingsDialog(
  BuildContext context,
  WidgetRef ref,
  String groupId,
) {
  final group = ref.read(currentGroupProvider);
  if (group == null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('그룹 정보를 불러올 수 없습니다.')));
    return;
  }

  double currentWeight = group.vetoWeightMultiplier;
  String currentDrawMode = group.drawMode;
  final areaController = TextEditingController(text: group.areaName ?? '');
  double currentRadius = group.maxRadiusM;
  double? resolvedLat = group.centerLat;
  double? resolvedLng = group.centerLng;
  String? locationStatus = group.centerLat != null
      ? '${group.centerLat!.toStringAsFixed(4)}, ${group.centerLng!.toStringAsFixed(4)}'
      : null;
  bool isSearching = false;

  showDialog(
    context: context,
    builder: (context) {
      return Consumer(
        builder: (context, ref, child) {
          final members = ref.watch(currentGroupMembersProvider).value ?? [];
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('그룹 설정'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '기본 확률 모드:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      RadioGroup<String>(
                        groupValue: currentDrawMode,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => currentDrawMode = value);
                          }
                        },
                        child: Column(
                          children: [
                            RadioListTile<String>(
                              title: const Text('균등 확률 (모두 동일)'),
                              value: 'equal',
                              contentPadding: EdgeInsets.zero,
                            ),
                            RadioListTile<String>(
                              title: const Text('연차/나이 차등 (개별 가중치)'),
                              value: 'weighted',
                              contentPadding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ),
                      if (currentDrawMode == 'weighted') ...[
                        const Divider(),
                        const Text(
                          '멤버별 기본 가중치 (연차/나이 기반 등):',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        ...members.map((m) {
                          return Row(
                            children: [
                              Expanded(child: Text(m.displayName)),
                              Expanded(
                                flex: 2,
                                child: Slider(
                                  value: m.baseWeight,
                                  min: 1.0,
                                  max: 5.0,
                                  divisions: 8,
                                  label: m.baseWeight.toStringAsFixed(1),
                                  onChanged: (val) {
                                    ref
                                        .read(groupRepositoryProvider)
                                        .updateMemberWeight(
                                          groupId,
                                          m.userId,
                                          val,
                                        );
                                  },
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                      const Divider(),
                      const Text(
                        '거부 이력(Veto)에 따른 가중치(확률 증가):',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '현재 가중치: ${currentWeight.toStringAsFixed(1)}\n'
                        '(1회 거부 시 당첨 확률이 ${(currentWeight * 100).toInt()}% 증가합니다)',
                      ),
                      Slider(
                        value: currentWeight,
                        min: 0.0,
                        max: 2.0,
                        divisions: 20,
                        label: currentWeight.toStringAsFixed(1),
                        onChanged: (value) {
                          setState(() {
                            currentWeight = value;
                          });
                        },
                      ),
                      const Divider(),
                      const Text(
                        '지역 설정 (크롤링용):',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: areaController,
                              decoration: InputDecoration(
                                labelText: '지역명',
                                hintText: '예: 신논현역',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade800,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(60, 40),
                            ),
                            onPressed: isSearching
                                ? null
                                : () async {
                                    final query =
                                        areaController.text.trim();
                                    if (query.isEmpty) return;
                                    setState(() {
                                      isSearching = true;
                                      locationStatus = '검색 중...';
                                    });
                                    final results =
                                        await GeocodingService
                                            .searchLocations(query);
                                    setState(() => isSearching = false);
                                    if (results.isEmpty) {
                                      setState(() {
                                        locationStatus =
                                            '위치를 찾을 수 없습니다';
                                      });
                                      return;
                                    }
                                    if (results.length == 1) {
                                      setState(() {
                                        resolvedLat = results[0].lat;
                                        resolvedLng = results[0].lng;
                                        locationStatus =
                                            results[0].displayName.split(',').take(3).join(',');
                                      });
                                      return;
                                    }
                                    if (!context.mounted) return;
                                    final selected =
                                        await _showLocationPicker(
                                            context, results);
                                    if (selected != null) {
                                      setState(() {
                                        resolvedLat = selected.lat;
                                        resolvedLng = selected.lng;
                                        locationStatus =
                                            selected.displayName.split(',').take(3).join(',');
                                      });
                                    }
                                  },
                            child: isSearching
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('검색'),
                          ),
                        ],
                      ),
                      if (locationStatus != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          locationStatus!,
                          style: TextStyle(
                            fontSize: 12,
                            color: resolvedLat != null
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text('검색 반경: ${currentRadius.toInt()}m'),
                      Slider(
                        value: currentRadius,
                        min: 300,
                        max: 1000,
                        divisions: 14,
                        label: '${currentRadius.toInt()}m',
                        onChanged: (v) =>
                            setState(() => currentRadius = v),
                      ),
                      if (group.lastCrawledAt != null)
                        Text(
                          '마지막 크롤링: ${group.lastCrawledAt!.toLocal().toString().substring(0, 16)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('취소'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      await ref
                          .read(groupRepositoryProvider)
                          .updateGroupSettings(groupId, currentWeight);
                      await ref
                          .read(groupRepositoryProvider)
                          .updateGroupDrawMode(groupId, currentDrawMode);
                      final area = areaController.text.trim();
                      if (resolvedLat != null &&
                          resolvedLng != null &&
                          area.isNotEmpty) {
                        await ref
                            .read(groupRepositoryProvider)
                            .updateGroupLocation(
                              groupId,
                              centerLat: resolvedLat!,
                              centerLng: resolvedLng!,
                              maxRadiusM: currentRadius,
                              areaName: area,
                            );
                      }
                      ref.invalidate(userGroupsProvider);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('설정이 저장되었습니다.')),
                        );
                      }
                    },
                    child: const Text('저장'),
                  ),
                ],
              );
            },
          );
        },
      );
    },
  );
}

String _getEmojiForCategory(String? category) {
  if (category == null || category.isEmpty) return '🍽️';
  final cat = category.toLowerCase();
  if (cat.contains('한식') || cat.contains('korean')) return '🍚';
  if (cat.contains('일식') ||
      cat.contains('japanese') ||
      cat.contains('초밥') ||
      cat.contains('스시') ||
      cat.contains('돈까스')) {
    return '🍣';
  }
  if (cat.contains('중식') ||
      cat.contains('chinese') ||
      cat.contains('짜장') ||
      cat.contains('짬뽕') ||
      cat.contains('마라')) {
    return '🍜';
  }
  if (cat.contains('양식') ||
      cat.contains('western') ||
      cat.contains('파스타') ||
      cat.contains('피자')) {
    return '🍝';
  }
  if (cat.contains('고기') ||
      cat.contains('meat') ||
      cat.contains('구이') ||
      cat.contains('삼겹살')) {
    return '🥩';
  }
  if (cat.contains('분식') || cat.contains('떡볶이') || cat.contains('snack')) {
    return '🥟';
  }
  if (cat.contains('카페') ||
      cat.contains('디저트') ||
      cat.contains('커피') ||
      cat.contains('cafe')) {
    return '☕';
  }
  if (cat.contains('아시안') ||
      cat.contains('asian') ||
      cat.contains('쌀국수') ||
      cat.contains('카레')) {
    return '🍛';
  }
  if (cat.contains('패스트푸드') ||
      cat.contains('햄버거') ||
      cat.contains('버거') ||
      cat.contains('fastfood')) {
    return '🍔';
  }
  if (cat.contains('해산물') || cat.contains('회') || cat.contains('생선')) {
    return '🐟';
  }
  if (cat.contains('치킨') || cat.contains('chicken')) return '🍗';
  return '🍽️';
}

void _showManageRestaurantsBottomSheet(
  BuildContext context,
  WidgetRef ref,
  String groupId,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '팀 식당 관리',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Consumer(
                    builder: (context, ref, child) {
                      final restaurantsAsync = ref.watch(
                        currentGroupRestaurantsProvider,
                      );
                      return restaurantsAsync.when(
                        data: (restaurants) {
                          if (restaurants.isEmpty) {
                            return const Center(child: Text('등록된 식당이 없습니다.'));
                          }
                          return ListView.builder(
                            controller: scrollController,
                            itemCount: restaurants.length,
                            itemBuilder: (context, index) {
                              final restaurant = restaurants[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: restaurant.isDisabled
                                      ? Colors.grey.shade200
                                      : Colors.orange.shade50,
                                  child: Text(
                                    _getEmojiForCategory(restaurant.category),
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                                title: Text(
                                  restaurant.name,
                                  style: TextStyle(
                                    decoration: restaurant.isDisabled
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: restaurant.isDisabled
                                        ? Colors.grey
                                        : null,
                                  ),
                                ),
                                subtitle: Text(
                                  restaurant.category ?? '카테고리 없음',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined),
                                      onPressed: () {
                                        _showEditRestaurantDialog(
                                          context,
                                          ref,
                                          groupId,
                                          restaurant,
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        restaurant.isFavorite
                                            ? Icons.star
                                            : Icons.star_border,
                                        color: restaurant.isFavorite
                                            ? Colors.amber
                                            : Colors.grey,
                                      ),
                                      onPressed: () {
                                        ref
                                            .read(restaurantRepositoryProvider)
                                            .toggleFavorite(
                                              groupId,
                                              restaurant,
                                            );
                                      },
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        restaurant.isDisabled
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        color: restaurant.isDisabled
                                            ? Colors.red.shade300
                                            : Colors.blue,
                                      ),
                                      onPressed: () {
                                        ref
                                            .read(restaurantRepositoryProvider)
                                            .toggleDisabled(
                                              groupId,
                                              restaurant,
                                            );
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, st) => Center(child: Text('오류: $e')),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

class _TodayMenuSelectionsWidget extends ConsumerWidget {
  final String groupId;
  const _TodayMenuSelectionsWidget({required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(currentGroupMembersProvider);
    final user = ref.watch(authStateChangesProvider).value;
    final recentSessionsAsync = ref.watch(recentSessionsProvider);
    final restaurantsAsync = ref.watch(currentGroupRestaurantsProvider);
    final activeSessionAsync = ref.watch(activeSessionProvider);
    final rouletteStateAsync = ref.watch(rouletteStateProvider);

    final members = membersAsync.value ?? [];
    if (members.isEmpty) return const SizedBox.shrink();

    final me = members.where((m) => m.userId == user?.uid).toList();
    final isAttending = me.isNotEmpty && me.first.isAttendingToday;
    final attending = members.where((m) => m.isAttendingToday).toList();

    // 현재 활성 세션 상태 확인
    final activeSession = activeSessionAsync.value;
    final isSessionActive = activeSession != null &&
        (activeSession.status == 'vetoing' ||
            activeSession.status == 'menu_selecting');

    // 오늘 완료된 세션에서 메뉴 선택 데이터 가져오기
    final sessions = recentSessionsAsync.value ?? [];
    final now = DateTime.now();
    final todayCompletedSession = sessions
        .where((s) =>
            (s.status == 'completed' || (s.status == 'cancelled' && s.menuSelections.isNotEmpty)) &&
            s.createdAt.year == now.year &&
            s.createdAt.month == now.month &&
            s.createdAt.day == now.day &&
            s.menuSelections.isNotEmpty)
        .toList();
    final menuSelections = todayCompletedSession.isNotEmpty
        ? todayCompletedSession.first.menuSelections
        : <String, List<String>>{};
    final selectedRestaurantId = todayCompletedSession.isNotEmpty
        ? todayCompletedSession.first.selectedRestaurantId
        : null;

    final restaurants = restaurantsAsync.value ?? [];
    final restaurantName = selectedRestaurantId != null
        ? (restaurants
                .where((r) => r.id == selectedRestaurantId)
                .map((r) => r.name)
                .firstOrNull ??
            '식당')
        : null;

    // 룰렛 상태 확인 (완료 시 평가 UI 숨김용)
    final hasCompletedRouletteToday =
        rouletteStateAsync.value?.status == 'completed';

    // 타이틀: 세션 상태에 따라 변경
    final String title;
    if (restaurantName != null) {
      title = '$restaurantName - 오늘의 메뉴';
    } else if (isSessionActive) {
      title = '오늘의 점심 주문';
    } else {
      title = '오늘의 점심';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            // 참여 토글
            if (me.isNotEmpty)
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  final activeSession = ref.read(activeSessionProvider).value;
                  final hasSelectedMenu = activeSession?.menuSelections.containsKey(user?.uid) ?? false;

                  if (isAttending) {
                    if (hasSelectedMenu) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('메뉴를 이미 선택하여 참여를 취소할 수 없습니다.'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                      return;
                    }
                    ref.read(groupRepositoryProvider).toggleAttendance(
                          groupId,
                          user!.uid,
                          false,
                        );
                  } else {
                    _showAttendanceOptionsDialog(
                        context, ref, groupId, user!.uid);
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        isAttending ? Colors.orange : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isAttending ? '참여 중' : '참여',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color:
                          isAttending ? Colors.white : Colors.grey.shade700,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: attending.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        '아직 참여자가 없어요.\n참여 버튼을 눌러 점심에 합류하세요!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 14),
                      ),
                    ),
                  )
                : Column(
                    children: attending.map((m) {
                      final menus = menuSelections[m.userId];
                      final hasMustEat = m.mustEatRestaurantName != null;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: hasMustEat
                                  ? Colors.red
                                  : Colors.orange.shade100,
                              child: hasMustEat
                                  ? const Icon(Icons.local_fire_department,
                                      size: 14, color: Colors.white)
                                  : Text(
                                      m.displayName[0],
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.orange.shade800,
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m.displayName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                  if (hasMustEat)
                                    Text(
                                      '🔥 ${m.mustEatRestaurantName!}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.red.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              menus != null ? menus.join(', ') : '',
                              style: TextStyle(color: Colors.grey.shade600),
                              textAlign: TextAlign.end,
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ),
        // 식사 후 평가 (룰렛 전일 때만 표시)
        if (todayCompletedSession.isNotEmpty &&
            user != null &&
            !hasCompletedRouletteToday &&
            todayCompletedSession.first.attendingUserIds.contains(user.uid) &&
            !todayCompletedSession.first.ratings.containsKey(user.uid)) ...[
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            color: Colors.amber.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    '${restaurantName ?? '오늘 식당'} 어떠셨나요?',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '과반수 불만족 시 식당이 자동 삭제됩니다',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade400,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            final s = todayCompletedSession.first;
                            ref.read(sessionRepositoryProvider).rateRestaurant(
                                  groupId,
                                  s.id,
                                  user.uid,
                                  true,
                                );
                          },
                          icon: const Icon(Icons.thumb_up, size: 18),
                          label: const Text('맛있었어요'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade400,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            final s = todayCompletedSession.first;
                            ref.read(sessionRepositoryProvider).rateRestaurant(
                                  groupId,
                                  s.id,
                                  user.uid,
                                  false,
                                );
                          },
                          icon: const Icon(Icons.thumb_down, size: 18),
                          label: const Text('별로였어요'),
                        ),
                      ),
                    ],
                  ),
                  // 현재 평가 현황
                  if (todayCompletedSession.first.ratings.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${todayCompletedSession.first.ratings.length}/${todayCompletedSession.first.attendingUserIds.length}명 평가 완료',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
        // 이미 평가한 경우 결과 표시 (룰렛 전일 때만 표시)
        if (todayCompletedSession.isNotEmpty &&
            user != null &&
            !hasCompletedRouletteToday &&
            todayCompletedSession.first.ratings.containsKey(user.uid) &&
            todayCompletedSession.first.ratings.isNotEmpty) ...[
          const SizedBox(height: 12),
          Builder(builder: (context) {
            final ratings = todayCompletedSession.first.ratings;
            final goodCount = ratings.values.where((v) => v).length;
            final badCount = ratings.values.where((v) => !v).length;
            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: Colors.grey.shade50,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.thumb_up, size: 16, color: Colors.green.shade600),
                    const SizedBox(width: 4),
                    Text('$goodCount'),
                    const SizedBox(width: 20),
                    Icon(Icons.thumb_down, size: 16, color: Colors.red.shade600),
                    const SizedBox(width: 4),
                    Text('$badCount'),
                    const SizedBox(width: 20),
                    Text(
                      '(${ratings.length}/${todayCompletedSession.first.attendingUserIds.length}명)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

class _RecentHistoryWidget extends ConsumerWidget {
  final String groupId;
  const _RecentHistoryWidget({required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentAsync = ref.watch(recentSessionsProvider);

    return recentAsync.when(
      data: (sessions) {
        if (sessions.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '최근 점심 히스토리 🗓️',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Center(
                  child: Text(
                    '아직 완료된 점심 기록이 없어요!\n첫 점심 세션을 시작해 보세요 😋',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                ),
              ),
            ],
          );
        }

        // Group sessions by date (max 3 days)
        final restAsync = ref.watch(currentGroupRestaurantsProvider);
        final restaurants = restAsync.value ?? [];

        final Map<String, List<Session>> grouped = {};
        for (final session in sessions) {
          final key =
              '${session.createdAt.year}-${session.createdAt.month}-${session.createdAt.day}';
          grouped.putIfAbsent(key, () => []).add(session);
        }

        final sortedDays = grouped.keys.toList();
        final displayDays = sortedDays.take(3).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '최근 점심 히스토리 🗓️',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            ...displayDays.map((dayKey) {
              final daySessions = grouped[dayKey]!;
              final date = daySessions.first.createdAt;

              // Count restaurant visits for the day
              final Map<String, int> restaurantCounts = {};
              for (final s in daySessions) {
                final name = restaurants
                    .where((r) => r.id == s.selectedRestaurantId)
                    .map((r) => r.name)
                    .firstOrNull ?? '알 수 없음';
                restaurantCounts[name] = (restaurantCounts[name] ?? 0) + 1;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: restaurantCounts.entries.map((entry) {
                            return Text(
                              entry.value > 1
                                  ? '${entry.key} x${entry.value}'
                                  : entry.key,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      Text(
                        '${daySessions.length}회',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _DessertHallOfFameWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(currentGroupMembersProvider);

    return membersAsync.when(
      data: (members) {
        final sorted = List.of(members)
          ..sort((a, b) => b.dessertWins.compareTo(a.dessertWins));
        final topMembers = sorted
            .where((m) => m.dessertWins > 0)
            .take(3)
            .toList();

        if (topMembers.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '후식 명예의 전당 ☕👑',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange.shade50, Colors.amber.shade50],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.shade100, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    '아직 커피 쏜 멤버가 없네요!\n누가 첫 주인공이 될까요? 👀',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '후식 명예의 전당 ☕👑',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade50, Colors.amber.shade50],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.shade100, width: 1.5),
              ),
              child: Column(
                children: topMembers.asMap().entries.map((entry) {
                  final index = entry.key;
                  final member = entry.value;
                  final crown = index == 0
                      ? '🥇'
                      : index == 1
                      ? '🥈'
                      : '🥉';

                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == topMembers.length - 1 ? 0 : 12.0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(crown, style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 8),
                            Text(
                              member.displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${member.dessertWins}회 쏨!',
                            style: TextStyle(
                              color: Colors.orange.shade900,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _RestaurantListBody extends ConsumerWidget {
  final String groupId;
  const _RestaurantListBody({required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restaurantsAsync = ref.watch(currentGroupRestaurantsProvider);

    return restaurantsAsync.when(
      data: (restaurants) {
        final activeRestaurants =
            restaurants.where((r) => !r.isDisabled).toList();
        final disabledCount = restaurants.length - activeRestaurants.length;

        if (restaurants.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                '등록된 식당이 없습니다.\n하단의 + 버튼을 눌러 추가하세요.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;

            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(12),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.0,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final restaurant = activeRestaurants[index];
                        final emoji =
                            _getEmojiForCategory(restaurant.category);

                        return GestureDetector(
                          onTap: () => RestaurantDetailSheet.show(
                              context, restaurant),
                          child: Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 1,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(emoji,
                                      style: const TextStyle(fontSize: 32)),
                                  const SizedBox(height: 8),
                                  Text(
                                    restaurant.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    restaurant.category ?? '',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (restaurant.isFavorite) ...[
                                    const SizedBox(height: 4),
                                    const Icon(Icons.star,
                                        color: Colors.amber, size: 16),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: activeRestaurants.length,
                    ),
                  ),
                ),
                if (disabledCount > 0)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: Text(
                        '숨겨진 식당 $disabledCount개 (관리에서 확인)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('오류: $e')),
    );
  }
}

class _MyTabBody extends ConsumerWidget {
  const _MyTabBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateChangesProvider).value;
    final currentGroupId = ref.watch(currentGroupIdProvider);
    final membersAsync = ref.watch(currentGroupMembersProvider);

    final displayName = user?.displayName ?? '이름 없음';
    final email = user?.email ?? '';

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 16),
        CircleAvatar(
          radius: 40,
          backgroundColor: Colors.orange.shade100,
          child: Text(
            displayName.isNotEmpty ? displayName[0] : '?',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade800,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          displayName,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        if (email.isNotEmpty)
          Text(
            email,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        const SizedBox(height: 32),
        if (currentGroupId != null)
          membersAsync.when(
            data: (members) {
              final me = members
                  .where((m) => m.userId == user?.uid)
                  .toList();
              if (me.isEmpty) return const SizedBox.shrink();
              final member = me.first;
              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '내 그룹 정보',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _infoRow('오늘 참여', member.isAttendingToday ? '참여 중' : '불참'),
                      _infoRow('후식 당첨 횟수', '${member.dessertWins}회'),
                      _infoRow('기본 가중치', member.baseWeight.toStringAsFixed(1)),
                    ],
                  ),
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        // 요일별 자동 참여 스케줄
        if (currentGroupId != null)
          membersAsync.when(
            data: (members) {
              final me = members
                  .where((m) => m.userId == user?.uid)
                  .toList();
              if (me.isEmpty) return const SizedBox.shrink();
              final member = me.first;
              const weekdays = ['월', '화', '수', '목', '금'];
              const weekdayValues = [1, 2, 3, 4, 5];

              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              '요일별 자동 참여',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Switch(
                            value: member.useSchedule,
                            activeThumbColor: Colors.orange,
                            onChanged: (value) {
                              ref
                                  .read(groupRepositoryProvider)
                                  .updateUseSchedule(
                                    currentGroupId,
                                    user!.uid,
                                    value,
                                  );
                            },
                          ),
                        ],
                      ),
                      Text(
                        member.useSchedule
                            ? '선택한 요일에 자동으로 참여 상태가 됩니다'
                            : '사용 시 매일 수동으로 참여를 누를 필요가 없습니다',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (member.useSchedule) ...[
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: List.generate(5, (i) {
                            final isSelected = member.attendanceSchedule
                                .contains(weekdayValues[i]);
                            return GestureDetector(
                              onTap: () {
                                final newSchedule =
                                    List<int>.from(member.attendanceSchedule);
                                if (isSelected) {
                                  newSchedule.remove(weekdayValues[i]);
                                } else {
                                  newSchedule.add(weekdayValues[i]);
                                }
                                ref
                                    .read(groupRepositoryProvider)
                                    .updateAttendanceSchedule(
                                      currentGroupId,
                                      user!.uid,
                                      newSchedule,
                                    );
                              },
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.orange
                                      : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text(
                                    weekdays[i],
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        const SizedBox(height: 24),
        // 그룹 탈퇴
        if (currentGroupId != null)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange.shade700,
              side: BorderSide(color: Colors.orange.shade700),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              final group = ref.read(currentGroupProvider);
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('그룹 탈퇴'),
                  content: Text(
                      '\'${group?.name ?? ''}\'  그룹에서 탈퇴하시겠어요?\n탈퇴 후에는 초대 코드로 다시 참여할 수 있습니다.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('취소'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('탈퇴'),
                    ),
                  ],
                ),
              );
              if (confirmed == true && context.mounted) {
                await ref
                    .read(groupRepositoryProvider)
                    .leaveGroup(currentGroupId, user!.uid);
                ref.read(currentGroupIdProvider.notifier).setGroupId(null);
                ref.invalidate(userGroupsProvider);
              }
            },
            icon: const Icon(Icons.exit_to_app),
            label: const Text('현재 그룹 탈퇴', style: TextStyle(fontSize: 16)),
          ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            side: const BorderSide(color: Colors.red),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () async {
            await ref.read(authRepositoryProvider).signOut();
            if (context.mounted) {
              context.go('/');
            }
          },
          icon: const Icon(Icons.logout),
          label: const Text('로그아웃', style: TextStyle(fontSize: 16)),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _NeedGroupPlaceholder extends StatelessWidget {
  const _NeedGroupPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.group_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            '먼저 그룹을 선택해주세요.\n그룹 탭에서 그룹을 선택하거나 생성하세요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

Future<GeocodingResult?> _showLocationPicker(
  BuildContext context,
  List<GeocodingResult> results,
) {
  return showDialog<GeocodingResult>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('위치 선택'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: results.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final r = results[index];
              final parts = r.displayName.split(',');
              final title = parts.take(2).join(',').trim();
              final subtitle =
                  parts.length > 2 ? parts.skip(2).join(',').trim() : '';
              return ListTile(
                title: Text(title, style: const TextStyle(fontSize: 14)),
                subtitle: subtitle.isNotEmpty
                    ? Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      )
                    : null,
                dense: true,
                onTap: () => Navigator.of(context).pop(r),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
        ],
      );
    },
  );
}

void _showGameChoiceDialog(BuildContext context, WidgetRef ref) {
  final user = ref.read(authStateChangesProvider).value;
  final nickname = user?.displayName ?? '게스트';
  final groupId = ref.read(currentGroupIdProvider);

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('후식 내기'),
      content: const Text('어떤 방식으로 후식 내기를 할까요?'),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            context.push('/roulette');
          },
          child: const Text('룰렛 (기본)'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.open_in_new, size: 18),
          onPressed: () async {
            Navigator.pop(ctx);
            if (groupId == null) return;
            await startCoffeeGame(context, ref, groupId, nickname,
                userId: user?.uid);
          },
          label: const Text('커피 게임 (Lucky Latte)'),
        ),
      ],
    ),
  );
}

