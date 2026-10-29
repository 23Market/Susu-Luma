/// Local RFQ domain types for the prototype.
///
/// These types validate draft input only. They do not submit an RFQ, reserve
/// stock, contact a supplier, or represent a persisted marketplace record.
class RfqLineItem {
  const RfqLineItem({
    required this.productName,
    required this.quantity,
    required this.unit,
    this.notes = '',
  });

  final String productName;
  final double quantity;
  final String unit;
  final String notes;

  List<String> validate() {
    final errors = <String>[];
    if (productName.trim().isEmpty) errors.add('Product name is required.');
    if (!quantity.isFinite || quantity <= 0) {
      errors.add('Quantity must be greater than zero.');
    }
    if (unit.trim().isEmpty) errors.add('A unit of measure is required.');
    return List.unmodifiable(errors);
  }
}

class RfqDraft {
  const RfqDraft({
    required this.items,
    required this.deliveryLocation,
    this.deliveryDate,
    this.notes = '',
  });

  final List<RfqLineItem> items;
  final String deliveryLocation;
  final DateTime? deliveryDate;
  final String notes;

  /// Returns human-readable validation errors without changing user input.
  ///
  /// Currency and unit conversions are intentionally not inferred. Each line
  /// retains the quantity and unit supplied by the buyer.
  List<String> validate({DateTime? today}) {
    final errors = <String>[];
    if (items.isEmpty) errors.add('Add at least one product.');
    for (var i = 0; i < items.length; i++) {
      for (final error in items[i].validate()) {
        errors.add('Item ${i + 1}: $error');
      }
    }
    if (deliveryLocation.trim().isEmpty) {
      errors.add('Delivery location is required.');
    }
    final date = deliveryDate;
    if (date != null) {
      final reference = today ?? DateTime.now();
      final requestedDay = DateTime(date.year, date.month, date.day);
      final referenceDay = DateTime(
        reference.year,
        reference.month,
        reference.day,
      );
      if (requestedDay.isBefore(referenceDay)) {
        errors.add('Delivery date cannot be in the past.');
      }
    }
    return List.unmodifiable(errors);
  }

  bool get isValid => validate().isEmpty;
}
