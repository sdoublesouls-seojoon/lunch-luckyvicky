import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lunch_lucky/features/group/presentation/group_providers.dart';
import 'package:lunch_lucky/features/session/data/session_repository.dart';
import 'package:lunch_lucky/features/session/domain/session.dart';

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return SessionRepository(firestore: FirebaseFirestore.instance);
});

final activeSessionProvider = StreamProvider<Session?>((ref) {
  final groupId = ref.watch(currentGroupIdProvider);
  if (groupId == null) return const Stream.empty();

  return ref.watch(sessionRepositoryProvider).watchActiveSession(groupId);
});

final recentSessionsProvider = StreamProvider<List<Session>>((ref) {
  final groupId = ref.watch(currentGroupIdProvider);
  if (groupId == null) return const Stream.empty();

  return ref.watch(sessionRepositoryProvider).watchRecentSessions(groupId);
});
