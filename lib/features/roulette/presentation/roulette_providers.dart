import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lunch_lucky/features/group/domain/group_member.dart';
import 'package:lunch_lucky/features/group/presentation/group_providers.dart';
import 'package:lunch_lucky/features/roulette/data/roulette_repository.dart';
import 'package:lunch_lucky/features/roulette/domain/roulette_state.dart';

final rouletteRepositoryProvider = Provider<RouletteRepository>((ref) {
  return RouletteRepository(firestore: FirebaseFirestore.instance);
});

final rouletteStateProvider = StreamProvider<RouletteState>((ref) {
  final groupId = ref.watch(currentGroupIdProvider);
  if (groupId == null) return const Stream.empty();
  return ref.watch(rouletteRepositoryProvider).watchRouletteState(groupId);
});

class RouletteParticipant {
  final GroupMember member;
  final int vetoCount;
  final double weight;

  RouletteParticipant({
    required this.member,
    required this.vetoCount,
    required this.weight,
  });
}

final rouletteParticipantsProvider = FutureProvider<List<RouletteParticipant>>((
  ref,
) async {
  final members = ref.watch(currentGroupMembersProvider).value;
  if (members == null || members.isEmpty) return [];

  final attendingMembers = members.where((m) => m.isAttendingToday).toList();
  if (attendingMembers.isEmpty) return [];

  final firestore = FirebaseFirestore.instance;

  final participants = <RouletteParticipant>[];

  final currentGroup = ref.watch(currentGroupProvider);
  final vetoMultiplier = currentGroup?.vetoWeightMultiplier ?? 0.5;

  for (final member in attendingMembers) {
    final memberDoc = await firestore
        .collection('groups')
        .doc(currentGroup!.id)
        .collection('members')
        .doc(member.userId)
        .get();
    final vetoCount = memberDoc.data()?['vetoCount'] as int? ?? 0;

    final isWeightedMode = currentGroup!.drawMode == 'weighted';
    final baseWeight = isWeightedMode ? member.baseWeight : 1.0;

    // Base weight, plus multiplier for each veto
    var weight = baseWeight + (vetoCount * vetoMultiplier);

    // Apply MUST EAT penalty
    if (member.mustEatRestaurantId != null) {
      weight *= 2.0;
    }

    participants.add(
      RouletteParticipant(member: member, vetoCount: vetoCount, weight: weight),
    );
  }

  return participants;
});
