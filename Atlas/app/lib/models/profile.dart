enum UserRole {
  user('user'),
  admin('admin'),
  superAdmin('super_admin');

  const UserRole(this.value);

  final String value;

  static UserRole fromString(String? raw) {
    return UserRole.values.firstWhere(
      (role) => role.value == raw,
      orElse: () => UserRole.user,
    );
  }

  String get homePath {
    switch (this) {
      case UserRole.user:
        return '/app';
      case UserRole.admin:
        return '/admin';
      case UserRole.superAdmin:
        return '/superadmin';
    }
  }
}

enum AccountStatus {
  unverified('unverified'),
  verified('verified'),
  active('active'),
  frozen('frozen');

  const AccountStatus(this.value);

  final String value;

  static AccountStatus fromString(String? raw) {
    return AccountStatus.values.firstWhere(
      (status) => status.value == raw,
      orElse: () => AccountStatus.unverified,
    );
  }

  String get label {
    switch (this) {
      case AccountStatus.unverified:
        return 'Unverified';
      case AccountStatus.verified:
        return 'Verified';
      case AccountStatus.active:
        return 'Active';
      case AccountStatus.frozen:
        return 'Frozen';
    }
  }
}

enum KycStatus {
  notSubmitted('not_submitted'),
  pending('pending'),
  approved('approved'),
  declined('declined');

  const KycStatus(this.value);

  final String value;

  static KycStatus fromString(String? raw) {
    return KycStatus.values.firstWhere(
      (status) => status.value == raw,
      orElse: () => KycStatus.notSubmitted,
    );
  }
}

class Profile {
  const Profile({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    required this.role,
    required this.accountStatus,
    required this.kycStatus,
    this.kycLevel = 0,
  });

  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final UserRole role;
  final AccountStatus accountStatus;
  final KycStatus kycStatus;

  /// 0 = newly registered (no verification yet). Levels 1–3 map to Tiers 1–3.
  final int kycLevel;

  bool get hasCompletedAnyKyc => kycLevel >= 1;

  /// Display badge: unverified users are not "Level 0" — they simply have no tier yet.
  String get levelBadgeTitle {
    switch (kycLevel) {
      case 1:
        return 'Level 1 · Tier 1';
      case 2:
        return 'Level 2 · Tier 2';
      case 3:
        return 'Level 3 · Tier 3';
      default:
        return 'Unverified';
    }
  }

  /// Realistic consumer-wallet daily transfer limits (USD).
  double get dailyTransferLimit {
    switch (kycLevel) {
      case 1:
        return 5000;
      case 2:
        return 20000;
      case 3:
        return 100000;
      default:
        return 0;
    }
  }

  String get formattedDailyLimit {
    switch (kycLevel) {
      case 1:
        return '\$5,000';
      case 2:
        return '\$20,000';
      case 3:
        return '\$100,000';
      default:
        return '\$0';
    }
  }

  String get tierLimitDescription {
    switch (kycLevel) {
      case 1:
        return 'Government ID verified · \$5,000 daily transfers';
      case 2:
        return 'Face match verified · \$20,000 daily transfers';
      case 3:
        return 'Address verified · \$100,000 daily transfers';
      default:
        return 'Complete identity verification to unlock transfers';
    }
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      role: UserRole.fromString(json['role'] as String?),
      accountStatus: AccountStatus.fromString(json['account_status'] as String?),
      kycStatus: KycStatus.fromString(json['kyc_status'] as String?),
      kycLevel: json['kyc_level'] as int? ?? 0,
    );
  }
}
