import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/profile.dart';
import '../../models/wallet_account.dart';
import '../../services/auth_service.dart';
import '../../services/wallet_service.dart';

/// Loads profile + wallet account together for user screens.
class UserWalletScope extends StatefulWidget {
  const UserWalletScope({super.key, required this.builder});

  final Widget Function(
    BuildContext context,
    Profile profile,
    WalletAccount? account,
    double availableBalance,
    bool loading,
    String? error,
    Future<void> Function() refresh,
  ) builder;

  @override
  State<UserWalletScope> createState() => _UserWalletScopeState();
}

class _UserWalletScopeState extends State<UserWalletScope> {
  late final ProfileService _profileService;
  late final WalletService _walletService;

  Profile? _profile;
  WalletAccount? _account;
  double _availableBalance = 0;
  bool _loading = true;
  String? _error;

  RealtimeChannel? _profilesChannel;
  RealtimeChannel? _accountsChannel;
  RealtimeChannel? _transactionsChannel;

  @override
  void initState() {
    super.initState();
    final client = Supabase.instance.client;
    _profileService = ProfileService(client);
    _walletService = WalletService(client);
    _load();
    _subscribeRealtime();
  }

  void _subscribeRealtime() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    _profilesChannel = Supabase.instance.client
        .channel('public:profiles:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
          callback: (_) {
            if (mounted) _load();
          },
        )
        .subscribe();

    _accountsChannel = Supabase.instance.client
        .channel('public:accounts:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'accounts',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'profile_id',
            value: userId,
          ),
          callback: (_) {
            if (mounted) _load();
          },
        )
        .subscribe();

    _transactionsChannel = Supabase.instance.client
        .channel('public:transactions:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'transactions',
          callback: (_) {
            if (mounted) _load();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _profilesChannel?.unsubscribe();
    _accountsChannel?.unsubscribe();
    _transactionsChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final profile = await _profileService.fetchCurrentProfile();
      WalletAccount? account;
      var available = 0.0;

      if (profile != null) {
        account = await _walletService.fetchOwnAccount();
        if (account != null) {
          available = await _walletService.fetchAvailableBalance(account.id);
        }
      }

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _account = account;
        _availableBalance = available;
        _loading = false;
        _error = profile == null ? 'Profile not found' : null;
      });
    } catch (e, st) {
      debugPrint('UserWalletScope load error: $e\n$st');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = mapRpcError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _profile == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _profile == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.orange),
                const SizedBox(height: 16),
                Text(
                  _error ?? 'Unable to sync profile',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton(
                      onPressed: () => Supabase.instance.client.auth.signOut(),
                      child: const Text('Sign out'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return widget.builder(
      context,
      _profile!,
      _account,
      _availableBalance,
      _loading,
      _error,
      _load,
    );
  }
}
