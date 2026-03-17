class Group {
  final String id;
  final String name;
  final String inviteCode;
  final String createdBy;
  final DateTime createdAt;
  final double vetoWeightMultiplier;
  final String drawMode; // 'equal' or 'weighted'
  final double? centerLat;
  final double? centerLng;
  final double maxRadiusM;
  final String? areaName;
  final DateTime? lastCrawledAt;

  const Group({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.createdBy,
    required this.createdAt,
    this.vetoWeightMultiplier = 0.5,
    this.drawMode = 'equal',
    this.centerLat,
    this.centerLng,
    this.maxRadiusM = 500,
    this.areaName,
    this.lastCrawledAt,
  });

  factory Group.fromMap(Map<String, dynamic> map, String id) {
    return Group(
      id: id,
      name: map['name'] ?? '',
      inviteCode: map['inviteCode'] ?? '',
      createdBy: map['createdBy'] ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      vetoWeightMultiplier:
          (map['vetoWeightMultiplier'] as num?)?.toDouble() ?? 0.5,
      drawMode: map['drawMode'] ?? 'equal',
      centerLat: (map['centerLat'] as num?)?.toDouble(),
      centerLng: (map['centerLng'] as num?)?.toDouble(),
      maxRadiusM: (map['maxRadiusM'] as num?)?.toDouble() ?? 500,
      areaName: map['areaName'],
      lastCrawledAt: map['lastCrawledAt'] != null
          ? DateTime.parse(map['lastCrawledAt'])
          : null,
    );
  }

  Group copyWith({
    String? id,
    String? name,
    String? inviteCode,
    String? createdBy,
    DateTime? createdAt,
    double? vetoWeightMultiplier,
    String? drawMode,
    double? centerLat,
    double? centerLng,
    double? maxRadiusM,
    String? areaName,
    DateTime? lastCrawledAt,
  }) {
    return Group(
      id: id ?? this.id,
      name: name ?? this.name,
      inviteCode: inviteCode ?? this.inviteCode,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      vetoWeightMultiplier: vetoWeightMultiplier ?? this.vetoWeightMultiplier,
      drawMode: drawMode ?? this.drawMode,
      centerLat: centerLat ?? this.centerLat,
      centerLng: centerLng ?? this.centerLng,
      maxRadiusM: maxRadiusM ?? this.maxRadiusM,
      areaName: areaName ?? this.areaName,
      lastCrawledAt: lastCrawledAt ?? this.lastCrawledAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'inviteCode': inviteCode,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'vetoWeightMultiplier': vetoWeightMultiplier,
      'drawMode': drawMode,
      'centerLat': centerLat,
      'centerLng': centerLng,
      'maxRadiusM': maxRadiusM,
      'areaName': areaName,
      'lastCrawledAt': lastCrawledAt?.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Group &&
        other.id == id &&
        other.name == name &&
        other.inviteCode == inviteCode &&
        other.createdBy == createdBy &&
        other.createdAt == createdAt &&
        other.vetoWeightMultiplier == vetoWeightMultiplier &&
        other.drawMode == drawMode &&
        other.centerLat == centerLat &&
        other.centerLng == centerLng &&
        other.maxRadiusM == maxRadiusM &&
        other.areaName == areaName;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        inviteCode.hashCode ^
        createdBy.hashCode ^
        createdAt.hashCode ^
        vetoWeightMultiplier.hashCode ^
        drawMode.hashCode ^
        centerLat.hashCode ^
        centerLng.hashCode ^
        maxRadiusM.hashCode ^
        areaName.hashCode;
  }
}
