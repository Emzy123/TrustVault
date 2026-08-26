import '../models/profile.dart';

/// Determines which wallet actions the user can perform (Blueprint §4.2).
class WalletEligibility {
  const WalletEligibility({required this.profile});

  final Profile profile;

  bool get isFrozen => profile.accountStatus == AccountStatus.frozen;

  bool get canSubmitKyc =>
      !isFrozen &&
      (profile.kycStatus == KycStatus.notSubmitted ||
          profile.kycStatus == KycStatus.declined);

  bool get canRequestFunding =>
      !isFrozen &&
      profile.kycStatus == KycStatus.approved &&
      (profile.accountStatus == AccountStatus.verified ||
          profile.accountStatus == AccountStatus.active);

  bool get canTransfer =>
      !isFrozen && profile.accountStatus == AccountStatus.active;

  bool get canWithdraw =>
      !isFrozen && profile.accountStatus == AccountStatus.active;

  String get fundingLockReason {
    if (isFrozen) return 'Your account is frozen';
    if (profile.kycStatus == KycStatus.notSubmitted) {
      return 'Complete identity verification to unlock';
    }
    if (profile.kycStatus == KycStatus.pending) {
      return 'Verification is under review';
    }
    if (profile.kycStatus == KycStatus.declined) {
      return 'Resubmit verification to unlock';
    }
    return '';
  }

  String get transferLockReason {
    if (isFrozen) return 'Your account is frozen';
    if (profile.kycStatus != KycStatus.approved) {
      return 'Complete verification to unlock transfers';
    }
    if (profile.accountStatus != AccountStatus.active) {
      return 'Fund your wallet to unlock transfers';
    }
    return '';
  }

  String get withdrawLockReason => transferLockReason;
}
