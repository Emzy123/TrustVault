import '../shared/withdrawals_review_screen.dart';

class SuperAdminWithdrawalsScreen extends WithdrawalsReviewScreen {
  const SuperAdminWithdrawalsScreen({super.key})
      : super(
          title: 'Withdrawals Review Queue',
          subtitle: 'Transparent Super Admin review of pending user withdrawal requests',
        );
}
