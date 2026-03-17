class RouletteState {
  final String status; // 'idle', 'spinning', 'completed'
  final String? winnerId;
  final double? targetRotation;
  final DateTime? spinStartedAt;

  const RouletteState({
    required this.status,
    this.winnerId,
    this.targetRotation,
    this.spinStartedAt,
  });

  factory RouletteState.fromMap(Map<String, dynamic> map) {
    return RouletteState(
      status: map['status'] ?? 'idle',
      winnerId: map['winnerId'],
      targetRotation: (map['targetRotation'] as num?)?.toDouble(),
      spinStartedAt: map['spinStartedAt'] != null
          ? DateTime.parse(map['spinStartedAt'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'status': status,
      'winnerId': winnerId,
      'targetRotation': targetRotation,
      'spinStartedAt': spinStartedAt?.toIso8601String(),
    };
  }

  RouletteState copyWith({
    String? status,
    String? winnerId,
    double? targetRotation,
    DateTime? spinStartedAt,
  }) {
    return RouletteState(
      status: status ?? this.status,
      winnerId: winnerId ?? this.winnerId,
      targetRotation: targetRotation ?? this.targetRotation,
      spinStartedAt: spinStartedAt ?? this.spinStartedAt,
    );
  }
}
