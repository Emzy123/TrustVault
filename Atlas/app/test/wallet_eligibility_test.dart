import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/core/wallet_eligibility.dart';
import 'package:atlas/models/profile.dart';

void main() {
  group('WalletEligibility Tests', () {
    Profile makeProfile({
      AccountStatus accountStatus = AccountStatus.unverified,
      KycStatus kycStatus = KycStatus.notSubmitted,
    }) {
      return Profile(
        id: 'test-user-id',
        fullName: 'Test User',
        email: 'test@example.com',
        role: UserRole.user,
        accountStatus: accountStatus,
        kycStatus: kycStatus,
      );
    }

    test('Unverified profile cannot funding, transfer, or withdraw', () {
      final eligibility = WalletEligibility(
        profile: makeProfile(
          accountStatus: AccountStatus.unverified,
          kycStatus: KycStatus.notSubmitted,
        ),
      );

      expect(eligibility.isFrozen, isFalse);
      expect(eligibility.canSubmitKyc, isTrue);
      expect(eligibility.canRequestFunding, isFalse);
      expect(eligibility.canTransfer, isFalse);
      expect(eligibility.canWithdraw, isFalse);
      expect(eligibility.fundingLockReason, contains('Complete identity verification'));
    });

    test('Pending KYC profile cannot submit new KYC or request funding', () {
      final eligibility = WalletEligibility(
        profile: makeProfile(
          accountStatus: AccountStatus.unverified,
          kycStatus: KycStatus.pending,
        ),
      );

      expect(eligibility.canSubmitKyc, isFalse);
      expect(eligibility.canRequestFunding, isFalse);
      expect(eligibility.fundingLockReason, contains('under review'));
    });

    test('Verified zero-balance profile can request funding but not transfer or withdraw', () {
      final eligibility = WalletEligibility(
        profile: makeProfile(
          accountStatus: AccountStatus.verified,
          kycStatus: KycStatus.approved,
        ),
      );

      expect(eligibility.canSubmitKyc, isFalse);
      expect(eligibility.canRequestFunding, isTrue);
      expect(eligibility.canTransfer, isFalse);
      expect(eligibility.canWithdraw, isFalse);
      expect(eligibility.transferLockReason, contains('Fund your wallet'));
    });

    test('Active profile with balance can transfer and withdraw', () {
      final eligibility = WalletEligibility(
        profile: makeProfile(
          accountStatus: AccountStatus.active,
          kycStatus: KycStatus.approved,
        ),
      );

      expect(eligibility.canSubmitKyc, isFalse);
      expect(eligibility.canRequestFunding, isTrue);
      expect(eligibility.canTransfer, isTrue);
      expect(eligibility.canWithdraw, isTrue);
    });

    test('Frozen profile blocks all wallet actions regardless of KYC status', () {
      final eligibility = WalletEligibility(
        profile: makeProfile(
          accountStatus: AccountStatus.frozen,
          kycStatus: KycStatus.approved,
        ),
      );

      expect(eligibility.isFrozen, isTrue);
      expect(eligibility.canSubmitKyc, isFalse);
      expect(eligibility.canRequestFunding, isFalse);
      expect(eligibility.canTransfer, isFalse);
      expect(eligibility.canWithdraw, isFalse);
      expect(eligibility.fundingLockReason, contains('frozen'));
      expect(eligibility.transferLockReason, contains('frozen'));
    });
  });
}
