import '../../core/ids_time.dart';

class ExpenseCategories {
  static const all = [
    'Marchandises',
    'Transport',
    'Loyer',
    'Électricité / Eau',
    'Salaires',
    'Autre',
  ];
}

class Expense {
  const Expense({
    required this.id,
    required this.category,
    required this.amount,
    this.note,
    required this.spentAt,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String category;
  final int amount;
  final String? note;
  final String spentAt;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;

  factory Expense.fromMap(Map<String, Object?> map) => Expense(
        id: map['id'] as String,
        category: map['category'] as String,
        amount: map['amount'] as int,
        note: map['note'] as String?,
        spentAt: map['spent_at'] as String,
        createdAt: map['created_at'] as String,
        updatedAt: map['updated_at'] as String,
        deletedAt: map['deleted_at'] as String?,
      );

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'] as String,
        category: json['category'] as String,
        amount: (json['amount'] as num).toInt(),
        note: json['note'] as String?,
        spentAt: normalizeIso(json['spent_at'])!,
        createdAt: normalizeIso(json['created_at'])!,
        updatedAt: normalizeIso(json['updated_at'])!,
        deletedAt: normalizeIso(json['deleted_at']),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'category': category,
        'amount': amount,
        'note': note,
        'spent_at': spentAt,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'deleted_at': deletedAt,
      };

  Expense copyWith({String? updatedAt, String? deletedAt}) => Expense(
        id: id,
        category: category,
        amount: amount,
        note: note,
        spentAt: spentAt,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt ?? this.deletedAt,
      );
}
