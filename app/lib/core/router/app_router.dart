import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/admin/admin_dashboard_screen.dart';
import '../../features/admin/admin_flags_screen.dart';
import '../../features/admin/admin_funding_queue_screen.dart';
import '../../features/admin/admin_kyc_queue_screen.dart';
import '../../features/admin/admin_shell.dart';
import '../../features/admin/admin_transactions_screen.dart';
import '../../features/shared/withdrawals_review_screen.dart';
import '../../features/auth/forgot_password_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/reset_password_screen.dart';
import '../../features/auth/signup_otp_screen.dart';
import '../../features/auth/signup_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/super_admin/super_admin_audit_log_screen.dart';
import '../../features/super_admin/super_admin_dashboard_screen.dart';
import '../../features/super_admin/super_admin_flags_screen.dart';
import '../../features/super_admin/super_admin_shell.dart';
import '../../features/super_admin/super_admin_users_screen.dart';
import '../../features/super_admin/super_admin_withdrawals_screen.dart';
import '../../features/user/funding/funding_request_screen.dart';
import '../../features/user/history/transaction_history_screen.dart';
import '../../features/user/kyc/kyc_screens.dart';
import '../../features/user/profile/profile_screen.dart';
import '../../features/user/profile/screens/profile_identity_screen.dart';
import '../../features/user/profile/screens/profile_limits_screen.dart';
import '../../features/user/profile/screens/profile_security_screen.dart';
import '../../features/user/profile/screens/profile_statements_screen.dart';
import '../../features/user/profile/screens/profile_support_screen.dart';
import '../../features/user/transfer/transfer_screen.dart';
import '../../features/user/user_dashboard_screen.dart';
import '../../features/user/user_shell.dart';
import '../../features/user/user_wallet_scope.dart';
import '../../features/user/withdraw/withdraw_screen.dart';
import '../../models/profile.dart';
import '../../models/wallet_models.dart';
import '../../services/auth_service.dart';
import '../../services/wallet_service.dart';
import '../auth/password_recovery_notifier.dart';
import '../onboarding/onboarding_prefs.dart';

class AppRouter {
  AppRouter({
    required AuthService authService,
    required ProfileService profileService,
  })  : _authService = authService,
        _profileService = profileService {
    _authRefresh = _AuthRefreshListenable(_authService.authStateChanges);
    _recoveryNotifier = PasswordRecoveryNotifier(_authService.authStateChanges);
  }

  final AuthService _authService;
  final ProfileService _profileService;
  late final _AuthRefreshListenable _authRefresh;
  late final PasswordRecoveryNotifier _recoveryNotifier;

  late final GoRouter router = GoRouter(
    initialLocation: '/onboarding',
    refreshListenable: Listenable.merge([_authRefresh, _recoveryNotifier]),
    redirect: _redirect,
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => ResetPasswordScreen(
          onComplete: _recoveryNotifier.complete,
        ),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const LoginScreen(),
        routes: [
          GoRoute(
            path: 'signup',
            builder: (context, state) => const SignUpScreen(),
            routes: [
              GoRoute(
                path: 'verify',
                builder: (context, state) {
                  final extra = state.extra;
                  if (extra is! Map<String, String>) {
                    return const SignUpScreen();
                  }
                  return SignUpOtpScreen(
                    email: extra['email'] ?? '',
                    password: extra['password'] ?? '',
                    fullName: extra['fullName'] ?? '',
                    phone: extra['phone'] ?? '',
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: 'forgot-password',
            builder: (context, state) {
              final email = state.uri.queryParameters['email'] ?? '';
              return ForgotPasswordScreen(initialEmail: email);
            },
          ),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) => UserShell(child: child),
        routes: [
          GoRoute(
            path: '/app',
            builder: (context, state) => UserWalletScope(
              builder: (context, profile, account, available, loading, error, refresh) {
                return UserDashboardScreen(
                  profile: profile,
                  account: account,
                  availableBalance: available,
                  onRefresh: refresh,
                );
              },
            ),
            routes: [
              GoRoute(
                path: 'kyc/pending',
                builder: (context, state) => UserWalletScope(
                  builder: (context, profile, account, available, loading, error, refresh) {
                    return KycPendingScreen(profile: profile);
                  },
                ),
              ),
              GoRoute(
                path: 'kyc',
                builder: (context, state) => UserWalletScope(
                  builder: (context, profile, account, available, loading, error, refresh) {
                    return KycFormScreen(profile: profile);
                  },
                ),
              ),
              GoRoute(
                path: 'funding',
                builder: (context, state) => UserWalletScope(
                  builder: (context, profile, account, available, loading, error, refresh) {
                    return FundingRequestScreen(profile: profile);
                  },
                ),
              ),
              GoRoute(
                path: 'transfer',
                builder: (context, state) => UserWalletScope(
                  builder: (context, profile, account, available, loading, error, refresh) {
                    if (account == null) {
                      return const Center(child: Text('Wallet not available'));
                    }
                    return TransferScreen(
                      profile: profile,
                      account: account,
                      availableBalance: available,
                    );
                  },
                ),
              ),
              GoRoute(
                path: 'withdraw',
                builder: (context, state) => UserWalletScope(
                  builder: (context, profile, account, available, loading, error, refresh) {
                    if (account == null) {
                      return const Center(child: Text('Wallet not available'));
                    }
                    return WithdrawScreen(
                      profile: profile,
                      account: account,
                      availableBalance: available,
                    );
                  },
                ),
              ),
              GoRoute(
                path: 'history',
                builder: (context, state) => const _HistoryRoute(),
              ),
              GoRoute(
                path: 'history/:id',
                builder: (context, state) => _TransactionDetailRoute(
                  transactionId: state.pathParameters['id']!,
                ),
              ),
              GoRoute(
                path: 'profile',
                builder: (context, state) => UserWalletScope(
                  builder: (context, profile, account, available, loading, error, refresh) {
                    return ProfileScreen(
                      profile: profile,
                      accountNumber: account?.accountNumber,
                    );
                  },
                ),
                routes: [
                  GoRoute(
                    path: 'identity',
                    builder: (context, state) => UserWalletScope(
                      builder: (context, profile, account, available, loading, error, refresh) {
                        return ProfileIdentityScreen(profile: profile);
                      },
                    ),
                  ),
                  GoRoute(
                    path: 'limits',
                    builder: (context, state) => UserWalletScope(
                      builder: (context, profile, account, available, loading, error, refresh) {
                        return ProfileLimitsScreen(profile: profile);
                      },
                    ),
                  ),
                  GoRoute(
                    path: 'security',
                    builder: (context, state) => const ProfileSecurityScreen(),
                  ),
                  GoRoute(
                    path: 'statements',
                    builder: (context, state) => const ProfileStatementsScreen(),
                  ),
                  GoRoute(
                    path: 'support',
                    builder: (context, state) => const ProfileSupportScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: '/admin',
            builder: (context, state) => const AdminDashboardScreen(),
            routes: [
              GoRoute(
                path: 'kyc',
                builder: (context, state) => const AdminKycQueueScreen(),
              ),
              GoRoute(
                path: 'funding',
                builder: (context, state) => const AdminFundingQueueScreen(),
              ),
              GoRoute(
                path: 'withdrawals',
                builder: (context, state) => const WithdrawalsReviewScreen(
                  title: 'Withdrawals Queue',
                  subtitle: 'Review and release pending user withdrawal requests',
                ),
              ),
              GoRoute(
                path: 'transactions',
                builder: (context, state) => const AdminTransactionsScreen(),
              ),
              GoRoute(
                path: 'flags',
                builder: (context, state) => const AdminFlagsScreen(),
              ),
            ],
          ),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) => SuperAdminShell(child: child),
        routes: [
          GoRoute(
            path: '/superadmin',
            builder: (context, state) => const SuperAdminDashboardScreen(),
            routes: [
              GoRoute(
                path: 'kyc',
                builder: (context, state) => const AdminKycQueueScreen(),
              ),
              GoRoute(
                path: 'funding',
                builder: (context, state) => const AdminFundingQueueScreen(),
              ),
              GoRoute(
                path: 'transactions',
                builder: (context, state) => const AdminTransactionsScreen(),
              ),
              GoRoute(
                path: 'withdrawals',
                builder: (context, state) => const SuperAdminWithdrawalsScreen(),
              ),
              GoRoute(
                path: 'flags',
                builder: (context, state) => const SuperAdminFlagsScreen(),
              ),
              GoRoute(
                path: 'users',
                builder: (context, state) => const SuperAdminUsersScreen(),
              ),
              GoRoute(
                path: 'audit',
                builder: (context, state) => const SuperAdminAuditLogScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  Future<String?> _redirect(BuildContext context, GoRouterState state) async {
    final isLoggedIn = _authService.currentUser != null;
    final location = state.matchedLocation;
    final isOnboarding = location == '/onboarding';
    final isResetPassword = location == '/reset-password';
    final isAuthRoute = location == '/' ||
        location == '/signup' ||
        location == '/signup/verify' ||
        location == '/forgot-password';

    if (_recoveryNotifier.pending) {
      return isResetPassword ? null : '/reset-password';
    }

    if (isResetPassword) {
      if (isLoggedIn) {
        final profile = await _profileService.fetchCurrentProfile();
        return profile?.role.homePath ?? '/app';
      }
      return '/forgot-password';
    }

    if (isOnboarding) {
      if (isLoggedIn) {
        final profile = await _profileService.fetchCurrentProfile();
        return profile?.role.homePath ?? '/app';
      }
      final onboardingDone = await OnboardingPrefs.hasCompleted();
      if (onboardingDone) return '/';
      return null;
    }

    if (!isLoggedIn) {
      final onboardingDone = await OnboardingPrefs.hasCompleted();
      if (!onboardingDone) {
        return '/onboarding';
      }
      return isAuthRoute ? null : '/';
    }

    if (isAuthRoute) {
      final profile = await _profileService.fetchCurrentProfile();
      return profile?.role.homePath ?? '/app';
    }

    final profile = await _profileService.fetchCurrentProfile();
    if (profile == null) {
      await _authService.signOut();
      return '/';
    }

    final roleHome = profile.role.homePath;

    if (location.startsWith('/app') && profile.role != UserRole.user) {
      return roleHome;
    }
    if (location.startsWith('/admin') && profile.role != UserRole.admin) {
      return roleHome;
    }
    if (location.startsWith('/superadmin') &&
        profile.role != UserRole.superAdmin) {
      return roleHome;
    }

    return null;
  }
}

class _HistoryRoute extends StatefulWidget {
  const _HistoryRoute();

  @override
  State<_HistoryRoute> createState() => _HistoryRouteState();
}

class _HistoryRouteState extends State<_HistoryRoute> {
  List<WalletTransaction> _transactions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final wallet = WalletService(Supabase.instance.client);
      final account = await wallet.fetchOwnAccount();
      if (account == null) {
        setState(() {
          _loading = false;
          _error = 'Wallet not found';
        });
        return;
      }

      final items = await wallet.fetchRecentTransactions(accountId: account.id, limit: 50);
      setState(() {
        _transactions = items;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _error = 'Failed to load transactions';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return TransactionHistoryScreen(
      transactions: _transactions,
      loading: _loading,
      error: _error,
      onRefresh: _load,
    );
  }
}

class _TransactionDetailRoute extends StatefulWidget {
  const _TransactionDetailRoute({required this.transactionId});

  final String transactionId;

  @override
  State<_TransactionDetailRoute> createState() => _TransactionDetailRouteState();
}

class _TransactionDetailRouteState extends State<_TransactionDetailRoute> {
  WalletTransaction? _transaction;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final wallet = WalletService(Supabase.instance.client);
      final account = await wallet.fetchOwnAccount();
      if (account == null) {
        setState(() {
          _loading = false;
          _error = 'Wallet not found';
        });
        return;
      }

      final tx = await wallet.fetchTransaction(widget.transactionId, account.id);
      setState(() {
        _transaction = tx;
        _loading = false;
        _error = tx == null ? 'Transaction not found' : null;
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _error = 'Failed to load transaction';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return TransactionDetailScreen(
      transaction: _transaction,
      loading: _loading,
      error: _error,
    );
  }
}

class _AuthRefreshListenable extends ChangeNotifier {
  _AuthRefreshListenable(Stream<AuthState> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
