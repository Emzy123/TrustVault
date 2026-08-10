import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/premium_widgets.dart';
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

  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _passError;
  String? _passSuccess;

  @override
  void dispose() {
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
    return ProfileSubScreenScaffold(
      title: 'Security & Privacy',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSecurityHealthCard(),
          const SizedBox(height: 16),
          _buildAuthenticationCard(),
          const SizedBox(height: 16),
          _buildPasswordChangeCard(),
          const SizedBox(height: 16),
          _buildActiveSessionsCard(),
        ],
      ),
    );
  }

  Widget _buildSecurityHealthCard() {
    return PremiumCard(
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
                  backgroundColor: AppColors.neutralLightGrey,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
                ),
              ),
              Text('90%', style: AppTypography.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Security Health: Strong', style: AppTypography.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Your account is well protected. Enable Two-Factor Authentication for 100% score.',
                  style: AppTypography.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthenticationCard() {
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _buildSwitchTile(
            title: 'Biometric Authentication',
            subtitle: 'Use FaceID / TouchID for quick app unlock',
            icon: Icons.fingerprint_rounded,
            color: AppColors.secondaryBlue,
            value: _biometricsEnabled,
            onChanged: (val) => setState(() => _biometricsEnabled = val),
          ),
          const Divider(height: 1, indent: 56),
          _buildSwitchTile(
            title: 'Two-Factor Authentication (2FA)',
            subtitle: 'Require OTP code on sign in',
            icon: Icons.security_rounded,
            color: AppColors.accentGold,
            value: _twoFactorEnabled,
            onChanged: (val) {
              setState(() => _twoFactorEnabled = val);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(val ? '2FA enabled' : '2FA disabled')),
              );
            },
          ),
          const Divider(height: 1, indent: 56),
          _buildSwitchTile(
            title: 'Security Alerts',
            subtitle: 'Receive instant emails on new device logins',
            icon: Icons.notifications_active_outlined,
            color: AppColors.secondaryBlue,
            value: _emailAlertsEnabled,
            onChanged: (val) => setState(() => _emailAlertsEnabled = val),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      title: Text(title, style: AppTypography.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: AppTypography.textTheme.bodySmall),
      secondary: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildPasswordChangeCard() {
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.secondaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.lock_reset_rounded, color: AppColors.secondaryBlue),
          ),
          title: Text('Change Account Password', style: AppTypography.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          subtitle: Text('Update your password regularly', style: AppTypography.textTheme.bodySmall),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
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
                        color: AppColors.success.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
                      ),
                      child: Text(_passSuccess!, style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w600)),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
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
      ),
    );
  }

  Widget _buildActiveSessionsCard() {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Active Sessions', style: AppTypography.textTheme.titleMedium),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.secondaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.laptop_mac_rounded, color: AppColors.secondaryBlue),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Chrome on Linux (Current Session)', style: AppTypography.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    Text('Active now · Lagos, Nigeria', style: AppTypography.textTheme.bodySmall),
                  ],
                ),
              ),
              StatusPill(label: 'ONLINE', color: AppColors.success),
            ],
          ),
        ],
      ),
    );
  }
}
