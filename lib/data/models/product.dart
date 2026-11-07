import '../../core/ids_time.dart';

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String name;
  final int price;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;

  factory Product.fromMap(Map<String, Object?> map) => Product(
        id: map['id'] as String,
        name: map['name'] as String,
        price: map['price'] as int,
        createdAt: map['created_at'] as String,
        updatedAt: map['updated_at'] as String,
        deletedAt: map['deleted_at'] as String?,
      );

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as String,
        name: json['name'] as String,
        price: (json['price'] as num).toInt(),
        createdAt: normalizeIso(json['created_at'])!,
        updatedAt: normalizeIso(json['updated_at'])!,
        deletedAt: normalizeIso(json['deleted_at']),
      );

  /// Même forme pour SQLite et pour l'API.
  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'price': price,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'deleted_at': deletedAt,
      };

  Product copyWith({String? name, int? price, String? updatedAt, String? deletedAt}) =>
      Product(
        id: id,
        name: name ?? this.name,
        price: price ?? this.price,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt ?? this.deletedAt,
      );
}
