import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lunch_lucky/features/group/domain/restaurant.dart';
import 'package:lunch_lucky/features/session/domain/session.dart';

class SessionRepository {
  final FirebaseFirestore _firestore;

  SessionRepository({required FirebaseFirestore firestore})
    : _firestore = firestore;

  Stream<Session?> watchActiveSession(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('sessions')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          final latestSession = Session.fromMap(
            snapshot.docs.first.data(),
            snapshot.docs.first.id,
          );
          // 취소/실패된 세션은 null 처리 (홈 화면이 깨끗하게 초기화됨)
          if (latestSession.status == 'cancelled') {
            return null;
          }
          return latestSession;
        });
  }

  Stream<List<Session>> watchRecentSessions(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('sessions')
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Session.fromMap(doc.data(), doc.id))
              .where((s) => s.status == 'completed' || s.menuSelections.isNotEmpty)
              .toList();
        });
  }

  Future<void> startSession(
    String groupId,
    List<String> attendingUserIds,
    List<Restaurant> availableRestaurants, {
    List<String> mustEatRestaurantIds = const [],
  }) async {
    final nextRestaurant = _pickRandomRestaurant(
      availableRestaurants,
      [],
      mustEatRestaurantIds: mustEatRestaurantIds,
    );

    if (nextRestaurant == null) {
      throw Exception('선택 가능한 식당이 없습니다.');
    }

    final sessionRef = _firestore
        .collection('groups')
        .doc(groupId)
        .collection('sessions')
        .doc();
    final session = Session(
      id: sessionRef.id,
      groupId: groupId,
      selectedRestaurantId: nextRestaurant.id,
      status: 'vetoing', // Now people can veto or accept
      attendingUserIds: attendingUserIds,
      vetoes: {},
      acceptances: {},
      previousRestaurantIds: [nextRestaurant.id],
      mustEatRestaurantIds: mustEatRestaurantIds,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(seconds: 30)),
    );

    await sessionRef.set(session.toMap());

    // Reset roulette state for the new session
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

  Future<void> cancelSession(String groupId, String sessionId) async {
    await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('sessions')
        .doc(sessionId)
        .update({'status': 'cancelled'});
  }

  Future<void> voteReject(
    String groupId,
    String sessionId,
    String userId,
    String reason,
    List<Restaurant> availableRestaurants,
  ) async {
    return _firestore.runTransaction((transaction) async {
      final sessionRef = _firestore
          .collection('groups')
          .doc(groupId)
          .collection('sessions')
          .doc(sessionId);
      final sessionSnapshot = await transaction.get(sessionRef);

      if (!sessionSnapshot.exists) return;

      final session = Session.fromMap(sessionSnapshot.data()!, sessionRef.id);
      if (session.status != 'vetoing') return;

      final updatedVetoes = Map<String, String>.from(session.vetoes)
        ..[userId] = reason;

      final totalVotes = updatedVetoes.length + session.acceptances.length;

      if (totalVotes >= session.attendingUserIds.length) {
        _applyMajorityDecision(
          transaction, sessionRef, session,
          updatedVetoes, session.acceptances,
          availableRestaurants,
        );
        return;
      }

      transaction.update(sessionRef, {
        'vetoes': updatedVetoes,
      });
    });
  }

  Future<void> voteAccept(
    String groupId,
    String sessionId,
    String userId,
    List<Restaurant> availableRestaurants,
  ) async {
    return _firestore.runTransaction((transaction) async {
      final sessionRef = _firestore
          .collection('groups')
          .doc(groupId)
          .collection('sessions')
          .doc(sessionId);
      final sessionSnapshot = await transaction.get(sessionRef);

      if (!sessionSnapshot.exists) return;

      final session = Session.fromMap(sessionSnapshot.data()!, sessionRef.id);
      if (session.status != 'vetoing') return;

      final updatedAcceptances = Map<String, bool>.from(session.acceptances)
        ..[userId] = true;

      final totalVotes = session.vetoes.length + updatedAcceptances.length;

      if (totalVotes >= session.attendingUserIds.length) {
        _applyMajorityDecision(
          transaction, sessionRef, session,
          session.vetoes, updatedAcceptances,
          availableRestaurants,
        );
        return;
      }

      transaction.update(sessionRef, {
        'acceptances': updatedAcceptances,
      });
    });
  }

  void _applyMajorityDecision(
    Transaction transaction,
    DocumentReference sessionRef,
    Session session,
    Map<String, String> vetoes,
    Map<String, bool> acceptances,
    List<Restaurant> availableRestaurants,
  ) {
    final rejectCount = vetoes.length;
    final acceptCount = acceptances.length;

    if (acceptCount > rejectCount) {
      // 과반수 찬성 → 메뉴 선택 단계로 이동
      transaction.update(sessionRef, {
        'acceptances': acceptances,
        'vetoes': vetoes,
        'status': 'menu_selecting',
        'menuSelections': {},
        'expiresAt': DateTime.now()
            .add(const Duration(seconds: 10))
            .toIso8601String(),
      });
    } else {
      // 과반수 반대 (동률 포함) → 반대자 전원 패널티 + 다음 식당
      for (final rejectorId in vetoes.keys) {
        final userRef = _firestore.collection('users').doc(rejectorId);
        transaction.update(userRef, {'vetoCount': FieldValue.increment(1)});
      }

      final nextRestaurant = _pickRandomRestaurant(
        availableRestaurants,
        session.previousRestaurantIds,
        mustEatRestaurantIds: session.mustEatRestaurantIds,
      );

      if (nextRestaurant == null) {
        transaction.update(sessionRef, {
          'vetoes': vetoes,
          'acceptances': acceptances,
          'status': 'failed',
        });
        return;
      }

      final updatedPrevious = List<String>.from(session.previousRestaurantIds)
        ..add(nextRestaurant.id);

      transaction.update(sessionRef, {
        'selectedRestaurantId': nextRestaurant.id,
        'vetoes': {},
        'acceptances': {},
        'previousRestaurantIds': updatedPrevious,
        'expiresAt': DateTime.now()
            .add(const Duration(seconds: 30))
            .toIso8601String(),
      });
    }
  }

  Future<void> completeSession(
    String groupId,
    String sessionId,
    String restaurantId,
  ) async {
    await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('sessions')
        .doc(sessionId)
        .update({'status': 'completed'});

    // Update last visited for the restaurant
    await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('restaurants')
        .doc(restaurantId)
        .update({'lastVisitedAt': DateTime.now().toIso8601String()});
  }

  Future<void> selectMenu(
    String groupId,
    String sessionId,
    String userId,
    List<String> menuNames,
  ) async {
    return _firestore.runTransaction((transaction) async {
      final sessionRef = _firestore
          .collection('groups')
          .doc(groupId)
          .collection('sessions')
          .doc(sessionId);
      final sessionSnapshot = await transaction.get(sessionRef);

      if (!sessionSnapshot.exists) return;

      final session = Session.fromMap(sessionSnapshot.data()!, sessionRef.id);
      final updatedSelections = Map<String, List<String>>.from(
        session.menuSelections,
      )..[userId] = menuNames;

      final documentUpdates = <String, dynamic>{
        'menuSelections': updatedSelections,
      };

      // If everyone selected a menu, complete the session
      if (updatedSelections.length >= session.attendingUserIds.length) {
        documentUpdates['status'] = 'completed';
      }

      transaction.update(sessionRef, documentUpdates);
    });
  }

  Future<void> skipMenuSelection(
    String groupId,
    String sessionId,
  ) async {
    await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('sessions')
        .doc(sessionId)
        .update({'status': 'completed'});
  }

  Future<void> rateRestaurant(
    String groupId,
    String sessionId,
    String userId,
    bool isGood,
  ) async {
    return _firestore.runTransaction((transaction) async {
      final sessionRef = _firestore
          .collection('groups')
          .doc(groupId)
          .collection('sessions')
          .doc(sessionId);
      final sessionSnapshot = await transaction.get(sessionRef);

      if (!sessionSnapshot.exists) return;

      final session = Session.fromMap(sessionSnapshot.data()!, sessionRef.id);
      final updatedRatings = Map<String, bool>.from(session.ratings)
        ..[userId] = isGood;

      transaction.update(sessionRef, {'ratings': updatedRatings});

      // 모든 참여자가 평가 완료했는지 확인
      if (updatedRatings.length >= session.attendingUserIds.length) {
        final badCount = updatedRatings.values.where((v) => !v).length;
        // 과반수 불만족이면 식당 비활성화
        if (badCount > session.attendingUserIds.length / 2 &&
            session.selectedRestaurantId != null) {
          final restaurantRef = _firestore
              .collection('groups')
              .doc(groupId)
              .collection('restaurants')
              .doc(session.selectedRestaurantId);
          transaction.update(restaurantRef, {'isDisabled': true});
        }
      }
    });
  }

  Future<void> autoRateAll(String groupId, String sessionId) async {
    return _firestore.runTransaction((transaction) async {
      final sessionRef = _firestore
          .collection('groups')
          .doc(groupId)
          .collection('sessions')
          .doc(sessionId);
      final sessionSnapshot = await transaction.get(sessionRef);

      if (!sessionSnapshot.exists) return;

      final session = Session.fromMap(sessionSnapshot.data()!, sessionRef.id);
      
      // 모든 참여자를 true(좋아요)로 설정
      final updatedRatings = <String, bool>{};
      for (final userId in session.attendingUserIds) {
        updatedRatings[userId] = true;
      }

      transaction.update(sessionRef, {'ratings': updatedRatings});
    });
  }

  Restaurant? _pickRandomRestaurant(
    List<Restaurant> restaurants,
    List<String> excludeIds, {
    List<String> mustEatRestaurantIds = const [],
  }) {
    final validRestaurants = restaurants
        .where((r) => !r.isDisabled && !excludeIds.contains(r.id))
        .toList();

    if (validRestaurants.isEmpty) return null;

    // Simple random picking, can add weight for favorites later
    final random = Random();

    // MUST EAT 우선 처리: Must Eat ID 목록에 있는 식당이 유효한 식당 풀에 있다면 그것들 중에서만 뽑습니다.
    if (mustEatRestaurantIds.isNotEmpty) {
      final mustEatPool =
          validRestaurants.where((r) => mustEatRestaurantIds.contains(r.id)).toList();
      if (mustEatPool.isNotEmpty) {
        return mustEatPool[random.nextInt(mustEatPool.length)];
      }
    }

    // Implement weight for favorite
    final pool = <Restaurant>[];
    for (final r in validRestaurants) {
      pool.add(r);
      if (r.isFavorite) {
        pool.add(r); // Favorites get x2 chance
      }
    }

    return pool[random.nextInt(pool.length)];
  }
}
