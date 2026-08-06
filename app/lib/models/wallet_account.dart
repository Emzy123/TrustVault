class WalletAccount {
  const WalletAccount({
    required this.id,
    required this.balance,
    required this.currency,
    required this.accountNumber,
  });

  final String id;
  final double balance;
  final String currency;
  final String accountNumber;

  factory WalletAccount.fromJson(Map<String, dynamic> json) {
    return WalletAccount(
      id: json['id'] as String,
      balance: (json['balance'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'USD',
      accountNumber: json['account_number'] as String,
    );
  }
}
