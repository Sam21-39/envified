import 'dart:async';
import 'package:flutter/material.dart';

/// Gate for accessing the debug panel.
///
/// Provides authentication before allowing access to the [EnvDebugPanel].
/// The gate is automatically cleared when the app is backgrounded.
///
/// ```dart
/// // PIN only
/// EnvGate(pin: '1234')
/// ```
class EnvGate {
  final String? _pin;

  const EnvGate({
    String? pin,
  }) : _pin = pin;

  /// Authenticate using PIN.
  ///
  /// Returns `true` if authentication succeeds, `false` if it fails or is cancelled.
  Future<bool> authenticate(BuildContext context) async {
    // If no PIN is configured, allow access
    if (_pin == null) {
      return true;
    }

    if (context.mounted) {
      return _showPinDialog(context);
    }

    return false;
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
