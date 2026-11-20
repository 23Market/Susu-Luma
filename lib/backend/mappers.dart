// ignore: deprecated_member_use -- Flutter 3.50 prefers material_ui; keep the SDK-wide import until the project migrates.
import 'package:flutter/material.dart';
import '../chat_media.dart';
import '../models.dart';

/// Pure functions from database rows (PostgREST JSON) to the app's models. No I/O, fully unit-tested.
typedef Row = Map<String, dynamic>;

double num_(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
List<Row> rows(Object? v) => v is List
    ? v.map((e) => Map<String, dynamic>.from(e as Map)).toList()
    : <Row>[];
DateTime ts(Object? v) =>
    DateTime.tryParse('$v')?.toLocal() ??
    DateTime.fromMillisecondsSinceEpoch(0);

const _palette = [
  Color(0xFFE6EDE6),
  Color(0xFFF0E7D8),
  Color(0xFFE2E9F1),
  Color(0xFFF2E8C9),
  Color(0xFFECE4F2),
  Color(0xFFEFE9DA)
];

Business mapBusiness(Row r) => Business(
    id: '${r['id']}',
    name: '${r['display_name'] ?? 'Business'}',
    district: '${r['district'] ?? ''}',
    verified: r['verified'] == true);

IconData categoryIcon(String name) => switch (name) {
      'Agriculture' => Icons.grass_rounded,
      'Metals & Hardware' => Icons.construction_rounded,
      'Equipment & Machinery' => Icons.precision_manufacturing_rounded,
      'Food & Beverage' => Icons.restaurant_rounded,
      'Energy & Power' => Icons.bolt_rounded,
      'Packaging & Office' => Icons.inventory_2_rounded,
      'Logistics & Services' => Icons.local_shipping_rounded,
      _ => Icons.foundation_rounded,
    };

Product mapListing(Row r, Map<String, String> categoryNames) {
  final cat = categoryNames['${r['category']}'] ?? '${r['category']}';
  final mode = '${r['price_mode']}';
  return Product(
      id: '${r['id']}',
      name: '${r['title']}',
      category: cat,
      supplierId: '${r['organization_id']}',
      location: '${r['district'] ?? ''}',
      unit: '${r['quantity_unit']}',
      icon: categoryIcon(cat),
      color: _palette['${r['category']}'.hashCode.abs() % _palette.length],
      indicativePrice: mode == 'quote_only' || r['price_amount'] == null
          ? null
          : num_(r['price_amount']),
      published: '${r['status']}' == 'published');
}

RfqStatus mapRfqStatus(String s) => switch (s) {
      'quoted' => RfqStatus.quoted,
      'accepted' => RfqStatus.accepted,
      'cancelled' || 'closed' => RfqStatus.cancelled,
      _ => RfqStatus.submitted,
    };

QuoteStatus mapQuoteStatus(String s) => switch (s) {
      'accepted' => QuoteStatus.accepted,
      'submitted' => QuoteStatus.submitted,
      _ => QuoteStatus.declined, // declined / expired / withdrawn
    };

OrderStatus mapOrderStatus(String s) => switch (s) {
      'confirmed' => OrderStatus.confirmed,
      'in_fulfilment' || 'partially_delivered' => OrderStatus.inFulfilment,
      'delivered' => OrderStatus.delivered,
      'disputed' => OrderStatus.disputed,
      'cancelled' => OrderStatus.cancelled,
      _ => OrderStatus.awaitingSellerConfirmation,
    };

Quote mapQuote(Row q, Map<String, String> orgNames) {
  final lines = rows(q['quote_lines']);
  final submitted = ts(q['submitted_at'] ?? q['created_at']);
  final validUntil =
      q['validity_until'] == null ? null : ts(q['validity_until']);
  return Quote(
      id: '${q['id']}',
      unitPrice: lines.isEmpty ? 0 : num_(lines.first['unit_price']),
      leadDays: (q['lead_time_days'] as num?)?.toInt() ?? 0,
      validDays:
          validUntil == null ? 0 : validUntil.difference(submitted).inDays,
      terms: '${q['terms'] ?? ''}',
      currency: '${q['currency_code']}',
      status: mapQuoteStatus('${q['status']}'),
      supplierName: orgNames['${q['supplier_organization_id']}'] ?? '');
}

/// [mySupplierId] is the signed-in supplier org (for supplier view); buyers use the first routed supplier.
Rfq mapRfq(Row r,
    {required Map<String, String> orgNames, String? mySupplierId}) {
  final items = rows(r['rfq_items']);
  final first = items.isEmpty ? <String, dynamic>{} : items.first;
  final recipients = rows(r['rfq_recipients']);
  final title =
      '${first['product_title'] ?? 'Request'}${items.length > 1 ? ' +${items.length - 1} more' : ''}';
  return Rfq(
      id: '${r['id']}',
      ref: '${r['reference_code']}',
      productName: title,
      supplierId: mySupplierId ??
          (recipients.isEmpty
              ? ''
              : '${recipients.first['supplier_organization_id']}'),
      quantity: num_(first['quantity']),
      unit: '${first['quantity_unit'] ?? ''}',
      district: '${r['destination_district'] ?? ''}',
      notes: '${r['notes'] ?? ''}',
      target: r['target_delivery_date'] == null
          ? null
          : shortDate(ts(r['target_delivery_date'])),
      status: mapRfqStatus('${r['status']}'),
      buyerName: orgNames['${r['buyer_organization_id']}'] ?? 'Buyer',
      itemIds: items.map((i) => '${i['id']}').toList(),
      quotes: (rows(r['quotes'])
            ..sort(
                (a, b) => ts(a['created_at']).compareTo(ts(b['created_at']))))
          .where((q) =>
              '${q['status']}' != 'revised' && '${q['status']}' != 'draft')
          .map((q) => mapQuote(q, orgNames))
          .toList());
}

Order mapOrder(Row o, {required Map<String, String> orgNames}) {
  final snap =
      Map<String, dynamic>.from((o['accepted_quote_snapshot'] ?? {}) as Map);
  final lines = rows(snap['lines']);
  final first = lines.isEmpty ? <String, dynamic>{} : lines.first;
  final events = rows(o['delivery_events'])
    ..sort((a, b) => ts(a['created_at']).compareTo(ts(b['created_at'])));
  final id = '${o['id']}';
  return Order(
      id: id,
      ref: 'ORD-${id.replaceAll('-', '').substring(0, 8).toUpperCase()}',
      rfqRef: '${snap['rfq_reference'] ?? ''}',
      productName:
          '${first['product_title'] ?? 'Order'}${lines.length > 1 ? ' +${lines.length - 1} more' : ''}',
      supplierId: '${o['supplier_organization_id']}',
      quantity: num_(first['quantity']),
      unit: '${first['quantity_unit'] ?? ''}',
      unitPrice: num_(first['unit_price']),
      currency: '${snap['currency_code'] ?? 'SLE'}',
      leadDays: (snap['lead_time_days'] as num?)?.toInt() ?? 0,
      status: mapOrderStatus('${o['status']}'),
      paymentStatus: '${o['payment_status'] ?? 'pending_unverified'}',
      buyerName: orgNames['${o['buyer_organization_id']}'] ?? 'Buyer',
      snapshotTotal: snap['total'] == null ? null : num_(snap['total']),
      events: events
          .map((e) => DeliveryEvent(
              '${e['event_type']}', '${e['note'] ?? ''}', ts(e['created_at'])))
          .toList());
}

Thread mapThread(Row t, {required Map<String, String> orgNames}) {
  final buyerOrg = '${t['buyer_organization_id']}';
  final msgs = rows(t['messages'])
    ..sort((a, b) => ts(a['created_at']).compareTo(ts(b['created_at'])));
  return Thread(
      id: '${t['id']}',
      title: '${t['subject']}',
      supplierId: '${t['supplier_organization_id']}',
      buyerName: orgNames[buyerOrg] ?? 'Buyer',
      messages: msgs
          .map((m) => ChatMessage(
              '${m['sender_organization_id']}' == buyerOrg
                  ? Role.buyer
                  : Role.supplier,
              '${m['body']}',
              ts(m['created_at']),
              attachment: mapAttachment(m)))
          .toList());
}

/// Photo or voice-note metadata from a message row; the file itself stays in private storage.
Attachment? mapAttachment(Row m) {
  final kind = m['attachment_kind'];
  if (kind == null) return null;
  return Attachment(
      kind: kind == 'voice' ? AttachmentKind.voice : AttachmentKind.image,
      mime: '${m['attachment_mime']}',
      sizeBytes: (m['attachment_bytes'] as num?)?.toInt() ?? 0,
      seconds: (m['attachment_seconds'] as num?)?.toInt(),
      path: '${m['attachment_path']}');
}
