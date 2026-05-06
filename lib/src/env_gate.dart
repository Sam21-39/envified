import 'dart:async';

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

/// Controls access to the [EnvDebugPanel] via a PIN code, biometric
/// authentication, or both.
///
/// Pass an [EnvGate] instance to [EnvifiedOverlay.gate] to require
/// authentication before the debug panel is revealed. If both a [pin] and
/// [biometric] are enabled, the user may authenticate with either method.
///
/// This class is **internal** and is not exported from the public API.
///
/// Example (in [EnvifiedOverlay]):
/// ```dart
/// EnvifiedOverlay(
///   service: EnvConfigService.instance,
///   enabled: kDebugMode,
///   gate: EnvGate(pin: '1234'),            // PIN only
///   // gate: EnvGate(biometric: true),     // biometric only
///   // gate: EnvGate(pin: '1234', biometric: true), // either
///   child: child!,
/// )
/// ```
class EnvGate {
  final String? _pin;
  final bool _biometric;

  /// Creates an [EnvGate].
  ///
  /// At least one of [pin] or [biometric] should be non-null/true, otherwise
  /// [authenticate] always returns `true` immediately.
  ///
  /// - [pin]: A 4-digit PIN string. When supplied a dialog with 4 obscured
  ///   digit fields is shown as an [OverlayEntry] — no [Navigator] required,
  ///   so it works correctly when placed above [MaterialApp] in the tree.
  /// - [biometric]: When `true`, local biometric authentication (fingerprint,
  ///   Face ID, etc.) is attempted via the `local_auth` package.
  const EnvGate({String? pin, bool biometric = false})
      : _pin = pin,
        _biometric = biometric;

  /// Attempts authentication using the configured methods.
  ///
  /// Returns `true` if authentication succeeds, `false` otherwise.
  ///
  /// - When [biometric] is `true`, biometric auth is tried first via
  ///   [LocalAuthentication]. If the device does not support biometrics the
  ///   method falls through to PIN (if configured).
  /// - When [pin] is configured, a 4-field obscured PIN overlay is shown
  ///   directly into the nearest [Overlay] — no [Navigator] needed.
  /// - When neither is configured, returns `true` immediately.
  Future<bool> authenticate(BuildContext context) async {
    if (_biometric) {
      final bool bioResult = await _tryBiometric();
      if (bioResult) return true;
      // Fall through to PIN if biometric failed/unavailable.
    }

    if (_pin != null) {
      if (!context.mounted) return false;
      return _showPinOverlay(context, _pin!);
    }

    // No gate configured — always allow.
    return true;
  }

  /// Attempts biometric authentication.
  ///
  /// Returns `false` silently on any error (e.g. no hardware available).
  Future<bool> _tryBiometric() async {
    final LocalAuthentication auth = LocalAuthentication();
    try {
      final bool canAuthenticate =
          await auth.canCheckBiometrics || await auth.isDeviceSupported();
      if (!canAuthenticate) return false;

      return await auth.authenticate(
        localizedReason: 'Authenticate to open the envified debug panel.',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  /// Shows the PIN entry UI as a raw [OverlayEntry].
  ///
  /// This deliberately avoids [showDialog] / [Navigator] so that the gate
  /// works correctly when [EnvifiedOverlay] is placed inside
  /// [MaterialApp.builder] — a context that sits *above* the Navigator.
  Future<bool> _showPinOverlay(BuildContext context, String expected) async {
    final Completer<bool> completer = Completer<bool>();
    late final OverlayEntry entry;

    void complete(bool result) {
      if (!completer.isCompleted) {
        entry.remove();
        completer.complete(result);
      }
    }

    entry = OverlayEntry(
      builder: (_) => _PinOverlay(expected: expected, onResult: complete),
    );

    Overlay.of(context).insert(entry);
    return completer.future;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PIN Overlay — rendered directly into the Overlay stack, no Navigator needed.
// ─────────────────────────────────────────────────────────────────────────────

class _PinOverlay extends StatefulWidget {
  final String expected;
  final void Function(bool result) onResult;

  const _PinOverlay({required this.expected, required this.onResult});

  @override
  State<_PinOverlay> createState() => _PinOverlayState();
}

class _PinOverlayState extends State<_PinOverlay> {
  final List<TextEditingController> _controllers =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());

  @override
  void initState() {
    super.initState();
    // Auto-focus the first field after the frame is rendered.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onChanged(String value, int index) {
    if (value.isNotEmpty && index < 3) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  void _submit() {
    final String entered = _controllers.map((c) => c.text).join();
    widget.onResult(entered == widget.expected);
  }

  @override
  Widget build(BuildContext context) {
    // Wrap in Directionality + Material so widgets render correctly without
    // requiring a MaterialApp ancestor in the overlay layer.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // ── Scrim ────────────────────────────────────────────────────
            GestureDetector(
              onTap: () => widget.onResult(false),
              child: Container(color: Colors.black54),
            ),

            // ── Dialog card ──────────────────────────────────────────────
            Center(
              child: Container(
                width: 320,
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2E),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black45,
                      blurRadius: 32,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 20,
                          color: Colors.white70,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Enter PIN',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    const Text(
                      'Enter the 4-digit PIN to access\nthe debug panel.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.white54),
                    ),

                    const SizedBox(height: 24),

                    // PIN fields
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        4,
                        (index) {
                          return Container(
                            width: 52,
                            margin: const EdgeInsets.symmetric(horizontal: 5),
                            child: TextField(
                              controller: _controllers[index],
                              focusNode: _focusNodes[index],
                              obscureText: true,
                              textAlign: TextAlign.center,
                              maxLength: 1,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              decoration: InputDecoration(
                                counterText: '',
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                filled: true,
                                fillColor: const Color(0xFF2A2A3E),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF6C8EEF),
                                    width: 2,
                                  ),
                                ),
                              ),
                              onChanged: (v) => _onChanged(v, index),
                              onSubmitted: (_) {
                                if (index == 3) _submit();
                              },
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => widget.onResult(false),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white54,
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF6C8EEF),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Unlock'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
