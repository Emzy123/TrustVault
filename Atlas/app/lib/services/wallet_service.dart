import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';
import '../models/wallet_account.dart';
import '../models/wallet_models.dart';

class WalletService {
  WalletService(this._client);

  final SupabaseClient _client;

  Future<WalletAccount?> fetchOwnAccount() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    var data = await _client
        .from('accounts')
        .select()
        .eq('profile_id', userId)
        .maybeSingle();

    if (data == null) {
      // Wallet accounts are created by handle_new_user on signup — not client-side.
      await Future<void>.delayed(const Duration(milliseconds: 500));
      data = await _client
          .from('accounts')
          .select()
          .eq('profile_id', userId)
          .maybeSingle();
    }

    if (data == null) return null;
    return WalletAccount.fromJson(Map<String, dynamic>.from(data));
  }

  Future<double> fetchAvailableBalance(String accountId) async {
    try {
      final result = await _client.rpc<double>(
        'get_available_balance',
        params: {'p_account_id': accountId},
      );
      return (result as num).toDouble();
    } catch (_) {
      return 0.0;
    }
  }

  Future<List<WalletTransaction>> fetchRecentTransactions({
    required String accountId,
    int limit = 20,
    int offset = 0,
  }) async {
    final userId = _client.auth.currentUser!.id;

    final query = _client
        .from('transactions')
        .select()
        .or('initiated_by.eq.$userId,from_account_id.eq.$accountId,to_account_id.eq.$accountId')
        .order('created_at', ascending: false);

    final data = offset > 0
        ? await query.range(offset, offset + limit - 1)
        : await query.limit(limit);

    return (data as List)
        .map((row) => WalletTransaction.fromJson(
              Map<String, dynamic>.from(row as Map),
              ownAccountId: accountId,
            ))
        .toList();
  }

  Future<WalletTransaction?> fetchTransaction(String id, String accountId) async {
    final data = await _client
        .from('transactions')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (data == null) return null;
    return WalletTransaction.fromJson(
      Map<String, dynamic>.from(data),
      ownAccountId: accountId,
    );
  }

  Future<String> submitKyc({
    required String idType,
    required String idNumber,
    required DateTime dob,
    required String address,
    String? documentUrl,
  }) async {
    return submitKycLevel1(
      idType: idType,
      idNumber: idNumber,
      dob: dob,
      address: address,
      documentUrl: documentUrl,
    );
  }

  Future<String> submitKycLevel1({
    required String idType,
    required String idNumber,
    required DateTime dob,
    required String address,
    String? documentUrl,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    final params = {
      'p_id_type': idType,
      'p_id_number': idNumber,
      'p_dob': dob.toIso8601String().split('T').first,
      'p_address': address,
      'p_document_url': documentUrl,
    };

    try {
      final result = await _client.rpc<String>(
        'submit_kyc_level1',
        params: params,
      );
      return result;
    } on PostgrestException catch (error) {
      if (!_isMissingKycLevelRpc(error)) rethrow;
      final fallback = await _client.rpc<String>(
        'submit_kyc',
        params: params,
      );
      return fallback;
    }
  }

  Future<String> submitKycLevel2({
    required String faceImageUrl,
    double matchScore = 94.5,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    final result = await _client.rpc<String>(
      'submit_kyc_level2',
      params: {
        'p_face_image_url': faceImageUrl,
        'p_match_score': matchScore,
      },
    );
    return result;
  }

  Future<String> submitKycLevel3({
    required String proofOfAddressUrl,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    final result = await _client.rpc<String>(
      'submit_kyc_level3',
      params: {
        'p_proof_of_address_url': proofOfAddressUrl,
      },
    );
    return result;
  }

  Future<KycSubmission?> fetchLatestKyc() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final data = await _client
        .from('kyc_submissions')
        .select()
        .eq('profile_id', userId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (data == null) return null;
    return KycSubmission.fromJson(Map<String, dynamic>.from(data));
  }

  Future<String> submitFundingRequest({
    required double amount,
    String? note,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    final params = <String, dynamic>{'p_amount': amount};
    final trimmedNote = note?.trim();
    if (trimmedNote != null && trimmedNote.isNotEmpty) {
      params['p_note'] = trimmedNote;
    }

    final result = await _client.rpc<String>(
      'submit_funding_request',
      params: params,
    );
    return result;
  }

  Future<List<FundingRequest>> fetchFundingRequests() async {
    final userId = _client.auth.currentUser!.id;
    final data = await _client
        .from('funding_requests')
        .select()
        .eq('profile_id', userId)
        .order('created_at', ascending: false);

    return (data as List)
        .map((row) => FundingRequest.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<String> transferFunds({
    required String recipient,
    required double amount,
    String? note,
  }) async {
    final params = <String, dynamic>{
      'p_recipient': recipient,
      'p_amount': amount,
    };
    final trimmedNote = note?.trim();
    if (trimmedNote != null && trimmedNote.isNotEmpty) {
      params['p_note'] = trimmedNote;
    }

    final result = await _client.rpc<String>(
      'transfer_funds',
      params: params,
    );
    return result;
  }

  Future<String> requestWithdrawal({
    required double amount,
    String? note,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    final params = <String, dynamic>{'p_amount': amount};
    final trimmedNote = note?.trim();
    if (trimmedNote != null && trimmedNote.isNotEmpty) {
      params['p_note'] = trimmedNote;
    }

    final result = await _client.rpc<String>(
      'request_withdrawal',
      params: params,
    );
    return result;
  }

  Stream<Profile> watchProfile() {
    final userId = _client.auth.currentUser!.id;
    return _client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .map((rows) => Profile.fromJson(Map<String, dynamic>.from(rows.first)));
  }

  Stream<List<Map<String, dynamic>>> watchTransactions(String accountId) {
    final userId = _client.auth.currentUser!.id;
    return _client
        .from('transactions')
        .stream(primaryKey: ['id'])
        .eq('initiated_by', userId)
        .order('created_at', ascending: false);
  }
}

String mapRpcError(Object error) {
  if (error is PostgrestException) {
    final message = error.message;
    if (message.contains('No API key found in request')) {
      return 'Server connection error. Refresh the page and sign in again.';
    }
    if (message.contains('Could not find the function') &&
        message.contains('submit_kyc')) {
      return 'KYC is not set up on the server. Run supabase/patch_kyc_level_rpcs.sql in the Supabase SQL Editor.';
    }
    if (message.contains('Could not find the function') &&
        (message.contains('transfer_funds') ||
            message.contains('transfer_fund') ||
            message.contains('request_withdrawal') ||
            message.contains('submit_funding_request'))) {
      return 'Wallet transfers are not set up on the server. Run supabase/patch_transfer_and_wallet_rpcs.sql in the Supabase SQL Editor.';
    }
    if (message.contains('Could not choose the best candidate function') &&
        message.contains('submit_kyc')) {
      return 'KYC database needs an update. Run supabase/patch_kyc_level_rpcs.sql in the Supabase SQL Editor.';
    }
    return message;
  }
  if (error is AuthException) {
    return error.message;
  }
  final text = error.toString();
  if (text.contains('Not authenticated')) {
    return 'Your session expired. Please sign in again.';
  }
  return 'Something went wrong. Please try again.';
}

bool _isMissingKycLevelRpc(PostgrestException error) {
  return error.message.contains('Could not find the function') &&
      error.message.contains('submit_kyc_level1');
}
