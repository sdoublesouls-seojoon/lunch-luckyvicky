import 'package:lunch_lucky/features/group/domain/menu_item.dart';

class Restaurant {
  final String id;
  final String? placeId;
  final String name;
  final String? address;
  final String? category;
  final DateTime? lastVisitedAt;
  final bool isDisabled;
  final bool isFavorite;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;
  final String? addedBy;
  final List<MenuItem> menus;

  const Restaurant({
    required this.id,
    this.placeId,
    required this.name,
    this.address,
    this.category,
    this.lastVisitedAt,
    this.isDisabled = false,
    this.isFavorite = false,
    this.latitude,
    this.longitude,
    required this.createdAt,
    this.addedBy,
    this.menus = const [],
  });

  factory Restaurant.fromMap(Map<String, dynamic> map, String id) {
    return Restaurant(
      id: id,
      placeId: map['placeId'],
      name: map['name'] ?? '',
      address: map['address'],
      category: map['category'],
      lastVisitedAt: map['lastVisitedAt'] != null
          ? DateTime.parse(map['lastVisitedAt'])
          : null,
      isDisabled: map['isDisabled'] ?? false,
      isFavorite: map['isFavorite'] ?? false,
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      addedBy: map['addedBy'],
      menus: (map['menus'] as List<dynamic>?)
              ?.map((m) => MenuItem.fromMap(Map<String, dynamic>.from(m)))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'placeId': placeId,
      'name': name,
      'address': address,
      'category': category,
      'lastVisitedAt': lastVisitedAt?.toIso8601String(),
      'isDisabled': isDisabled,
      'isFavorite': isFavorite,
      'latitude': latitude,
      'longitude': longitude,
      'createdAt': createdAt.toIso8601String(),
      'addedBy': addedBy,
      'menus': menus.map((m) => m.toMap()).toList(),
    };
  }

  Restaurant copyWith({
    String? id,
    String? placeId,
    String? name,
    String? address,
    String? category,
    DateTime? lastVisitedAt,
    bool? isDisabled,
    bool? isFavorite,
    double? latitude,
    double? longitude,
    DateTime? createdAt,
    String? addedBy,
    List<MenuItem>? menus,
  }) {
    return Restaurant(
      id: id ?? this.id,
      placeId: placeId ?? this.placeId,
      name: name ?? this.name,
      address: address ?? this.address,
      category: category ?? this.category,
      lastVisitedAt: lastVisitedAt ?? this.lastVisitedAt,
      isDisabled: isDisabled ?? this.isDisabled,
      isFavorite: isFavorite ?? this.isFavorite,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt ?? this.createdAt,
      addedBy: addedBy ?? this.addedBy,
      menus: menus ?? this.menus,
    );
  }
}
