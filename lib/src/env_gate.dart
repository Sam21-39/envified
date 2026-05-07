import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
      builder: (context) => _PinOverlay(
        pinController: pinController,
        pinFocusNode: pinFocusNode,
        correctPin: _pin!,
        onClose: close,
      ),
    );

    Overlay.of(context).insert(entry);
    return completer.future;
  }
}

class _PinOverlay extends StatefulWidget {
  final TextEditingController pinController;
  final FocusNode pinFocusNode;
  final String correctPin;
  final ValueChanged<bool> onClose;

  const _PinOverlay({
    required this.pinController,
    required this.pinFocusNode,
    required this.correctPin,
    required this.onClose,
  });

  @override
  State<_PinOverlay> createState() => _PinOverlayState();
}

class _PinOverlayState extends State<_PinOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _blurAnim;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );

    _blurAnim = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOut,
      ),
    );

    _animController.forward();

    widget.pinController.addListener(_onPinChanged);

    // Ensure keyboard opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.pinFocusNode.requestFocus();
    });
  }

  void _onPinChanged() {
    setState(() {});
    if (widget.pinController.text.length == widget.correctPin.length) {
      _verify();
    }
  }

  @override
  void dispose() {
    widget.pinController.removeListener(_onPinChanged);
    _animController.dispose();
    super.dispose();
  }

  void _verify() {
    if (widget.pinController.text == widget.correctPin) {
      widget.onClose(true);
    } else {
      setState(() => _isError = true);
      HapticFeedback.vibrate();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _isError = false;
            widget.pinController.clear();
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Glass background
          GestureDetector(
            onTap: () => widget.onClose(false),
            child: AnimatedBuilder(
              animation: _blurAnim,
              builder: (context, child) => BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: _blurAnim.value,
                  sigmaY: _blurAnim.value,
                ),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),

          // Dialog content
          Center(
            child: ScaleTransition(
              scale: _scaleAnim,
              child: Container(
                width: 340,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1F2E),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_person_rounded,
                        color: Colors.blue,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 24),

                    const Text(
                      'Access Restricted',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter the secure PIN to continue',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Input Fields
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        _buildPinFields(),
                        // The actual TextField (invisible but interactive)
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: TextField(
                            controller: widget.pinController,
                            focusNode: widget.pinFocusNode,
                            autofocus: true,
                            showCursor: false,
                            cursorWidth: 0,
                            enableInteractiveSelection: false,
                            keyboardType: TextInputType.number,
                            maxLength: widget.correctPin.length,
                            style: const TextStyle(
                              color: Colors.transparent,
                              fontSize: 1, // Minimize visible text
                            ),
                            decoration: const InputDecoration(
                              counterText: '',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onSubmitted: (_) => _verify(),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Cancel button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () => widget.onClose(false),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinFields() {
    final length = widget.correctPin.length;
    final text = widget.pinController.text;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(length, (index) {
        final isFocused = text.length == index;
        final hasValue = text.length > index;
        final char = hasValue ? text[index] : '';

        return Container(
          width: 42,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _isError
                ? Colors.red.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isError
                  ? Colors.red
                  : isFocused
                      ? Colors.blue
                      : Colors.white.withValues(alpha: 0.1),
              width: isFocused ? 2 : 1.5,
            ),
            boxShadow: [
              if (isFocused && !_isError)
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.2),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: Text(
            char.isEmpty ? '' : '•', // Use dot for obscure or char for visible
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }),
    );
  }
}
