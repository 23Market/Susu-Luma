// ignore_for_file: avoid_dynamic_calls
import 'package:supabase_flutter/supabase_flutter.dart';

/// The only surface the app uses to reach the backend. Authorisation is enforced by Postgres (RLS and
/// SECURITY DEFINER functions); this layer just moves data. A fake implementation backs the unit tests.
abstract class RemoteApi {
  bool get signedIn;
  String? get userId;
  String? get email;
  Future<void> signIn(String email, String password);

  /// Returns true when the account is immediately usable (false = email confirmation pending).
  Future<bool> signUp(String email, String password);
  Future<void> signOut();
  Future<List<Map<String, dynamic>>> select(String table,
      {String columns = '*',
      Map<String, Object>? eq,
      String? orderBy,
      bool descending = false,
      int? limit});
  Future<Map<String, dynamic>> insert(String table, Map<String, dynamic> row);
  Future<dynamic> rpc(String fn, Map<String, dynamic> params);
}

class SupabaseApi implements RemoteApi {
  SupabaseApi(this._client);
  final SupabaseClient _client;

  @override
  bool get signedIn => _client.auth.currentSession != null;
  @override
  String? get userId => _client.auth.currentUser?.id;
  @override
  String? get email => _client.auth.currentUser?.email;

  @override
  Future<void> signIn(String email, String password) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<bool> signUp(String email, String password) async {
    final res = await _client.auth.signUp(email: email, password: password);
    return res.session != null;
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  Future<List<Map<String, dynamic>>> select(String table,
      {String columns = '*',
      Map<String, Object>? eq,
      String? orderBy,
      bool descending = false,
      int? limit}) async {
    var f = _client.from(table).select(columns);
    eq?.forEach((k, v) => f = f.eq(k, v));
    final List<dynamic> rows;
    if (orderBy != null) {
      final o = f.order(orderBy, ascending: !descending);
      rows = await (limit == null ? o : o.limit(limit));
    } else {
      rows = await (limit == null ? f : f.limit(limit));
    }
    return rows.map((r) => Map<String, dynamic>.from(r as Map)).toList();
  }

  @override
  Future<Map<String, dynamic>> insert(
          String table, Map<String, dynamic> row) async =>
      Map<String, dynamic>.from(
          await _client.from(table).insert(row).select().single());

  @override
  Future<dynamic> rpc(String fn, Map<String, dynamic> params) =>
      _client.rpc(fn, params: params);
}
