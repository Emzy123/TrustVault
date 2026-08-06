import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../models/profile.dart';
import '../../services/auth_service.dart';

typedef ProfileBuilder = Widget Function(Profile profile);

class ProfileBootstrap extends StatefulWidget {
  const ProfileBootstrap({super.key, required this.builder});

  final ProfileBuilder builder;

  @override
  State<ProfileBootstrap> createState() => _ProfileBootstrapState();
}

class _ProfileBootstrapState extends State<ProfileBootstrap> {
  late final ProfileService _profileService;
  Profile? _profile;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _profileService = ProfileService(Supabase.instance.client);
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await _profileService.fetchCurrentProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loading = false;
        _error = profile == null ? 'Profile not found' : null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load profile';
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

    if (_error != null && _profile == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error ?? 'Something went wrong',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.error,
                    ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _load,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return widget.builder(_profile!);
  }
}
