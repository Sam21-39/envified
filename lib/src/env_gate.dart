import 'dart:async';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';

/// Gate for accessing the debug panel — PIN, biometric, or both.
///
/// Provides authentication before allowing access to the [EnvDebugPanel].
/// The gate is automatically cleared when the app is backgrounded.
///
/// ```dart
/// // PIN only
/// EnvGate(pin: '1234')
///
/// // Biometric only
/// EnvGate(biometric: true)
///
/// // Either method works
/// EnvGate(pin: '1234', biometric: true)
/// ```
class EnvGate {
  final String? _pin;
  final bool _biometric;

  const EnvGate({
    String? pin,
    bool biometric = false,
  })  : _pin = pin,
        _biometric = biometric;

  /// Authenticate using PIN or biometric.
  ///
  /// Returns `true` if authentication succeeds, `false` if it fails or is cancelled.
  Future<bool> authenticate(BuildContext context) async {
    // If neither PIN nor biometric is configured, allow access
    if (_pin == null && !_biometric) {
      return true;
    }

    // Try biometric first if enabled
    if (_biometric) {
      final authenticated = await _authenticateBiometric();
      if (authenticated) return true;
    }

    // Fall back to PIN if biometric failed or not enabled
    if (_pin != null) {
      if (context.mounted) {
        return _showPinDialog(context);
      }
    }

    return false;
  }

  /// Authenticate using device biometrics (Face ID, fingerprint).
  Future<bool> _authenticateBiometric() async {
    try {
      final localAuth = LocalAuthentication();

      // Check if device supports biometric
      final canAuthenticateWithBiometrics = await localAuth.canCheckBiometrics;
      final canAuthenticate =
          canAuthenticateWithBiometrics || await localAuth.isDeviceSupported();

      if (!canAuthenticate) {
        return false;
      }

      // Attempt biometric authentication
      // Using the new API (local_auth >= 2.2.0)
      final isAuthenticated = await localAuth.authenticate(
        localizedReason: 'Authenticate to access envified debug panel',
        authMessages: const <AuthMessages>[
          AndroidAuthMessages(
            signInTitle: 'Unlock Debug Panel',
            cancelButton: 'Cancel',
          ),
        ],
        persistAcrossBackgrounding: true,
      );

      return isAuthenticated;
    } catch (e) {
      // Biometric failed or not available
      return false;
    }
  }

  /// Show PIN entry dialog using Overlay to avoid Navigator dependency.
  Future<bool> _showPinDialog(BuildContext context) async {
    final completer = Completer<bool>();
    final pinController = TextEditingController();
    final pinFocusNode = FocusNode();

    late OverlayEntry entry;

    void close(bool result) {
      if (!completer.isCompleted) {
        entry.remove();
        completer.complete(result);
      }
    }

    entry = OverlayEntry(
      builder: (context) => Material(
        color: Colors.black54,
        child: Center(
          child: AlertDialog(
            title: const Text('Enter PIN'),
            content: TextField(
              controller: pinController,
              focusNode: pinFocusNode,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                hintText: '••••',
                border: OutlineInputBorder(),
                counterText: '',
              ),
              onSubmitted: (_) {
                close(pinController.text == _pin);
              },
            ),
            actions: [
              TextButton(
                onPressed: () => close(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  close(pinController.text == _pin);
                },
                child: const Text('Submit'),
              ),
            ],
          ),
        ),
      ),
    );

    Overlay.of(context).insert(entry);
    return completer.future;
  }
}
