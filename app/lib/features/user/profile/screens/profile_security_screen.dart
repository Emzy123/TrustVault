import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../shared/state_widgets.dart';

class ProfileSecurityScreen extends StatefulWidget {
  const ProfileSecurityScreen({super.key});

  @override
  State<ProfileSecurityScreen> createState() => _ProfileSecurityScreenState();
}

class _ProfileSecurityScreenState extends State<ProfileSecurityScreen> {
  bool _biometricsEnabled = true;
  bool _twoFactorEnabled = false;
  bool _emailAlertsEnabled = true;
  bool _changingPassword = false;

  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _passError;
  String? _passSuccess;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    if (_newPasswordController.text.length < 8) {
      setState(() => _passError = 'Password must be at least 8 characters');
      return;
    }
    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() => _passError = 'New passwords do not match');
      return;
    }

    setState(() {
      _changingPassword = true;
      _passError = null;
      _passSuccess = null;
    });

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _newPasswordController.text),
      );
      setState(() {
        _passSuccess = 'Password updated successfully!';
        _oldPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      });
    } catch (e) {
      setState(() => _passError = 'Failed to update password. Please try again.');
    } finally {
      setState(() => _changingPassword = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Security & Privacy'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/app/profile'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSecurityHealthCard(theme),
                const SizedBox(height: 24),
                _buildAuthenticationCard(theme),
                const SizedBox(height: 24),
                _buildPasswordChangeCard(theme),
                const SizedBox(height: 24),
                _buildActiveSessionsCard(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityHealthCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: CircularProgressIndicator(
                    value: 0.90,
                    strokeWidth: 8,
                    backgroundColor: AppColors.surfaceLight,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
                  ),
                ),
                const Text(
                  '90%',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Security Health: Strong', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  const Text(
                    'Your account is well protected. Enable Two-Factor Authentication for 100% score.',
                    style: TextStyle(color: AppColors.textGrey, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthenticationCard(ThemeData theme) {
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('Biometric Authentication'),
            subtitle: const Text('Use FaceID / TouchID for quick app unlock'),
            secondary: const Icon(Icons.fingerprint, color: AppColors.secondaryBlue),
            value: _biometricsEnabled,
            onChanged: (val) => setState(() => _biometricsEnabled = val),
          ),
          const Divider(height: 1),
          SwitchListTile(
            title: const Text('Two-Factor Authentication (2FA)'),
            subtitle: const Text('Require OTP code on sign in'),
            secondary: const Icon(Icons.security, color: AppColors.accentGold),
            value: _twoFactorEnabled,
            onChanged: (val) {
              setState(() => _twoFactorEnabled = val);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(val ? '2FA enabled' : '2FA disabled'),
                ),
              );
            },
          ),
          const Divider(height: 1),
          SwitchListTile(
            title: const Text('Security Alerts'),
            subtitle: const Text('Receive instant emails on new device logins'),
            secondary: const Icon(Icons.notifications_active_outlined, color: AppColors.secondaryBlue),
            value: _emailAlertsEnabled,
            onChanged: (val) => setState(() => _emailAlertsEnabled = val),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordChangeCard(ThemeData theme) {
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.lock_reset, color: AppColors.secondaryBlue),
        title: const Text('Change Account Password'),
        subtitle: const Text('Update your password regularly'),
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New Password'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Confirm New Password'),
                ),
                if (_passError != null) ...[
                  const SizedBox(height: 12),
                  ErrorBanner(message: _passError!),
                ],
                if (_passSuccess != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _passSuccess!,
                      style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _changingPassword ? null : _updatePassword,
                  child: _changingPassword
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
                        )
                      : const Text('Update Password'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSessionsCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Active Sessions', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.laptop, color: AppColors.secondaryBlue),
              title: const Text('Chrome on Linux (Current Session)'),
              subtitle: const Text('Active now • Lagos, Nigeria'),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'ONLINE',
                  style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
