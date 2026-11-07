import '../../core/ids_time.dart';

/// Ligne du panier pendant la saisie d'une vente (pas persistée telle quelle).
class CartLine {
  CartLine({
    this.productId,
    required this.name,
    required this.unitPrice,
    this.quantity = 1,
  });

  final String? productId;
  final String name;
  final int unitPrice;
  int quantity;

  int get total => unitPrice * quantity;
}

class SaleItem {
  const SaleItem({
    required this.id,
    required this.saleId,
    this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
  });

  final String id;
  final String saleId;
  final String? productId;
  final String productName;
  final int unitPrice;
  final int quantity;

  int get lineTotal => unitPrice * quantity;

  factory SaleItem.fromMap(Map<String, Object?> map) => SaleItem(
        id: map['id'] as String,
        saleId: map['sale_id'] as String,
        productId: map['product_id'] as String?,
        productName: map['product_name'] as String,
        unitPrice: map['unit_price'] as int,
        quantity: map['quantity'] as int,
      );

  factory SaleItem.fromJson(String saleId, Map<String, dynamic> json) => SaleItem(
        id: json['id'] as String,
        saleId: saleId,
        productId: json['product_id'] as String?,
        productName: json['product_name'] as String,
        unitPrice: (json['unit_price'] as num).toInt(),
        quantity: (json['quantity'] as num).toInt(),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'sale_id': saleId,
        'product_id': productId,
        'product_name': productName,
        'unit_price': unitPrice,
        'quantity': quantity,
      };

  Map<String, Object?> toJson() => {
        'id': id,
        'product_id': productId,
        'product_name': productName,
        'unit_price': unitPrice,
        'quantity': quantity,
      };
}

class Sale {
  const Sale({
    required this.id,
    required this.total,
    this.note,
    required this.soldAt,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.items = const [],
  });

  final String id;
  final int total;
  final String? note;
  final String soldAt;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;
  final List<SaleItem> items;

  String get summary => items.map((i) => '${i.quantity}× ${i.productName}').join(', ');

  factory Sale.fromMap(Map<String, Object?> map, List<SaleItem> items) => Sale(
        id: map['id'] as String,
        total: map['total'] as int,
        note: map['note'] as String?,
        soldAt: map['sold_at'] as String,
        createdAt: map['created_at'] as String,
        updatedAt: map['updated_at'] as String,
        deletedAt: map['deleted_at'] as String?,
        items: items,
      );

  factory Sale.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final rawItems = (json['items'] as List<dynamic>?) ?? const [];
    return Sale(
      id: id,
      total: (json['total'] as num).toInt(),
      note: json['note'] as String?,
      soldAt: normalizeIso(json['sold_at'])!,
      createdAt: normalizeIso(json['created_at'])!,
      updatedAt: normalizeIso(json['updated_at'])!,
      deletedAt: normalizeIso(json['deleted_at']),
      items: [
        for (final raw in rawItems) SaleItem.fromJson(id, raw as Map<String, dynamic>),
      ],
    );
  }

  /// Ligne SQLite de la table `sales` (sans les articles).
  Map<String, Object?> toMap() => {
        'id': id,
        'total': total,
        'note': note,
        'sold_at': soldAt,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'deleted_at': deletedAt,
      };

  /// Représentation envoyée à l'API : la vente embarque ses articles, ce qui
  /// garantit qu'une vente est toujours synchronisée de façon atomique.
  Map<String, Object?> toJson() => {
        ...toMap(),
        'items': [for (final item in items) item.toJson()],
      };

  Sale copyWith({String? updatedAt, String? deletedAt}) => Sale(
        id: id,
        total: total,
        note: note,
        soldAt: soldAt,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt ?? this.deletedAt,
        items: items,
      );
}
