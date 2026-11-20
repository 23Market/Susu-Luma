// ignore: deprecated_member_use -- Flutter 3.50 prefers material_ui; keep the SDK-wide import until the project migrates.
import 'package:flutter/material.dart';
import 'chat_media.dart';

enum Role { buyer, supplier }

enum RfqStatus { submitted, quoted, accepted, cancelled }

enum QuoteStatus { submitted, accepted, declined }

enum OrderStatus {
  awaitingSellerConfirmation,
  confirmed,
  inFulfilment,
  delivered,
  disputed,
  cancelled
}

String enumLabel(Object e) {
  final s = e.toString().split('.').last;
  final out =
      s.replaceAllMapped(RegExp(r'[A-Z]'), (m) => ' ${m[0]!.toLowerCase()}');
  return out[0].toUpperCase() + out.substring(1);
}

/// Formats an amount with an explicit currency code. No silent conversion.
String money(num amount, String currency) {
  final fixed =
      amount.toStringAsFixed(amount == amount.roundToDouble() ? 0 : 2);
  final parts = fixed.split('.');
  final whole =
      parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return '$currency $whole${parts.length > 1 ? '.${parts[1]}' : ''}';
}

class Business {
  const Business(
      {required this.id,
      required this.name,
      required this.district,
      this.verified = false});
  final String id, name, district;
  final bool verified;
}

class Product {
  Product(
      {required this.id,
      required this.name,
      required this.category,
      required this.supplierId,
      required this.location,
      required this.unit,
      required this.icon,
      required this.color,
      this.indicativePrice,
      this.published = true});
  final String id, name, category, supplierId, location, unit;
  final IconData icon;
  final Color color;
  final double? indicativePrice; // SLE, indicative only; null = quote only
  bool published; // false = pending marketplace review
}

class Quote {
  Quote(
      {required this.id,
      required this.unitPrice,
      required this.leadDays,
      required this.validDays,
      required this.terms,
      this.currency = 'SLE',
      this.status = QuoteStatus.submitted,
      this.supplierName = ''});
  final String id, terms, currency, supplierName;
  final double unitPrice;
  final int leadDays, validDays;
  QuoteStatus status;
}

class Rfq {
  Rfq(
      {required this.id,
      required this.ref,
      required this.productName,
      required this.supplierId,
      required this.quantity,
      required this.unit,
      required this.district,
      required this.notes,
      this.target,
      this.status = RfqStatus.submitted,
      this.buyerName = 'Aberdeen Construction',
      this.itemIds = const [],
      List<Quote>? quotes})
      : quotes = quotes ?? [];
  final String id,
      ref,
      productName,
      supplierId,
      unit,
      district,
      notes,
      buyerName;

  /// Server item ids (live mode). More than one means a multi-item RFQ.
  final List<String> itemIds;
  final double quantity;
  final String? target;
  RfqStatus status;
  final List<Quote> quotes;
}

class DeliveryEvent {
  const DeliveryEvent(this.type, this.note, this.at);
  final String type, note;
  final DateTime at;
}

class Order {
  Order(
      {required this.id,
      required this.ref,
      required this.rfqRef,
      required this.productName,
      required this.supplierId,
      required this.quantity,
      required this.unit,
      required this.unitPrice,
      required this.currency,
      required this.leadDays,
      this.status = OrderStatus.awaitingSellerConfirmation,
      this.paymentStatus = 'pending_unverified',
      this.buyerName = 'Aberdeen Construction',
      this.snapshotTotal,
      List<DeliveryEvent>? events})
      : events = events ?? [];
  final String id,
      ref,
      rfqRef,
      productName,
      supplierId,
      unit,
      currency,
      buyerName;
  final double? snapshotTotal;
  final double quantity, unitPrice;
  final int leadDays;
  OrderStatus status;

  /// Payment is arranged outside the app; only an administrator can record external evidence.
  String paymentStatus;
  final List<DeliveryEvent> events;
  double get total => snapshotTotal ?? quantity * unitPrice;
}

class ChatMessage {
  const ChatMessage(this.from, this.text, this.at, {this.attachment});
  final Role from;
  final String text;
  final DateTime at;

  /// A photo or voice note. The text is then an optional caption.
  final Attachment? attachment;

  /// One line for conversation lists.
  String get preview => text.isNotEmpty ? text : (attachment?.label ?? '');
}

class Thread {
  Thread(
      {required this.id,
      required this.title,
      required this.supplierId,
      this.buyerName = 'Aberdeen Construction',
      List<ChatMessage>? messages})
      : messages = messages ?? [];
  final String id, title, supplierId, buyerName;
  final List<ChatMessage> messages;
}

/// 'in_transit' -> 'In transit'
String snakeLabel(String s) {
  final t = s.replaceAll('_', ' ');
  return t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);
}

String shortDate(DateTime d) => '${d.day.toString().padLeft(2, '0')} ${const [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ][d.month - 1]} ${d.year}';
