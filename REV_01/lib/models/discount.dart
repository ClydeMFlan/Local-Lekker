class Discount {
  final String id;
  final String trustedPartnerId;
  final String name;
  final String description;
  final double percentage;
  final double? fixedAmount;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Discount({
    required this.id,
    required this.trustedPartnerId,
    required this.name,
    required this.description,
    required this.percentage,
    this.fixedAmount,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Discount.fromJson(Map<String, dynamic> json) {
    return Discount(
      id: json['id'] as String,
      trustedPartnerId: json['trusted_partner_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      percentage: (json['percentage'] as num).toDouble(),
      fixedAmount: json['fixed_amount'] != null
          ? (json['fixed_amount'] as num).toDouble()
          : null,
      isActive: json['is_active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trusted_partner_id': trustedPartnerId,
      'name': name,
      'description': description,
      'percentage': percentage,
      'fixed_amount': fixedAmount,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String get discountDisplay {
    if (fixedAmount != null && fixedAmount! > 0) {
      return 'R${fixedAmount!.toStringAsFixed(2)} off';
    } else {
      return '${percentage.toStringAsFixed(0)}% off';
    }
  }
}
