import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/countries.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/premium_widgets.dart';
import '../../services/email_service.dart';
import '../shared/state_widgets.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  CountryDial _country = kRegistrationCountries.first;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await EmailService(Supabase.instance.client)
          .requestRegistrationOtp(_emailController.text.trim());

      if (mounted) {
        context.go(
          '/signup/verify',
          extra: {
            'email': _emailController.text.trim(),
            'password': _passwordController.text,
            'fullName': _fullNameController.text.trim(),
            'phone': _country.formatPhone(_phoneController.text.trim()),
          },
        );
      }
    } on PostgrestException catch (error) {
      setState(() => _errorMessage = error.message);
    } catch (_) {
      setState(() => _errorMessage = 'Sign up failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageScaffold(
      title: 'Create your account',
      subtitle: 'Start with a zero-balance wallet. We\'ll email a 6-digit code to verify your address.',
      heroTagline: 'Your wealth.\nProtected & connected.',
      footer: TextButton(
        onPressed: () => context.go('/'),
        child: const Text('Already have an account? Sign in'),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _fullNameController,
              decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) return 'Full name is required';
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<CountryDial>(
              value: _country,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Country',
                prefixIcon: Icon(Icons.public_outlined),
              ),
              items: [
                for (final country in kRegistrationCountries)
                  DropdownMenuItem(
                    value: country,
                    child: Text(country.label, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _country = value);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: 'Phone number',
                hintText: 'Local number without country code',
                prefixIcon: const Icon(Icons.phone_outlined),
                prefixText: '+${_country.dialCode} ',
              ),
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) => _country.validateNational(value),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.trim().isEmpty) return 'Email is required';
                if (!value.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              obscureText: true,
              validator: (value) {
                if (value == null || value.length < 8) {
                  return 'Password must be at least 8 characters';
                }
                return null;
              },
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              ErrorBanner(message: _errorMessage!),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              child: _isLoading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
                    )
                  : const Text('Send verification code'),
            ),
          ],
        ),
      ),
    );
  }
}
