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

  Future<void> _pickCountry() async {
    final selected = await showDialog<CountryDial>(
      context: context,
      builder: (context) => _CountryPickerDialog(selected: _country),
    );
    if (selected != null && mounted) {
      setState(() => _country = selected);
    }
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
            InkWell(
              onTap: _pickCountry,
              borderRadius: BorderRadius.circular(4),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Country',
                  prefixIcon: Icon(Icons.public_outlined),
                  suffixIcon: Icon(Icons.arrow_drop_down),
                ),
                child: Text(
                  _country.label,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
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

class _CountryPickerDialog extends StatefulWidget {
  const _CountryPickerDialog({required this.selected});

  final CountryDial selected;

  @override
  State<_CountryPickerDialog> createState() => _CountryPickerDialogState();
}

class _CountryPickerDialogState extends State<_CountryPickerDialog> {
  late final TextEditingController _searchController;
  late List<CountryDial> _filtered;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _filtered = kRegistrationCountries;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = kRegistrationCountries;
      } else {
        _filtered = kRegistrationCountries
            .where(
              (c) =>
                  c.name.toLowerCase().contains(q) ||
                  c.dialCode.contains(q) ||
                  c.iso2.toLowerCase().contains(q),
            )
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Select country',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search by name or code',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
                onChanged: _onSearch,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _filtered.isEmpty
                  ? const Center(child: Text('No countries match'))
                  : ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        final country = _filtered[index];
                        final isSelected = country.iso2 == widget.selected.iso2 &&
                            country.dialCode == widget.selected.dialCode;
                        return ListTile(
                          dense: true,
                          title: Text(country.name),
                          trailing: Text('+${country.dialCode}'),
                          selected: isSelected,
                          onTap: () => Navigator.of(context).pop(country),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
