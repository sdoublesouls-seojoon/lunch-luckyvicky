class MenuItem {
  final String name;
  final String price;

  const MenuItem({required this.name, required this.price});

  int? get priceAsInt {
    final digits = price.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    return int.tryParse(digits);
  }

  bool get isUnder15000 => priceAsInt != null && priceAsInt! <= 15000;

  factory MenuItem.fromMap(Map<String, dynamic> map) {
    return MenuItem(
      name: map['name'] ?? '',
      price: map['price'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'price': price};
  }
}
