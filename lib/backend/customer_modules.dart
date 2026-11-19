import 'remote_api.dart';

/// Server-scoped module boundary. RPC failures propagate so UI can retain drafts
/// and offer retry; success means server acceptance, never recipient read status.
class CustomerModules {
  CustomerModules(this.api);
  final RemoteApi api;

  Future<List<Map<String, dynamic>>> discover(
      {String query = '',
      String? category,
      String? district,
      String? availability,
      String? after,
      int limit = 20}) async {
    final rows = await api.rpc('discover_listings', {
      'p_query': query,
      'p_category': category,
      'p_district': district,
      'p_availability': availability,
      'p_after': after,
      'p_limit': limit,
    });
    return (rows as List)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
  }

  Future<void> blockThread(String thread, bool blocked) async {
    await api.rpc('set_thread_block',
        {'p_thread': thread, 'p_blocked': blocked});
  }

  Future<String> createCase(String organization, String subject,
      String description, {String? thread}) async {
    final id = await api.rpc('create_support_case', {
      'p_org': organization,
      'p_subject': subject,
      'p_description': description,
      'p_thread': thread,
    });
    return '$id';
  }

  Future<void> reply(String caseId, String body) async {
    await api.rpc('reply_support_case',
        {'p_case': caseId, 'p_body': body, 'p_internal': false});
  }
}
