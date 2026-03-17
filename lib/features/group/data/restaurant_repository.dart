import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lunch_lucky/features/group/domain/restaurant.dart';

class RestaurantRepository {
  final FirebaseFirestore _firestore;

  RestaurantRepository({required FirebaseFirestore firestore})
    : _firestore = firestore;

  Stream<List<Restaurant>> watchRestaurants(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('restaurants')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Restaurant.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<void> addRestaurant(String groupId, Restaurant restaurant) async {
    final docRef = _firestore
        .collection('groups')
        .doc(groupId)
        .collection('restaurants')
        .doc();

    // override ID with doc.id
    final newRestaurant = restaurant.copyWith(id: docRef.id);
    await docRef.set(newRestaurant.toMap());
  }

  Future<void> updateRestaurant(String groupId, Restaurant restaurant) async {
    await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('restaurants')
        .doc(restaurant.id)
        .update(restaurant.toMap());
  }

  Future<void> deleteRestaurant(String groupId, String restaurantId) async {
    await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('restaurants')
        .doc(restaurantId)
        .delete();
  }

  Future<void> toggleDisabled(String groupId, Restaurant restaurant) async {
    await updateRestaurant(
      groupId,
      restaurant.copyWith(isDisabled: !restaurant.isDisabled),
    );
  }

  Future<void> toggleFavorite(String groupId, Restaurant restaurant) async {
    await updateRestaurant(
      groupId,
      restaurant.copyWith(isFavorite: !restaurant.isFavorite),
    );
  }
}
