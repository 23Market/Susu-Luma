import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_api_client.dart';

abstract class AdminDashboardDataSource {
  Future<AdminDashboardSnapshot> fetch();

  Future<void> reviewSupplier(String caseId, String decision, {String? reason});

  Future<void> reviewListing(String listingId, String decision,
      {String? reason});

  Future<void> resolveSupportCase(String caseId, String resolution);
}

class LiveAdminDashboardDataSource implements AdminDashboardDataSource {
  const LiveAdminDashboardDataSource();

  @override
  Future<AdminDashboardSnapshot> fetch() async {
    final Map<String, dynamic>? payload;
    if (kIsWeb) {
      payload = await AuthApiClient.instance.fetchAdminDashboard();
    } else {
      final result =
          await Supabase.instance.client.rpc('admin_dashboard_snapshot');
      payload = _map(result);
    }
    if (payload == null) {
      throw const AdminDashboardException('dashboard_unavailable');
    }
    return AdminDashboardSnapshot.fromJson(payload);
  }

  @override
  Future<void> reviewSupplier(String caseId, String decision,
          {String? reason}) =>
      _mutate(
        web: () => AuthApiClient.instance
            .reviewSupplier(caseId, decision, reason: reason),
        rpc: 'admin_review_supplier',
        parameters: {
          'p_case_id': caseId,
          'p_decision': decision,
          'p_reason': reason
        },
      );

  @override
  Future<void> reviewListing(String listingId, String decision,
          {String? reason}) =>
      _mutate(
        web: () => AuthApiClient.instance
            .reviewListing(listingId, decision, reason: reason),
        rpc: 'admin_review_listing',
        parameters: {
          'p_listing_id': listingId,
          'p_decision': decision,
          'p_reason': reason
        },
      );

  @override
  Future<void> resolveSupportCase(String caseId, String resolution) => _mutate(
        web: () =>
            AuthApiClient.instance.resolveSupportCase(caseId, resolution),
        rpc: 'admin_resolve_support_case',
        parameters: {'p_case_id': caseId, 'p_resolution': resolution},
      );

  Future<void> _mutate({
    required Future<bool> Function() web,
    required String rpc,
    required Map<String, dynamic> parameters,
  }) async {
    if (kIsWeb) {
      if (!await web()) throw const AdminDashboardException('operation_failed');
      return;
    }
    await Supabase.instance.client.rpc(rpc, params: parameters);
  }
}

class AdminDashboardException implements Exception {
  const AdminDashboardException(this.code);
  final String code;

  @override
  String toString() => code;
}

class AdminDashboardSnapshot {
  const AdminDashboardSnapshot({
    required this.generatedAt,
    required this.overview,
    required this.marketplace,
    required this.suppliers,
    required this.revenue,
    required this.operations,
  });

  factory AdminDashboardSnapshot.fromJson(Map<String, dynamic> json) =>
      AdminDashboardSnapshot(
        generatedAt:
            DateTime.tryParse(_text(json['generatedAt'])) ?? DateTime.now(),
        overview: AdminOverview.fromJson(_map(json['overview']) ?? const {}),
        marketplace:
            AdminMarketplace.fromJson(_map(json['marketplace']) ?? const {}),
        suppliers: AdminSuppliers.fromJson(_map(json['suppliers']) ?? const {}),
        revenue: AdminRevenue.fromJson(_map(json['revenue']) ?? const {}),
        operations:
            AdminOperations.fromJson(_map(json['operations']) ?? const {}),
      );

  final DateTime generatedAt;
  final AdminOverview overview;
  final AdminMarketplace marketplace;
  final AdminSuppliers suppliers;
  final AdminRevenue revenue;
  final AdminOperations operations;
}

class AdminOverview {
  const AdminOverview(
      {required this.monthlyRevenue,
      required this.marketplaceGmv,
      required this.qualifiedRfqs,
      required this.conversionRate});
  factory AdminOverview.fromJson(Map<String, dynamic> json) => AdminOverview(
        monthlyRevenue: _number(json['monthlyRevenue']),
        marketplaceGmv: _number(json['marketplaceGmv']),
        qualifiedRfqs: _integer(json['qualifiedRfqs']),
        conversionRate: _number(json['conversionRate']),
      );
  final double monthlyRevenue;
  final double marketplaceGmv;
  final int qualifiedRfqs;
  final double conversionRate;
}

class AdminMarketplace {
  const AdminMarketplace(
      {required this.openRfqs,
      required this.ordersThisMonth,
      required this.disputedOrders,
      required this.recentRfqs});
  factory AdminMarketplace.fromJson(Map<String, dynamic> json) =>
      AdminMarketplace(
        openRfqs: _integer(json['openRfqs']),
        ordersThisMonth: _integer(json['ordersThisMonth']),
        disputedOrders: _integer(json['disputedOrders']),
        recentRfqs: _maps(json['recentRfqs']).map(AdminRfq.fromJson).toList(),
      );
  final int openRfqs;
  final int ordersThisMonth;
  final int disputedOrders;
  final List<AdminRfq> recentRfqs;
}

class AdminRfq {
  const AdminRfq(
      {required this.id,
      required this.referenceCode,
      required this.buyer,
      required this.category,
      required this.status,
      required this.createdAt});
  factory AdminRfq.fromJson(Map<String, dynamic> json) => AdminRfq(
        id: _text(json['id']),
        referenceCode: _text(json['referenceCode']),
        buyer: _text(json['buyer']),
        category: _text(json['category']),
        status: _text(json['status']),
        createdAt: _date(json['createdAt']),
      );
  final String id, referenceCode, buyer, category, status;
  final DateTime? createdAt;
}

class AdminSuppliers {
  const AdminSuppliers(
      {required this.activeSuppliers,
      required this.verifiedSuppliers,
      required this.proSuppliers,
      required this.atRiskSuppliers,
      required this.verificationQueue});
  factory AdminSuppliers.fromJson(Map<String, dynamic> json) => AdminSuppliers(
        activeSuppliers: _integer(json['activeSuppliers']),
        verifiedSuppliers: _integer(json['verifiedSuppliers']),
        proSuppliers: _integer(json['proSuppliers']),
        atRiskSuppliers: _integer(json['atRiskSuppliers']),
        verificationQueue: _maps(json['verificationQueue'])
            .map(AdminVerificationCase.fromJson)
            .toList(),
      );
  final int activeSuppliers, verifiedSuppliers, proSuppliers, atRiskSuppliers;
  final List<AdminVerificationCase> verificationQueue;
}

class AdminVerificationCase {
  const AdminVerificationCase(
      {required this.id,
      required this.organizationId,
      required this.supplier,
      required this.district,
      required this.scope,
      required this.status,
      required this.submittedAt});
  factory AdminVerificationCase.fromJson(Map<String, dynamic> json) =>
      AdminVerificationCase(
        id: _text(json['id']),
        organizationId: _text(json['organizationId']),
        supplier: _text(json['supplier']),
        district: _text(json['district']),
        scope: _text(json['scope']),
        status: _text(json['status']),
        submittedAt: _date(json['submittedAt']),
      );
  final String id, organizationId, supplier, district, scope, status;
  final DateTime? submittedAt;
}

class AdminRevenue {
  const AdminRevenue(
      {required this.monthlyTotal,
      required this.streams,
      required this.history});
  factory AdminRevenue.fromJson(Map<String, dynamic> json) => AdminRevenue(
        monthlyTotal: _number(json['monthlyTotal']),
        streams:
            _maps(json['streams']).map(AdminRevenueStream.fromJson).toList(),
        history:
            _maps(json['history']).map(AdminRevenuePoint.fromJson).toList(),
      );
  final double monthlyTotal;
  final List<AdminRevenueStream> streams;
  final List<AdminRevenuePoint> history;
}

class AdminRevenueStream {
  const AdminRevenueStream(
      {required this.stream, required this.volume, required this.amount});
  factory AdminRevenueStream.fromJson(Map<String, dynamic> json) =>
      AdminRevenueStream(
          stream: _text(json['stream']),
          volume: _integer(json['volume']),
          amount: _number(json['amount']));
  final String stream;
  final int volume;
  final double amount;
}

class AdminRevenuePoint {
  const AdminRevenuePoint({required this.month, required this.amount});
  factory AdminRevenuePoint.fromJson(Map<String, dynamic> json) =>
      AdminRevenuePoint(
          month: _date(json['month']), amount: _number(json['amount']));
  final DateTime? month;
  final double amount;
}

class AdminOperations {
  const AdminOperations(
      {required this.verificationBacklog,
      required this.listingsInReview,
      required this.supportCases,
      required this.highPriorityCases,
      required this.listingQueue,
      required this.supportQueue});
  factory AdminOperations.fromJson(Map<String, dynamic> json) =>
      AdminOperations(
        verificationBacklog: _integer(json['verificationBacklog']),
        listingsInReview: _integer(json['listingsInReview']),
        supportCases: _integer(json['supportCases']),
        highPriorityCases: _integer(json['highPriorityCases']),
        listingQueue: _maps(json['listingQueue'])
            .map(AdminListingReview.fromJson)
            .toList(),
        supportQueue:
            _maps(json['supportQueue']).map(AdminSupportCase.fromJson).toList(),
      );
  final int verificationBacklog,
      listingsInReview,
      supportCases,
      highPriorityCases;
  final List<AdminListingReview> listingQueue;
  final List<AdminSupportCase> supportQueue;
}

class AdminListingReview {
  const AdminListingReview(
      {required this.id,
      required this.title,
      required this.supplier,
      required this.category,
      required this.status,
      required this.createdAt});
  factory AdminListingReview.fromJson(Map<String, dynamic> json) =>
      AdminListingReview(
        id: _text(json['id']),
        title: _text(json['title']),
        supplier: _text(json['supplier']),
        category: _text(json['category']),
        status: _text(json['status']),
        createdAt: _date(json['createdAt']),
      );
  final String id, title, supplier, category, status;
  final DateTime? createdAt;
}

class AdminSupportCase {
  const AdminSupportCase(
      {required this.id,
      required this.priority,
      required this.category,
      required this.subject,
      required this.status,
      required this.organization,
      required this.createdAt});
  factory AdminSupportCase.fromJson(Map<String, dynamic> json) =>
      AdminSupportCase(
        id: _text(json['id']),
        priority: _text(json['priority']),
        category: _text(json['category']),
        subject: _text(json['subject']),
        status: _text(json['status']),
        organization: _text(json['organization']),
        createdAt: _date(json['createdAt']),
      );
  final String id, priority, category, subject, status, organization;
  final DateTime? createdAt;
}

Map<String, dynamic>? _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;
Iterable<Map<String, dynamic>> _maps(dynamic value) => value is List
    ? value.map(_map).whereType<Map<String, dynamic>>()
    : const [];
String _text(dynamic value) => value?.toString() ?? '';
double _number(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse(_text(value)) ?? 0;
int _integer(dynamic value) =>
    value is num ? value.toInt() : int.tryParse(_text(value)) ?? 0;
DateTime? _date(dynamic value) => DateTime.tryParse(_text(value));
