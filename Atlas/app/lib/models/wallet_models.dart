enum TransactionType {
  transfer('transfer'),
  deposit('deposit'),
  withdrawal('withdrawal'),
  funding('funding');

  const TransactionType(this.value);
  final String value;

  static TransactionType fromString(String? raw) {
    return TransactionType.values.firstWhere(
      (t) => t.value == raw,
      orElse: () => TransactionType.transfer,
    );
  }

  String get label {
    switch (this) {
      case TransactionType.transfer:
        return 'Transfer';
      case TransactionType.deposit:
        return 'Deposit';
      case TransactionType.withdrawal:
        return 'Withdrawal';
      case TransactionType.funding:
        return 'Funding';
    }
  }
}

enum TransactionStatus {
  pending('pending'),
  completed('completed'),
  declined('declined'),
  flagged('flagged'),
  reversed('reversed');

  const TransactionStatus(this.value);
  final String value;

  static TransactionStatus fromString(String? raw) {
    return TransactionStatus.values.firstWhere(
      (s) => s.value == raw,
      orElse: () => TransactionStatus.pending,
    );
  }

  String get label {
    switch (this) {
      case TransactionStatus.pending:
        return 'Pending Review';
      case TransactionStatus.completed:
        return 'Completed';
      case TransactionStatus.declined:
        return 'Declined';
      case TransactionStatus.flagged:
        return 'Flagged';
      case TransactionStatus.reversed:
        return 'Reversed';
    }
  }
}

class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.declineReason,
    this.note,
    this.fromAccountId,
    this.toAccountId,
    this.isIncoming = false,
    this.counterpartyLabel,
  });

  final String id;
  final TransactionType type;
  final double amount;
  final TransactionStatus status;
  final DateTime createdAt;
  final String? declineReason;
  final String? note;
  final String? fromAccountId;
  final String? toAccountId;
  final bool isIncoming;
  final String? counterpartyLabel;

  factory WalletTransaction.fromJson(
    Map<String, dynamic> json, {
    required String ownAccountId,
  }) {
    final fromId = json['from_account_id'] as String?;
    final toId = json['to_account_id'] as String?;
    final isIncoming = toId == ownAccountId && fromId != ownAccountId;

    return WalletTransaction(
      id: json['id'] as String,
      type: TransactionType.fromString(json['type'] as String?),
      amount: (json['amount'] as num).toDouble(),
      status: TransactionStatus.fromString(json['status'] as String?),
      createdAt: DateTime.parse(json['created_at'] as String),
      declineReason: json['decline_reason'] as String?,
      note: json['note'] as String?,
      fromAccountId: fromId,
      toAccountId: toId,
      isIncoming: isIncoming,
    );
  }
}

class FundingRequest {
  const FundingRequest({
    required this.id,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.note,
    this.declineReason,
  });

  final String id;
  final double amount;
  final String status;
  final DateTime createdAt;
  final String? note;
  final String? declineReason;

  factory FundingRequest.fromJson(Map<String, dynamic> json) {
    return FundingRequest(
      id: json['id'] as String,
      amount: (json['amount'] as num).toDouble(),
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      note: json['note'] as String?,
      declineReason: json['decline_reason'] as String?,
    );
  }
}

class KycSubmission {
  const KycSubmission({
    required this.id,
    required this.status,
    required this.createdAt,
    this.level = 1,
    this.idType,
    this.idNumber,
    this.dob,
    this.address,
    this.documentUrl,
    this.faceImageUrl,
    this.faceMatchScore,
    this.proofOfAddressUrl,
    this.declineReason,
  });

  final String id;
  final String status;
  final DateTime createdAt;
  final int level;
  final String? idType;
  final String? idNumber;
  final DateTime? dob;
  final String? address;
  final String? documentUrl;
  final String? faceImageUrl;
  final double? faceMatchScore;
  final String? proofOfAddressUrl;
  final String? declineReason;

  factory KycSubmission.fromJson(Map<String, dynamic> json) {
    return KycSubmission(
      id: json['id'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      level: json['level'] as int? ?? 1,
      idType: json['id_type'] as String?,
      idNumber: json['id_number'] as String?,
      dob: json['dob'] != null ? DateTime.tryParse(json['dob'] as String) : null,
      address: json['address'] as String?,
      documentUrl: json['document_url'] as String?,
      faceImageUrl: json['face_image_url'] as String?,
      faceMatchScore: (json['face_match_score'] as num?)?.toDouble(),
      proofOfAddressUrl: json['proof_of_address_url'] as String?,
      declineReason: json['decline_reason'] as String?,
    );
  }
}
