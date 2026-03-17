class GroupMember {
  final String userId;
  final String displayName;
  final String? photoUrl;
  final bool isAttendingToday;
  final DateTime joinedAt;
  final double baseWeight;
  final int dessertWins;
  final bool useSchedule; // 자동 스케줄 사용 여부
  final List<int> attendanceSchedule; // 요일별 자동 참여 (1=월 ~ 7=일)
  final String? mustEatRestaurantId; // 오늘 꼭 먹고 싶은 식당 ID
  final String? mustEatRestaurantName; // 오늘 꼭 먹고 싶은 식당 이름

  const GroupMember({
    required this.userId,
    required this.displayName,
    this.photoUrl,
    this.isAttendingToday = false,
    required this.joinedAt,
    this.baseWeight = 1.0,
    this.dessertWins = 0,
    this.useSchedule = false,
    this.attendanceSchedule = const [],
    this.mustEatRestaurantId,
    this.mustEatRestaurantName,
  });

  factory GroupMember.fromMap(Map<String, dynamic> map, String userId) {
    return GroupMember(
      userId: userId,
      displayName: map['displayName'] ?? '이름 없음',
      photoUrl: map['photoUrl'],
      isAttendingToday: map['isAttendingToday'] ?? false,
      joinedAt: map['joinedAt'] != null
          ? DateTime.parse(map['joinedAt'])
          : DateTime.now(),
      baseWeight: (map['baseWeight'] as num?)?.toDouble() ?? 1.0,
      dessertWins: map['dessertWins'] as int? ?? 0,
      useSchedule: map['useSchedule'] ?? false,
      attendanceSchedule: List<int>.from(map['attendanceSchedule'] ?? []),
      mustEatRestaurantId: map['mustEatRestaurantId'],
      mustEatRestaurantName: map['mustEatRestaurantName'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'photoUrl': photoUrl,
      'isAttendingToday': isAttendingToday,
      'joinedAt': joinedAt.toIso8601String(),
      'baseWeight': baseWeight,
      'dessertWins': dessertWins,
      'useSchedule': useSchedule,
      'attendanceSchedule': attendanceSchedule,
      'mustEatRestaurantId': mustEatRestaurantId,
      'mustEatRestaurantName': mustEatRestaurantName,
    };
  }

  GroupMember copyWith({
    String? userId,
    String? displayName,
    String? photoUrl,
    bool? isAttendingToday,
    DateTime? joinedAt,
    double? baseWeight,
    int? dessertWins,
    bool? useSchedule,
    List<int>? attendanceSchedule,
    String? mustEatRestaurantId,
    String? mustEatRestaurantName,
  }) {
    return GroupMember(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      isAttendingToday: isAttendingToday ?? this.isAttendingToday,
      joinedAt: joinedAt ?? this.joinedAt,
      baseWeight: baseWeight ?? this.baseWeight,
      dessertWins: dessertWins ?? this.dessertWins,
      useSchedule: useSchedule ?? this.useSchedule,
      attendanceSchedule: attendanceSchedule ?? this.attendanceSchedule,
      mustEatRestaurantId: mustEatRestaurantId ?? this.mustEatRestaurantId,
      mustEatRestaurantName:
          mustEatRestaurantName ?? this.mustEatRestaurantName,
    );
  }
}
