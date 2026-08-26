import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/core/formatters.dart';
import 'package:atlas/models/profile.dart';
import 'package:atlas/models/wallet_account.dart';
import 'package:atlas/models/wallet_models.dart';

void main() {
  group('Formatter Tests', () {
    test('formatNaira / formatCurrency formats positive numbers with comma separators', () {
      expect(formatCurrency(0), equals('\$0.00'));
      expect(formatCurrency(500), equals('\$500.00'));
      expect(formatCurrency(12500.5), equals('\$12,500.50'));
      expect(formatCurrency(1000000), equals('\$1,000,000.00'));
    });

    test('formatDate formats DateTime nicely', () {
      final date = DateTime(2026, 7, 24, 14, 30);
      expect(formatDate(date), contains('2026'));
      expect(formatShortDate(date), equals('Jul 24'));
    });

    test('formatAccountNumber formats 10-digit account numbers correctly', () {
      expect(formatAccountNumber('3081928471'), equals('3081 928 471'));
      expect(formatAccountNumber('2045839176'), equals('2045 839 176'));
      expect(formatAccountNumber(null), equals('—'));
      expect(formatAccountNumber('123'), equals('123'));
    });
  });

  group('Model Deserialization Tests', () {
    test('Profile.fromJson parses correctly', () {
      final json = {
        'id': 'p-123',
        'full_name': 'Jane Doe',
        'email': 'jane@example.com',
        'phone': '+2348012345678',
        'role': 'admin',
        'account_status': 'active',
        'kyc_status': 'approved',
      };

      final profile = Profile.fromJson(json);
      expect(profile.id, equals('p-123'));
      expect(profile.fullName, equals('Jane Doe'));
      expect(profile.email, equals('jane@example.com'));
      expect(profile.role, equals(UserRole.admin));
      expect(profile.accountStatus, equals(AccountStatus.active));
      expect(profile.kycStatus, equals(KycStatus.approved));
    });

    test('WalletAccount.fromJson parses correctly', () {
      final json = {
        'id': 'acc-789',
        'profile_id': 'p-123',
        'balance': 150000.75,
        'currency': 'NGN',
        'account_number': '3081928471',
        'is_system': false,
      };

      final account = WalletAccount.fromJson(json);
      expect(account.id, equals('acc-789'));
      expect(account.balance, equals(150000.75));
      expect(account.accountNumber, equals('3081928471'));
    });

    test('WalletTransaction.fromJson determines incoming vs outgoing correctly', () {
      final json = {
        'id': 'tx-001',
        'type': 'transfer',
        'amount': 2500.0,
        'status': 'completed',
        'created_at': '2026-07-24T10:00:00Z',
        'from_account_id': 'other-acc',
        'to_account_id': 'my-acc',
      };

      final tx = WalletTransaction.fromJson(json, ownAccountId: 'my-acc');
      expect(tx.id, equals('tx-001'));
      expect(tx.type, equals(TransactionType.transfer));
      expect(tx.isIncoming, isTrue);
      expect(tx.status, equals(TransactionStatus.completed));
    });
  });
}
