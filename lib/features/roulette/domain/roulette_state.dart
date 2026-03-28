class RouletteState {
  final String status; // 'idle', 'spinning', 'completed'
  final String? winnerId;
  final double? targetRotation;
  final DateTime? spinStartedAt;
  final String? gameUrl;
  final DateTime? gameUrlSetAt;
  final String? gameUrlSetBy;

  const RouletteState({
    required this.status,
    this.winnerId,
    this.targetRotation,
    this.spinStartedAt,
    this.gameUrl,
    this.gameUrlSetAt,
    this.gameUrlSetBy,
  });

  factory RouletteState.fromMap(Map<String, dynamic> map) {
    return RouletteState(
      status: map['status'] ?? 'idle',
      winnerId: map['winnerId'],
      targetRotation: (map['targetRotation'] as num?)?.toDouble(),
      spinStartedAt: map['spinStartedAt'] != null
          ? DateTime.parse(map['spinStartedAt'])
          : null,
      gameUrl: map['gameUrl'],
      gameUrlSetAt: map['gameUrlSetAt'] != null
          ? DateTime.parse(map['gameUrlSetAt'])
          : null,
      gameUrlSetBy: map['gameUrlSetBy'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'status': status,
      'winnerId': winnerId,
      'targetRotation': targetRotation,
      'spinStartedAt': spinStartedAt?.toIso8601String(),
      'gameUrl': gameUrl,
      'gameUrlSetAt': gameUrlSetAt?.toIso8601String(),
      'gameUrlSetBy': gameUrlSetBy,
    };
  }

  RouletteState copyWith({
    String? status,
    String? winnerId,
    double? targetRotation,
    DateTime? spinStartedAt,
    String? gameUrl,
    DateTime? gameUrlSetAt,
    String? gameUrlSetBy,
  }) {
    return RouletteState(
      status: status ?? this.status,
      winnerId: winnerId ?? this.winnerId,
      targetRotation: targetRotation ?? this.targetRotation,
      spinStartedAt: spinStartedAt ?? this.spinStartedAt,
      gameUrl: gameUrl ?? this.gameUrl,
      gameUrlSetAt: gameUrlSetAt ?? this.gameUrlSetAt,
      gameUrlSetBy: gameUrlSetBy ?? this.gameUrlSetBy,
    );
  }
}
