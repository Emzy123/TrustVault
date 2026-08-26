import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Uploads KYC media to the `kyc-documents` storage bucket and returns a public URL.
class KycUploadService {
  KycUploadService(this._client);

  final SupabaseClient _client;
  static const _bucket = 'kyc-documents';

  Future<String> uploadBytes({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    required String folder,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final path =
        '$userId/$folder/${DateTime.now().millisecondsSinceEpoch}_$safeName';

    await _client.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: true,
          ),
        );

    return _client.storage.from(_bucket).getPublicUrl(path);
  }
}
