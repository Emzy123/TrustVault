import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/admin_models.dart';
import '../models/profile.dart';

class AdminService {
  AdminService(this._client);

  final SupabaseClient _client;

  Map<String, dynamic> _parseRpcJsonMap(dynamic response) {
    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }
    if (response is String) {
      final decoded = jsonDecode(response);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    }
    throw FormatException('Unexpected RPC response: ${response.runtimeType}');
  }

  Future<AdminMetrics> fetchAdminMetrics() async {
    final response = await _client.rpc('get_admin_metrics');
    return AdminMetrics.fromJson(_parseRpcJsonMap(response));
  }

  Future<SuperAdminMetrics> fetchSuperAdminMetrics() async {
    final response = await _client.rpc('get_super_admin_metrics');
    return SuperAdminMetrics.fromJson(_parseRpcJsonMap(response));
  }

  Future<List<Map<String, dynamic>>> fetchKycQueue() async {
    final data = await _client
        .from('kyc_submissions')
        .select('*, profiles!profile_id(id, full_name, email)')
        .eq('status', 'pending')
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<void> reviewKyc({
    required String submissionId,
    required bool approve,
    String? declineReason,
  }) async {
    await _client.rpc(
      'review_kyc_submission',
      params: {
        'p_submission_id': submissionId,
        'p_approve': approve,
        'p_decline_reason': declineReason,
      },
    );
  }

  Future<List<Map<String, dynamic>>> fetchFundingQueue() async {
    final data = await _client
        .from('funding_requests')
        .select('*, profiles!profile_id(id, full_name, email)')
        .eq('status', 'pending')
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<void> reviewFunding({
    required String requestId,
    required bool approve,
    String? declineReason,
  }) async {
    await _client.rpc(
      'approve_funding_request',
      params: {
        'p_request_id': requestId,
        'p_decline_reason': approve ? null : (declineReason ?? 'Declined by admin'),
      },
    );
  }

  Future<List<Map<String, dynamic>>> fetchWithdrawalQueue() async {
    final data = await _client
        .from('transactions')
        .select('*, accounts!from_account_id(profiles(id, full_name, email, account_status, kyc_status))')
        .eq('type', 'withdrawal')
        .eq('status', 'pending')
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<void> reviewWithdrawal({
    required String transactionId,
    required bool approve,
    String? declineReason,
  }) async {
    await _client.rpc(
      'review_withdrawal',
      params: {
        'p_transaction_id': transactionId,
        'p_approve': approve,
        'p_decline_reason': declineReason,
      },
    );
  }

  Future<List<Profile>> fetchUsers({String? query}) async {
    final hasQuery = query != null && query.trim().isNotEmpty;
    final data = hasQuery
        ? await _client
            .from('profiles')
            .select()
            .or('full_name.ilike.%${query.trim()}%,email.ilike.%${query.trim()}%')
            .order('created_at', ascending: false)
        : await _client
            .from('profiles')
            .select()
            .order('created_at', ascending: false);
    return (data as List).map((row) => Profile.fromJson(Map<String, dynamic>.from(row as Map))).toList();
  }

  Future<void> setAccountStatus({
    required String profileId,
    required String status,
    String? reason,
  }) async {
    await _client.rpc(
      'set_account_status',
      params: {
        'p_profile_id': profileId,
        'p_status': status,
        'p_reason': reason,
      },
    );
  }

  Future<List<Map<String, dynamic>>> fetchTransactions({int limit = 50}) async {
    final data = await _client
        .from('transactions')
        .select('*, profiles!initiated_by(full_name, email)')
        .order('created_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<void> raiseFlag({
    required String transactionId,
    required String reason,
  }) async {
    await _client.rpc(
      'raise_flag',
      params: {
        'p_transaction_id': transactionId,
        'p_reason': reason,
      },
    );
  }

  Future<List<TransactionFlag>> fetchFlags() async {
    final data = await _client
        .from('flags')
        .select('*, transactions(*, profiles!initiated_by(email))')
        .order('created_at', ascending: false);

    return (data as List).map((row) => TransactionFlag.fromJson(Map<String, dynamic>.from(row as Map))).toList();
  }

  Future<void> resolveFlag({
    required String flagId,
    required bool dismiss,
    String? resolutionNote,
    bool freezeAccount = false,
  }) async {
    await _client.rpc(
      'resolve_flag',
      params: {
        'p_flag_id': flagId,
        'p_dismiss': dismiss,
        'p_resolution_note': resolutionNote,
        'p_freeze_account': freezeAccount,
      },
    );
  }

  Future<List<AuditLogItem>> fetchAuditLogs({int limit = 100}) async {
    final data = await _client
        .from('audit_logs')
        .select('*, profiles!actor_id(email, full_name)')
        .order('created_at', ascending: false)
        .limit(limit);

    return (data as List).map((row) => AuditLogItem.fromJson(Map<String, dynamic>.from(row as Map))).toList();
  }

  Future<void> manageUserRole({
    required String profileId,
    required String role,
  }) async {
    await _client.rpc(
      'manage_user_role',
      params: {
        'p_profile_id': profileId,
        'p_role': role,
      },
    );
  }

  Future<String?> inviteAdminUser({
    required String email,
    String role = 'admin',
  }) async {
    final response = await _client.rpc(
      'invite_admin_user',
      params: {
        'p_email': email.trim(),
        'p_role': role,
      },
    );
    return response as String?;
  }

  Future<PlatformAnalytics> fetchPlatformAnalytics() async {
    final response = await _client.rpc('get_platform_analytics');
    return PlatformAnalytics.fromJson(_parseRpcJsonMap(response));
  }

  Future<List<AdminInvitation>> fetchAdminInvitations() async {
    final data = await _client
        .from('admin_invitations')
        .select()
        .order('created_at', ascending: false);

    return (data as List)
        .map((row) => AdminInvitation.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<List<Profile>> fetchAdmins() async {
    final data = await _client
        .from('profiles')
        .select()
        .inFilter('role', ['admin', 'super_admin'])
        .order('created_at', ascending: false);

    return (data as List).map((row) => Profile.fromJson(Map<String, dynamic>.from(row as Map))).toList();
  }

  Future<String?> createUserAccount({
    required String email,
    required String fullName,
    String role = 'user',
    String? password,
  }) async {
    final response = await _client.rpc(
      'create_user_account',
      params: {
        'p_email': email.trim(),
        'p_full_name': fullName.trim(),
        'p_role': role,
        'p_password': password,
      },
    );
    return response as String?;
  }

  Future<void> deleteUserAccount({required String profileId}) async {
    await _client.rpc(
      'delete_user_account',
      params: {'p_profile_id': profileId},
    );
  }
}
