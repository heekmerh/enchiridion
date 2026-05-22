import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VerificationCodeScreen extends StatefulWidget {
  final String email;
  final VoidCallback onVerificationSuccess;

  const VerificationCodeScreen({
    super.key,
    required this.email,
    required this.onVerificationSuccess,
  });

  @override
  State<VerificationCodeScreen> createState() => _VerificationCodeScreenState();
}

class _VerificationCodeScreenState extends State<VerificationCodeScreen> {
  // 6 individual digit fields
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  late DateTime _codeExpiryTime;
  late Duration _remainingTime;
  bool _isCountingDown = true;
  int _secondsRemaining = 600; // 10 minutes
  bool _isLoading = false;
  String? _errorMessage;
  bool _canResend = false;
  int _resendCooldownSeconds = 0;

  @override
  void initState() {
    super.initState();
    _codeExpiryTime = DateTime.now().add(const Duration(minutes: 10));
    _startCountdown();
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        _remainingTime = _codeExpiryTime.difference(DateTime.now());
        if (_remainingTime.isNegative) {
          setState(() {
            _isCountingDown = false;
          });
        } else {
          setState(() {
            _secondsRemaining = _remainingTime.inSeconds;
          });
          _startCountdown();
        }
      }
    });
  }

  void _startResendCooldown() {
    setState(() {
      _canResend = false;
      _resendCooldownSeconds = 60;
    });

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        if (_resendCooldownSeconds > 0) {
          setState(() => _resendCooldownSeconds--);
          _startResendCooldown();
        } else {
          setState(() => _canResend = true);
        }
      }
    });
  }

  Future<void> _resendCode() async {
    if (!_canResend || _isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Resend OTP by attempting signup with email
      // Supabase will rate-limit this automatically (1 per minute per D-02)
      try {
        await Supabase.instance.client.auth.signUp(
          email: widget.email,
          password: 'dummy_password_$widget.email',
        );
      } catch (_) {
        // Suppress error from signup; we're just triggering OTP resend
      }

      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });

      _startResendCooldown();
      _codeExpiryTime = DateTime.now().add(const Duration(minutes: 10));
      _secondsRemaining = 600;
      _isCountingDown = true;
      _startCountdown();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification code resent')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to resend code. Please try again.';
      });
    }
  }

  Future<void> _verifyCode() async {
    final code = _controllers.map((c) => c.text).join();

    if (code.length != 6) {
      setState(() => _errorMessage = 'Please enter all 6 digits');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Per D-02, verify OTP using Supabase auth
      final response = await Supabase.instance.client.auth.verifyOTP(
        email: widget.email,
        type: OtpType.email,
        token: code,
      );

      if (mounted) {
        if (response.session != null) {
          setState(() => _isLoading = false);
          // Trigger callback for AuthProvider to handle device binding
          widget.onVerificationSuccess();
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Verification failed. Please try again.';
          });
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (e.message.toLowerCase().contains('expired')) {
            _errorMessage =
                'Code expired. Tap "Resend" to get a new code.';
          } else if (e.message.toLowerCase().contains('invalid')) {
            _errorMessage = 'Incorrect code. Try again.';
          } else {
            _errorMessage = e.message;
          }
        });

        // Clear fields on error
        for (final controller in _controllers) {
          controller.clear();
        }
        _focusNodes[0].requestFocus();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Something went wrong. Please try again.';
        });
        for (final controller in _controllers) {
          controller.clear();
        }
        _focusNodes[0].requestFocus();
      }
    }
  }

  void _onDigitEntered(int index, String value) {
    if (value.length > 1) {
      // Paste detected, fill remaining fields
      final digits = value.replaceAll(RegExp(r'[^0-9]'), '').split('');
      for (int i = 0; i < digits.length && i < 6; i++) {
        _controllers[i].text = digits[i];
      }
      // Move focus to last filled field or verify button
      if (digits.length >= 6) {
        _focusNodes[5].unfocus();
      } else {
        _focusNodes[digits.length - 1].requestFocus();
      }
    } else if (value.isEmpty) {
      // Backspace handling
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
    } else {
      // Single digit entered
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      }
    }
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  bool get _allFieldsFilled =>
      _controllers.every((c) => c.text.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Image.asset(
                      'assets/icon/logo.png',
                      width: 80,
                      height: 80,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Confirm Your Email',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'A 6-digit code has been sent to\n${widget.email}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Countdown timer
                  if (_isCountingDown)
                    Center(
                      child: Text(
                        'Code expires in ${_formatTime(_secondsRemaining)}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    Center(
                      child: Text(
                        'Code expired. Tap "Resend" to get a new code.',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: cs.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // 6 digit input fields
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (index) {
                      return Container(
                        width: 50,
                        height: 60,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        child: TextField(
                          controller: _controllers[index],
                          focusNode: _focusNodes[index],
                          enabled: !_isLoading && _isCountingDown,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          maxLength: 1,
                          inputFormatters: [
                            // Only allow digits
                          ],
                          decoration: InputDecoration(
                            counterText: '',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: cs.outlineVariant,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: cs.primary,
                                width: 2,
                              ),
                            ),
                            contentPadding: EdgeInsets.zero,
                            filled: true,
                            fillColor: cs.surfaceContainerHighest,
                          ),
                          style: theme.textTheme.headlineSmall,
                          onChanged: (value) {
                            final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
                            if (digits.isNotEmpty) {
                              _controllers[index].text = digits[0];
                              _onDigitEntered(index, digits[0]);
                            } else {
                              _onDigitEntered(index, '');
                            }
                          },
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),

                  // Error message
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onErrorContainer,
                        ),
                      ),
                    ),
                  if (_errorMessage != null) const SizedBox(height: 16),

                  // Verify button
                  FilledButton(
                    onPressed: (_isLoading || !_allFieldsFilled || !_isCountingDown)
                        ? null
                        : _verifyCode,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Verify Code'),
                  ),
                  const SizedBox(height: 16),

                  // Resend button
                  TextButton(
                    onPressed:
                        _canResend && !_isLoading ? _resendCode : null,
                    child: Text(
                      _canResend
                          ? "Didn't get the code? Resend"
                          : "Resend in ${_resendCooldownSeconds}s",
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
