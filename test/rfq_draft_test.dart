import 'package:flutter_test/flutter_test.dart';
import 'package:susu_luma/models/rfq_draft.dart';

void main() {
  group('RfqLineItem', () {
    test('accepts a positive quantity with an explicit unit', () {
      const item = RfqLineItem(
        productName: 'Portland Cement',
        quantity: 25,
        unit: 'bag',
      );

      expect(item.validate(), isEmpty);
    });

    test('rejects blank product, non-positive quantity and blank unit', () {
      const item = RfqLineItem(productName: ' ', quantity: 0, unit: ' ');

      expect(item.validate(), hasLength(3));
    });

    test('rejects non-finite quantities', () {
      const item = RfqLineItem(
        productName: 'Steel rod',
        quantity: double.infinity,
        unit: 'length',
      );

      expect(item.validate(), contains('Quantity must be greater than zero.'));
    });
  });

  group('RfqDraft', () {
    test('requires at least one item and delivery location', () {
      const draft = RfqDraft(items: [], deliveryLocation: ' ');

      expect(
        draft.validate(),
        containsAll([
          'Add at least one product.',
          'Delivery location is required.',
        ]),
      );
    });

    test('reports invalid item with its line number', () {
      const draft = RfqDraft(
        items: [
          RfqLineItem(productName: 'Cement', quantity: 2, unit: 'bag'),
          RfqLineItem(productName: 'Steel', quantity: -1, unit: 'length'),
        ],
        deliveryLocation: 'Freetown',
      );

      expect(
        draft.validate(),
        contains('Item 2: Quantity must be greater than zero.'),
      );
    });

    test('rejects past delivery dates using supplied reference date', () {
      final draft = RfqDraft(
        items: const [
          RfqLineItem(productName: 'Cement', quantity: 1, unit: 'bag'),
        ],
        deliveryLocation: 'Bo',
        deliveryDate: DateTime(2026, 10, 16),
      );

      expect(
        draft.validate(today: DateTime(2026, 10, 17)),
        contains('Delivery date cannot be in the past.'),
      );
    });

    test('accepts a complete draft with no past delivery date', () {
      final draft = RfqDraft(
        items: const [
          RfqLineItem(productName: 'Cement', quantity: 25, unit: 'bag'),
          RfqLineItem(productName: 'Steel rod', quantity: 10, unit: 'length'),
        ],
        deliveryLocation: 'Freetown',
        deliveryDate: DateTime(2026, 10, 20),
      );

      expect(
        draft.validate(today: DateTime(2026, 10, 17)),
        isEmpty,
      );
    });
  });
}
