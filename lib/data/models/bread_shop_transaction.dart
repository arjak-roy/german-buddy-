class BreadItem {
  final String name;
  final String germanName;
  final double priceEur;
  final String emoji;

  const BreadItem({
    required this.name,
    required this.germanName,
    required this.priceEur,
    required this.emoji,
  });
}

class BreadShopNegotiation {
  final String
  action; // 'offer_item', 'counter_offer', 'accept', 'reject', 'complete_sale'
  final String item; // Item name or empty
  final double itemPrice; // EUR
  final int quantity;
  final double totalPrice; // EUR
  final String shopkeeperResponse; // German + English
  final String englishTranslation;
  final bool dealAccepted;

  const BreadShopNegotiation({
    required this.action,
    required this.item,
    required this.itemPrice,
    required this.quantity,
    required this.totalPrice,
    required this.shopkeeperResponse,
    required this.englishTranslation,
    required this.dealAccepted,
  });

  factory BreadShopNegotiation.fromFunctionArgs(Map<String, dynamic> args) {
    int parseQty(dynamic value) {
      if (value is int) return value.clamp(1, 20);
      if (value is num) return value.toInt().clamp(1, 20);
      if (value is String) return (int.tryParse(value) ?? 1).clamp(1, 20);
      return 1;
    }

    double parsePrice(dynamic value) {
      if (value is double) return value.clamp(0.0, 100.0);
      if (value is num) return value.toDouble().clamp(0.0, 100.0);
      if (value is String)
        return (double.tryParse(value) ?? 0.0).clamp(0.0, 100.0);
      return 0.0;
    }

    final qty = parseQty(args['quantity']);
    final unitPrice = parsePrice(args['itemPrice']);
    final total = parsePrice(args['totalPrice']);

    return BreadShopNegotiation(
      action: (args['action'] ?? 'offer_item').toString().trim().toLowerCase(),
      item: (args['item'] ?? '').toString().trim(),
      itemPrice: unitPrice,
      quantity: qty,
      totalPrice: total,
      shopkeeperResponse: (args['shopkeeperResponse'] ?? '').toString().trim(),
      englishTranslation: (args['englishTranslation'] ?? '').toString().trim(),
      dealAccepted:
          (args['dealAccepted'] ?? false).toString().toLowerCase() == 'true',
    );
  }
}
