class Session {
  final String id;
  final String groupId;
  final String? selectedRestaurantId;
  final String status; // 'picking', 'vetoing', 'confirmed'
  final List<String> attendingUserIds;
  final Map<String, String> vetoes; // userId -> reason
  final Map<String, bool> acceptances; // userId -> bool
  final List<String>
      previousRestaurantIds; // History of suggested restaurants this session
  final Map<String, List<String>> menuSelections; // userId -> menuNames
  final Map<String, bool> ratings; // userId -> true(good)/false(bad)
  final List<String> mustEatRestaurantIds; // Must Eat ids
  final DateTime createdAt;
  final DateTime? expiresAt; // For veto timeout

  const Session({
    required this.id,
    required this.groupId,
    this.selectedRestaurantId,
    required this.status,
    required this.attendingUserIds,
    required this.vetoes,
    required this.acceptances,
    required this.previousRestaurantIds,
    this.menuSelections = const {},
    this.ratings = const {},
    this.mustEatRestaurantIds = const [],
    required this.createdAt,
    this.expiresAt,
  });

  factory Session.fromMap(Map<String, dynamic> map, String id) {
    return Session(
      id: id,
      groupId: map['groupId'] ?? '',
      selectedRestaurantId: map['selectedRestaurantId'],
      status: map['status'] ?? 'picking',
      attendingUserIds: List<String>.from(map['attendingUserIds'] ?? []),
      vetoes: Map<String, String>.from(map['vetoes'] ?? {}),
      acceptances: Map<String, bool>.from(map['acceptances'] ?? {}),
      previousRestaurantIds: List<String>.from(
        map['previousRestaurantIds'] ?? [],
      ),
      menuSelections: (map['menuSelections'] as Map<String, dynamic>? ?? {}).map(
        (key, value) => MapEntry(key, List<String>.from(value)),
      ),
      ratings: Map<String, bool>.from(map['ratings'] ?? {}),
      mustEatRestaurantIds:
          List<String>.from(map['mustEatRestaurantIds'] ?? []),
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      expiresAt: map['expiresAt'] != null
          ? DateTime.parse(map['expiresAt'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'selectedRestaurantId': selectedRestaurantId,
      'status': status,
      'attendingUserIds': attendingUserIds,
      'vetoes': vetoes,
      'acceptances': acceptances,
      'previousRestaurantIds': previousRestaurantIds,
      'menuSelections': menuSelections,
      'ratings': ratings,
      'mustEatRestaurantIds': mustEatRestaurantIds,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
    };
  }
}
