import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/premium_widgets.dart';
import '../../services/email_service.dart';
import '../shared/state_widgets.dart';

class SignUpOtpScreen extends StatefulWidget {
  const SignUpOtpScreen({
    super.key,
    required this.email,
    required this.password,
    required this.fullName,
    required this.phone,
  });

  final String email;
  final String password;
  final String fullName;
  final String phone;

  @override
  State<SignUpOtpScreen> createState() => _SignUpOtpScreenState();
}

class _SignUpOtpScreenState extends State<SignUpOtpScreen> {
  final _otpController = TextEditingController();
  bool _isLoading = false;
  bool _isResending = false;
  String? _errorMessage;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() => _errorMessage = 'Enter the 6-digit code from your email');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final emailService = EmailService(Supabase.instance.client);
      await emailService.completeRegistration(
        email: widget.email,
        otp: otp,
        password: widget.password,
        fullName: widget.fullName,
        phone: widget.phone,
      );

      if (mounted) {
        _showWelcomeDialog();
      }
    } on AuthException catch (error) {
      setState(() => _errorMessage = error.message);
    } on PostgrestException catch (error) {
      setState(() => _errorMessage = error.message);
    } catch (_) {
      setState(() => _errorMessage = 'Verification failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    try {
      await EmailService(Supabase.instance.client).resendRegistrationOtp(widget.email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A new verification code has been sent.')),
        );
      }
    } on PostgrestException catch (error) {
      setState(() => _errorMessage = error.message);
    } catch (_) {
      setState(() => _errorMessage = 'Could not resend code. Try again shortly.');
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _fetchDemoCode() async {
    setState(() => _errorMessage = null);
    try {
      final code = await EmailService(Supabase.instance.client).getDemoOtp(widget.email);
      if (code != null && code.isNotEmpty) {
        setState(() => _otpController.text = code);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Demo Mode: Verification code [$code] autofilled.')),
          );
        }
      } else {
        setState(() => _errorMessage = 'No active demo code found. Click "Resend code".');
      }
    } catch (_) {
      setState(() => _errorMessage = 'Could not fetch demo verification code.');
    }
  }

  void _showWelcomeDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(32),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 52),
            ),
            const SizedBox(height: 24),
            Text(
              'Account created!',
              style: AppTypography.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Welcome to TrustVault, ${widget.fullName.split(' ').first}. '
              'We sent a welcome email and a reminder to complete identity verification.',
              style: AppTypography.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  context.go('/app/kyc');
                },
                child: const Text('Complete KYC Now'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  context.go('/app');
                },
                child: const Text('Go to dashboard'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageScaffold(
      title: 'Verify your email',
      subtitle: 'We sent a 6-digit code to ${widget.email}',
      heroTagline: 'One step away\nfrom your account.',
      footer: TextButton(
        onPressed: () => context.go('/signup'),
        child: const Text('Back to sign up'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _otpController,
            decoration: const InputDecoration(
              labelText: 'Verification code',
              hintText: '000000',
              prefixIcon: Icon(Icons.pin_outlined),
            ),
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              letterSpacing: 12,
              fontWeight: FontWeight.w700,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            onEditingComplete: _verify,
          ),
          const SizedBox(height: 8),
          Text(
            'Demo Mode: Click "Get Code" or use 123456',
            style: AppTypography.textTheme.bodySmall?.copyWith(fontSize: 11),
            textAlign: TextAlign.center,
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            ErrorBanner(message: _errorMessage!),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isLoading ? null : _verify,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
                  )
                : const Text('Verify & create account'),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: _isResending ? null : _resend,
                child: Text(_isResending ? 'Sending…' : 'Resend code'),
              ),
              TextButton.icon(
                icon: const Icon(Icons.key_outlined, size: 16),
                label: const Text('Get Code (Demo)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                onPressed: _fetchDemoCode,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
