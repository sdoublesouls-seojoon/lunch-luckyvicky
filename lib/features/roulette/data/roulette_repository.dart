import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lunch_lucky/features/roulette/domain/roulette_state.dart';

class RouletteRepository {
  final FirebaseFirestore _firestore;

  RouletteRepository({required FirebaseFirestore firestore})
    : _firestore = firestore;

  Stream<RouletteState> watchRouletteState(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('roulette')
        .doc('state')
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists || snapshot.data() == null) {
            return const RouletteState(status: 'idle');
          }
          return RouletteState.fromMap(snapshot.data()!);
        });
  }

  Future<void> readyRoulette(String groupId) async {
    await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('roulette')
        .doc('state')
        .set({
          'status': 'ready',
          'winnerId': null,
          'targetRotation': null,
          'spinStartedAt': null,
        });
  }

  Future<void> startSpin(
    String groupId,
    String winnerId,
    double targetRotation,
  ) async {
    await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('roulette')
        .doc('state')
        .set({
          'status': 'spinning',
          'winnerId': winnerId,
          'targetRotation': targetRotation,
          'spinStartedAt': DateTime.now().toIso8601String(),
        });
  }

  Future<bool> setCompleted(String groupId) async {
    final docRef = _firestore
        .collection('groups')
        .doc(groupId)
        .collection('roulette')
        .doc('state');

    return await _firestore.runTransaction<bool>((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return false;

      final data = snapshot.data();
      if (data == null || data['status'] == 'completed') {
        return false;
      }

      transaction.update(docRef, {'status': 'completed'});
      return true;
    });
  }

  Future<void> resetRoulette(String groupId) async {
    await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('roulette')
        .doc('state')
        .set({
          'status': 'idle',
          'winnerId': null,
          'targetRotation': null,
          'spinStartedAt': null,
        });
  }
}
