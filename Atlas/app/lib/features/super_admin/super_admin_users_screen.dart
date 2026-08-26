import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/premium_widgets.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../models/admin_models.dart';
import '../../models/profile.dart';
import '../../services/admin_service.dart';
import '../../services/wallet_service.dart';
import '../shared/state_widgets.dart';

class SuperAdminUsersScreen extends StatefulWidget {
  const SuperAdminUsersScreen({super.key});

  @override
  State<SuperAdminUsersScreen> createState() => _SuperAdminUsersScreenState();
}

class _SuperAdminUsersScreenState extends State<SuperAdminUsersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Profile> _users = [];
  List<Profile> _admins = [];
  List<AdminInvitation> _invitations = [];
  bool _loading = true;
  String? _error;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    _load();
  }

  void _handleTabChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  AdminService get _admin => AdminService(Supabase.instance.client);

  Future<void> _load() async {
    final isInitial = _users.isEmpty && _admins.isEmpty && _invitations.isEmpty;
    if (isInitial) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final results = await Future.wait([
        _admin.fetchUsers(query: _searchController.text.trim()),
        _admin.fetchAdmins(),
        _admin.fetchAdminInvitations(),
      ]);
      if (mounted) {
        setState(() {
          _users = results[0] as List<Profile>;
          _admins = results[1] as List<Profile>;
          _invitations = results[2] as List<AdminInvitation>;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && isInitial) setState(() => _error = 'Failed to load users');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createAccount() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController(text: 'Atlas123!');
    var selectedRole = 'user';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Create User Account'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Create a new user account, admin, or super admin directly with instant wallet provisioning.',
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        hintText: 'John Doe',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email address',
                        hintText: 'user@company.com',
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Initial Password',
                        hintText: 'Atlas123!',
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      decoration: const InputDecoration(labelText: 'Account Role'),
                      items: const [
                        DropdownMenuItem(value: 'user', child: Text('Normal User')),
                        DropdownMenuItem(value: 'admin', child: Text('Admin')),
                        DropdownMenuItem(value: 'super_admin', child: Text('Super Admin')),
                      ],
                      onChanged: (val) => setDialogState(() => selectedRole = val!),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Create Account'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirm != true) return;

    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty) return;

    try {
      if (name.isNotEmpty) {
        await _admin.createUserAccount(
          email: email,
          fullName: name,
          role: selectedRole,
          password: password.isEmpty ? 'Atlas123!' : password,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('User account created for $email ($selectedRole)'),
              backgroundColor: AppColors.success,
            ),
          );
          _load();
        }
      } else {
        await _admin.inviteAdminUser(email: email, role: selectedRole);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Admin access granted or invitation sent to $email'),
              backgroundColor: AppColors.success,
            ),
          );
          _load();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mapRpcError(e))),
        );
      }
    }
  }

  Future<void> _deleteUser(Profile profile) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to permanently delete ${profile.fullName.isEmpty ? profile.email : profile.fullName} (${profile.email})?',
            ),
            const SizedBox(height: 12),
            Text(
              'Warning: This action will permanently remove their profile, wallet account, and linked data. This action cannot be undone.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.error),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _admin.deleteUserAccount(profileId: profile.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${profile.fullName.isEmpty ? profile.email : profile.fullName} account deleted'),
            backgroundColor: AppColors.primaryNavy,
          ),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mapRpcError(e))),
        );
      }
    }
  }

  Future<void> _changeRole(Profile profile) async {
    var selectedRole = profile.role.value;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Change role for ${profile.fullName}'),
              content: DropdownButtonFormField<String>(
                value: selectedRole,
                decoration: const InputDecoration(labelText: 'New role'),
                items: const [
                  DropdownMenuItem(value: 'user', child: Text('User')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  DropdownMenuItem(value: 'super_admin', child: Text('Super Admin')),
                ],
                onChanged: (val) => setDialogState(() => selectedRole = val!),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Update Role'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirm != true || selectedRole == profile.role.value) return;

    try {
      await _admin.manageUserRole(profileId: profile.id, role: selectedRole);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${profile.fullName} is now $selectedRole'),
            backgroundColor: AppColors.primaryNavy,
          ),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mapRpcError(e))),
        );
      }
    }
  }

  Future<void> _toggleFreeze(Profile profile) async {
    final isFrozen = profile.accountStatus == AccountStatus.frozen;
    final reasonController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isFrozen ? 'Unfreeze Account' : 'Freeze Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to ${isFrozen ? 'unfreeze' : 'freeze'} ${profile.fullName}?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'e.g. Compliance review or suspicious activity',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: isFrozen ? AppColors.success : AppColors.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(isFrozen ? 'Unfreeze' : 'Freeze Account'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _admin.setAccountStatus(
        profileId: profile.id,
        status: isFrozen ? 'verified' : 'frozen',
        reason: reasonController.text.trim().isEmpty ? null : reasonController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${profile.fullName} account status updated'),
            backgroundColor: AppColors.primaryNavy,
          ),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mapRpcError(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingInvites = _invitations.where((i) => i.acceptedAt == null).toList();

    return Padding(
      padding: context.adminPagePadding.copyWith(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ResponsivePageHeader(
            title: 'User Management',
            subtitle: 'Create accounts, manage roles, freeze users, and review admin invitations',
            actions: [
              FilledButton.icon(
                onPressed: _createAccount,
                icon: const Icon(Icons.person_add_rounded, size: 18),
                label: Text(context.isMobile ? 'Create' : 'Create Account'),
              ),
              IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'All Users (${_users.length})'),
              Tab(text: 'Admins (${_admins.length})'),
              Tab(text: 'Invites (${pendingInvites.length})'),
            ],
          ),
          const SizedBox(height: 16),
          if (_tabController.index == 0)
            context.isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Search by name or email...',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onSubmitted: (_) => _load(),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(onPressed: _load, child: const Text('Search')),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: 'Search by name or email...',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onSubmitted: (_) => _load(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _load,
                        child: const Text('Search'),
                      ),
                    ],
                  ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading && _users.isEmpty && _admins.isEmpty && _invitations.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _users.isEmpty && _admins.isEmpty && _invitations.isEmpty
                    ? ErrorBanner(message: _error!)
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _UserList(
                            users: _users,
                            onFreeze: _toggleFreeze,
                            onChangeRole: _changeRole,
                            onDelete: _deleteUser,
                            showRoleActions: true,
                          ),
                          _UserList(
                            users: _admins,
                            onFreeze: _toggleFreeze,
                            onChangeRole: _changeRole,
                            onDelete: _deleteUser,
                            showRoleActions: true,
                          ),
                          _InvitationList(invitations: pendingInvites),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

class _UserList extends StatelessWidget {
  const _UserList({
    required this.users,
    required this.onFreeze,
    required this.onChangeRole,
    required this.onDelete,
    required this.showRoleActions,
  });

  final List<Profile> users;
  final void Function(Profile) onFreeze;
  final void Function(Profile) onChangeRole;
  final void Function(Profile) onDelete;
  final bool showRoleActions;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return PremiumCard(
        padding: EdgeInsets.zero,
        child: EmptyState(
          icon: Icons.people_outline_rounded,
          title: 'No users found',
          message: 'No user profiles matched your query.',
        ),
      );
    }

    return PremiumCard(
      padding: EdgeInsets.zero,
      child: ListView.separated(
        itemCount: users.length,
        separatorBuilder: (context, index) => Divider(height: 1, color: AppColors.borderGrey.withValues(alpha: 0.6)),
        itemBuilder: (context, index) {
          final profile = users[index];
          final isFrozen = profile.accountStatus == AccountStatus.frozen;
          final isAdmin = profile.role != UserRole.user;
          final actionButtons = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (showRoleActions)
                OutlinedButton(
                  onPressed: () => onChangeRole(profile),
                  child: const Text('Change Role'),
                ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: isFrozen ? AppColors.success : AppColors.error,
                ),
                onPressed: () => onFreeze(profile),
                icon: Icon(isFrozen ? Icons.lock_open : Icons.ac_unit, size: 18),
                label: Text(isFrozen ? 'Unfreeze' : 'Freeze'),
              ),
              IconButton(
                style: IconButton.styleFrom(
                  foregroundColor: AppColors.error,
                ),
                onPressed: () => onDelete(profile),
                icon: const Icon(Icons.delete_outline, size: 20),
                tooltip: 'Delete User Account',
              ),
            ],
          );

          if (context.isCompact) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundColor: isFrozen
                            ? AppColors.error.withValues(alpha: 0.15)
                            : AppColors.secondaryBlue.withValues(alpha: 0.12),
                        child: Icon(
                          isFrozen ? Icons.ac_unit : (isAdmin ? Icons.admin_panel_settings : Icons.person),
                          color: isFrozen ? AppColors.error : AppColors.secondaryBlue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(profile.fullName.isEmpty ? 'Unnamed User' : profile.fullName),
                            Text(profile.email, style: Theme.of(context).textTheme.bodySmall),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                _Badge(label: profile.role.value, color: AppColors.primaryNavy),
                                _Badge(
                                  label: profile.accountStatus.label,
                                  color: isFrozen ? AppColors.error : AppColors.secondaryBlue,
                                ),
                                _Badge(
                                  label: 'KYC: ${profile.kycStatus.value}',
                                  color: AppColors.textGrey,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  actionButtons,
                ],
              ),
            );
          }

          return ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: isFrozen
                  ? AppColors.error.withValues(alpha: 0.15)
                  : AppColors.secondaryBlue.withValues(alpha: 0.12),
              child: Icon(
                isFrozen ? Icons.ac_unit : (isAdmin ? Icons.admin_panel_settings : Icons.person),
                color: isFrozen ? AppColors.error : AppColors.secondaryBlue,
              ),
            ),
            title: Text(profile.fullName.isEmpty ? 'Unnamed User' : profile.fullName),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile.email, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _Badge(label: profile.role.value, color: AppColors.primaryNavy),
                    _Badge(
                      label: profile.accountStatus.label,
                      color: isFrozen ? AppColors.error : AppColors.secondaryBlue,
                    ),
                    _Badge(
                      label: 'KYC: ${profile.kycStatus.value}',
                      color: AppColors.textGrey,
                    ),
                  ],
                ),
              ],
            ),
            trailing: actionButtons,
          );
        },
      ),
    );
  }
}

class _InvitationList extends StatelessWidget {
  const _InvitationList({required this.invitations});

  final List<AdminInvitation> invitations;

  @override
  Widget build(BuildContext context) {
    if (invitations.isEmpty) {
      return PremiumCard(
        padding: EdgeInsets.zero,
        child: EmptyState(
          icon: Icons.mail_outline_rounded,
          title: 'No pending invitations',
          message: 'Use "Create Admin" to invite new administrators by email.',
        ),
      );
    }

    return PremiumCard(
      padding: EdgeInsets.zero,
      child: ListView.separated(
        itemCount: invitations.length,
        separatorBuilder: (context, index) => Divider(height: 1, color: AppColors.borderGrey.withValues(alpha: 0.6)),
        itemBuilder: (context, index) {
          final invite = invitations[index];
          return ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: AppColors.accentGold.withValues(alpha: 0.2),
              child: const Icon(Icons.mail, color: AppColors.primaryNavy),
            ),
            title: Text(invite.email),
            subtitle: Text(
              'Role: ${invite.role} · Invited ${formatDate(invite.createdAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accentGold.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'AWAITING SIGNUP',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
      ),
    );
  }
}
