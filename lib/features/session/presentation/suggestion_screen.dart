import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lunch_lucky/features/auth/data/auth_repository.dart';
import 'package:lunch_lucky/features/group/presentation/group_providers.dart';
import 'package:lunch_lucky/features/roulette/presentation/roulette_providers.dart';
import 'package:lunch_lucky/features/roulette/presentation/coffee_game_launcher.dart';
import 'package:lunch_lucky/features/session/presentation/menu_selection_view.dart';
import 'package:lunch_lucky/features/session/presentation/session_providers.dart';
import 'package:lunch_lucky/features/session/presentation/widgets/countdown_timer_widget.dart';


class SuggestionScreen extends ConsumerWidget {
  const SuggestionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSessionAsync = ref.watch(activeSessionProvider);
    final currentGroupId = ref.watch(currentGroupIdProvider);
    final user = ref.watch(authStateChangesProvider).value;
    final restaurantsAsync = ref.watch(currentGroupRestaurantsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          activeSessionAsync.value?.status == 'menu_selecting'
              ? '메뉴 선택'
              : '오늘의 추천 식당',
        ),
        actions: [
          if (activeSessionAsync.value != null &&
              activeSessionAsync.value!.status == 'vetoing') ...[
            // 후식 룰렛으로 건너뛰기
            IconButton(
              icon: const Icon(Icons.coffee, color: Colors.brown),
              tooltip: '후식 룰렛으로 건너뛰기',
              onPressed: () async {
                final session = activeSessionAsync.value!;
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('☕ 후식 룰렛으로 건너뛰기'),
                    content: const Text('점심 메뉴 선택을 건너뛰고 바로 후식 룰렛을 돌리시겠어요?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('아니오'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.brown,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('후식 룰렛으로'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && context.mounted) {
                  // 세션 완료 처리 (skipMenuSelection 호출 시 status가 'completed'가 됨)
                  await ref
                      .read(sessionRepositoryProvider)
                      .skipMenuSelection(session.groupId, session.id);
                  await ref
                      .read(groupRepositoryProvider)
                      .resetGroupVetoCounts(session.groupId);
                  if (context.mounted) {
                    _showGameChoiceDialog(context, ref);
                  }
                }
              },
            ),
            // 세션 초기화 (취소)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.red),
              tooltip: '세션 초기화',
              onPressed: () async {
                final session = activeSessionAsync.value!;
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('세션 초기화'),
                    content: const Text('현재 점심 세션을 취소하고 처음부터 다시 시작하시겠어요?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('아니오'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('초기화'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && context.mounted) {
                  // 세션 취소 + 패널티 초기화
                  await ref
                      .read(sessionRepositoryProvider)
                      .cancelSession(session.groupId, session.id);
                  await ref
                      .read(groupRepositoryProvider)
                      .resetGroupVetoCounts(session.groupId);
                  if (context.mounted) {
                    context.go('/home');
                  }
                }
              },
            ),
          ],
        ],
      ),
      body: activeSessionAsync.when(
        data: (session) {
          if (session == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('진행 중인 세션이 없습니다.'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.go('/home'),
                    child: const Text('홈으로 돌아가기'),
                  ),
                ],
              ),
            );
          }

          if (session.status == 'completed') {
            // 바로 홈으로 이동
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                context.go('/home');
              }
            });
            return const Center(child: CircularProgressIndicator());
          }

          if (session.status == 'menu_selecting') {
            return restaurantsAsync.when(
              data: (restaurants) {
                final selectedRestaurant = restaurants.firstWhere(
                  (r) => r.id == session.selectedRestaurantId,
                );
                return MenuSelectionView(
                  session: session,
                  restaurant: selectedRestaurant,
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('오류: $e')),
            );
          }

          if (session.status == 'failed') {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('모든 식당이 거부되어 더 이상 추천할 식당이 없습니다.'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.go('/home'),
                    child: const Text('홈으로 돌아가기'),
                  ),
                ],
              ),
            );
          }

          final membersAsync = ref.watch(currentGroupMembersProvider);
          final members = membersAsync.value ?? [];

          return restaurantsAsync.when(
            data: (restaurants) {
              final selectedRestaurant = restaurants.firstWhere(
                (r) => r.id == session.selectedRestaurantId,
              );

              final isMeAttending = session.attendingUserIds.contains(
                user?.uid,
              );
              final hasVetoed = session.vetoes.containsKey(user?.uid);
              final hasAccepted = session.acceptances.containsKey(user?.uid);
              final canVote = isMeAttending && !hasVetoed;

              // Must Eat 요청자 확인
              final mustEatRequesters = members
                  .where((m) =>
                      m.mustEatRestaurantId == session.selectedRestaurantId)
                  .map((m) => m.displayName)
                  .toList();

              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('이건 어때요?', style: TextStyle(fontSize: 20)),
                      const SizedBox(height: 8),
                      if (canVote)
                        CountdownTimerWidget(
                          expiresAt:
                              session.expiresAt?.toLocal() ??
                              DateTime.now().add(const Duration(seconds: 30)),
                          onTimeout: () {
                            ref
                                .read(sessionRepositoryProvider)
                                .acceptRestaurant(
                                  currentGroupId!,
                                  session.id,
                                  user!.uid,
                                );
                          },
                        ),
                      const SizedBox(height: 16),
                      Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: mustEatRequesters.isNotEmpty
                                ? Colors.red.shade50
                                : null,
                            border: mustEatRequesters.isNotEmpty
                                ? Border.all(
                                    color: Colors.red.shade300, width: 2)
                                : null,
                          ),
                          child: Column(
                            children: [
                              if (mustEatRequesters.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.local_fire_department,
                                          color: Colors.white, size: 16),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${mustEatRequesters.join(", ")}님의 꼭 먹고 싶은 메뉴!',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              const Icon(
                                Icons.restaurant,
                                size: 64,
                                color: Colors.orange,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                selectedRestaurant.name,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (selectedRestaurant.category != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    selectedRestaurant.category!,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        '수락 현황: ${session.acceptances.length} / ${session.attendingUserIds.length}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (canVote)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            FloatingActionButton.extended(
                              heroTag: 'veto',
                              onPressed: hasAccepted
                                  ? null
                                  : () {
                                      ref
                                          .read(sessionRepositoryProvider)
                                          .vetoRestaurant(
                                            currentGroupId!,
                                            session.id,
                                            user!.uid,
                                            '그냥 싫음', // Optional reason
                                            restaurants,
                                          );
                                    },
                              backgroundColor: Colors.red.shade100,
                              foregroundColor: Colors.red.shade900,
                              icon: const Icon(Icons.thumb_down),
                              label: const Text('거부 (패널티)'),
                            ),
                            FloatingActionButton.extended(
                              heroTag: 'accept',
                              onPressed: hasAccepted
                                  ? null
                                  : () {
                                      ref
                                          .read(sessionRepositoryProvider)
                                          .acceptRestaurant(
                                            currentGroupId!,
                                            session.id,
                                            user!.uid,
                                          );
                                    },
                              backgroundColor: Colors.green.shade100,
                              foregroundColor: Colors.green.shade900,
                              icon: const Icon(Icons.thumb_up),
                              label: hasAccepted
                                  ? const Text('수락 완료')
                                  : const Text('수락'),
                            ),
                          ],
                        )
                      else if (!isMeAttending)
                        const Text('세션에 참여하지 않았습니다.'),
                    ],
                  ),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('오류: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('오류: $e')),
      ),
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
            onPressed: () async {
              Navigator.pop(ctx);
              if (groupId != null) {
                await ref
                    .read(rouletteRepositoryProvider)
                    .readyRoulette(groupId);
              }
              if (context.mounted) {
                context.go('/roulette');
              }
            },
            child: const Text('룰렛 (기본)'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.open_in_new, size: 18),
            onPressed: () async {
              Navigator.pop(ctx);
              if (groupId == null) return;
              final user = ref.read(authStateChangesProvider).value;
              await startCoffeeGame(context, ref, groupId, nickname,
                  userId: user?.uid);
            },
            label: const Text('커피 게임 (Lucky Latte)'),
          ),
        ],
      ),
    );
  }
}
