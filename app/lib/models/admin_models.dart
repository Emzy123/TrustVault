class AdminMetrics {
  const AdminMetrics({
    required this.totalUsers,
    required this.pendingKyc,
    required this.pendingFunding,
    required this.pendingWithdrawals,
    required this.openFlags,
    required this.dailyVolume,
  });

  final int totalUsers;
  final int pendingKyc;
  final int pendingFunding;
  final int pendingWithdrawals;
  final int openFlags;
  final double dailyVolume;

  factory AdminMetrics.fromJson(Map<String, dynamic> json) {
    return AdminMetrics(
      totalUsers: (json['total_users'] as num?)?.toInt() ?? 0,
      pendingKyc: (json['pending_kyc'] as num?)?.toInt() ?? 0,
      pendingFunding: (json['pending_funding'] as num?)?.toInt() ?? 0,
      pendingWithdrawals: (json['pending_withdrawals'] as num?)?.toInt() ?? 0,
      openFlags: (json['open_flags'] as num?)?.toInt() ?? 0,
      dailyVolume: (json['daily_volume'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class PlatformAnalytics {
  const PlatformAnalytics({
    required this.activeUsers,
    required this.activeUserRate,
    required this.totalFlags,
    required this.openFlags,
    required this.resolvedFlags,
    required this.flagRatePct,
    required this.pendingAdminInvites,
    required this.volume7d,
    required this.volume30d,
  });

  final int activeUsers;
  final double activeUserRate;
  final int totalFlags;
  final int openFlags;
  final int resolvedFlags;
  final double flagRatePct;
  final int pendingAdminInvites;
  final double volume7d;
  final double volume30d;

  factory PlatformAnalytics.fromJson(Map<String, dynamic> json) {
    return PlatformAnalytics(
      activeUsers: (json['active_users'] as num?)?.toInt() ?? 0,
      activeUserRate: (json['active_user_rate'] as num?)?.toDouble() ?? 0.0,
      totalFlags: (json['total_flags'] as num?)?.toInt() ?? 0,
      openFlags: (json['open_flags'] as num?)?.toInt() ?? 0,
      resolvedFlags: (json['resolved_flags'] as num?)?.toInt() ?? 0,
      flagRatePct: (json['flag_rate_pct'] as num?)?.toDouble() ?? 0.0,
      pendingAdminInvites: (json['pending_admin_invites'] as num?)?.toInt() ?? 0,
      volume7d: (json['volume_7d'] as num?)?.toDouble() ?? 0.0,
      volume30d: (json['volume_30d'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class AdminInvitation {
  const AdminInvitation({
    required this.id,
    required this.email,
    required this.role,
    required this.createdAt,
    this.acceptedAt,
  });

  final String id;
  final String email;
  final String role;
  final DateTime createdAt;
  final DateTime? acceptedAt;

  factory AdminInvitation.fromJson(Map<String, dynamic> json) {
    return AdminInvitation(
      id: json['id'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      acceptedAt: json['accepted_at'] != null
          ? DateTime.parse(json['accepted_at'] as String)
          : null,
    );
  }
}

class SuperAdminMetrics {
  const SuperAdminMetrics({
    required this.totalUsers,
    required this.pendingKyc,
    required this.pendingFunding,
    required this.pendingWithdrawals,
    required this.openFlags,
    required this.frozenAccounts,
    required this.totalAdmins,
    required this.totalVolume,
  });

  final int totalUsers;
  final int pendingKyc;
  final int pendingFunding;
  final int pendingWithdrawals;
  final int openFlags;
  final int frozenAccounts;
  final int totalAdmins;
  final double totalVolume;

  factory SuperAdminMetrics.fromJson(Map<String, dynamic> json) {
    return SuperAdminMetrics(
      totalUsers: (json['total_users'] as num?)?.toInt() ?? 0,
      pendingKyc: (json['pending_kyc'] as num?)?.toInt() ?? 0,
      pendingFunding: (json['pending_funding'] as num?)?.toInt() ?? 0,
      pendingWithdrawals: (json['pending_withdrawals'] as num?)?.toInt() ?? 0,
      openFlags: (json['open_flags'] as num?)?.toInt() ?? 0,
      frozenAccounts: (json['frozen_accounts'] as num?)?.toInt() ?? 0,
      totalAdmins: (json['total_admins'] as num?)?.toInt() ?? 0,
      totalVolume: (json['total_volume'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class TransactionFlag {
  const TransactionFlag({
    required this.id,
    required this.transactionId,
    required this.raisedBy,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.resolvedBy,
    this.resolvedAt,
    this.resolutionNote,
    this.transactionType,
    this.transactionAmount,
    this.userEmail,
  });

  final String id;
  final String transactionId;
  final String raisedBy;
  final String reason;
  final String status;
  final DateTime createdAt;
  final String? resolvedBy;
  final DateTime? resolvedAt;
  final String? resolutionNote;
  final String? transactionType;
  final double? transactionAmount;
  final String? userEmail;

  factory TransactionFlag.fromJson(Map<String, dynamic> json) {
    final tx = json['transactions'] as Map<String, dynamic>?;
    final profile = tx != null ? (tx['profiles'] as Map<String, dynamic>?) : null;

    return TransactionFlag(
      id: json['id'] as String,
      transactionId: json['transaction_id'] as String,
      raisedBy: json['raised_by'] as String,
      reason: json['reason'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      resolvedBy: json['resolved_by'] as String?,
      resolvedAt: json['resolved_at'] != null ? DateTime.parse(json['resolved_at'] as String) : null,
      resolutionNote: json['resolution_note'] as String?,
      transactionType: tx?['type'] as String?,
      transactionAmount: (tx?['amount'] as num?)?.toDouble(),
      userEmail: profile?['email'] as String?,
    );
  }
}

class AuditLogItem {
  const AuditLogItem({
    required this.id,
    required this.actorId,
    required this.action,
    this.targetId,
    required this.metadata,
    required this.createdAt,
    this.actorEmail,
    this.actorName,
  });

  final String id;
  final String actorId;
  final String action;
  final String? targetId;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final String? actorEmail;
  final String? actorName;

  factory AuditLogItem.fromJson(Map<String, dynamic> json) {
    final actor = json['profiles'] as Map<String, dynamic>?;

    return AuditLogItem(
      id: json['id'] as String,
      actorId: json['actor_id'] as String,
      action: json['action'] as String,
      targetId: json['target_id'] as String?,
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
      createdAt: DateTime.parse(json['created_at'] as String),
      actorEmail: actor?['email'] as String?,
      actorName: actor?['full_name'] as String?,
    );
  }
}
