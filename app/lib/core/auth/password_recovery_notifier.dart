import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Tracks Supabase [AuthChangeEvent.passwordRecovery] so routing can show reset UI.
class PasswordRecoveryNotifier extends ChangeNotifier {
  PasswordRecoveryNotifier(Stream<AuthState> stream) {
    _subscription = stream.listen(_onAuthState);
  }

  late final StreamSubscription<AuthState> _subscription;
  bool _pending = false;

  bool get pending => _pending;

  void _onAuthState(AuthState state) {
    if (state.event == AuthChangeEvent.passwordRecovery) {
      if (!_pending) {
        _pending = true;
        notifyListeners();
      }
      return;
    }

    if (state.event == AuthChangeEvent.signedOut && _pending) {
      _pending = false;
      notifyListeners();
    }
  }

  void complete() {
    if (_pending) {
      _pending = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
