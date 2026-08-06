import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../services/email_service.dart';

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
      await EmailService(Supabase.instance.client)
          .resendRegistrationOtp(widget.email);
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.all(28),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: AppColors.success, size: 48),
            ),
            const SizedBox(height: 20),
            Text(
              'Account created!',
              style: Theme.of(dialogContext).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryNavy,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Welcome to TrustVault, ${widget.fullName.split(' ').first}. '
              'We sent a welcome email and a reminder to complete identity verification.',
              style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                    color: AppColors.textGrey,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryNavy),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  context.go('/onboarding');
                },
                child: const Text('Start Onboarding Tour'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  context.go('/app/kyc');
                },
                child: const Text('Complete KYC Now'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: Image.asset('assets/images/logo.png', height: 64)),
                const SizedBox(height: 16),
                Text(
                  'Verify your email',
                  style: theme.textTheme.displayMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'We sent a 6-digit code to\n${widget.email}',
                  style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textGrey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
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
                            fontSize: 24,
                            letterSpacing: 8,
                            fontWeight: FontWeight.bold,
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
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textGrey,
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage!,
                            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.error),
                          ),
                        ],
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _verify,
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.white,
                                  ),
                                )
                              : const Text('Verify & create account'),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: _isResending ? null : _resend,
                              child: _isResending
                                  ? const Text('Sending…')
                                  : const Text('Resend code'),
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.key_outlined, size: 16),
                              label: const Text('Get Code (Demo Mode)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              onPressed: _fetchDemoCode,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/signup'),
                  child: const Text('Back to sign up'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
