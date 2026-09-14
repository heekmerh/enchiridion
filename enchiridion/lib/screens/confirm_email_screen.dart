import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../config/supabase_config.dart';
import '../providers/auth_provider.dart';
import 'library_screen.dart';
import 'login_screen.dart';

/// Collects the numeric code Supabase emails after sign-up.
///
/// Reached from RegisterScreen when signUp returns without a session. The code
/// only exists if the "Confirm signup" email template renders `{{ .Token }}` —
/// with the stock link-only template the email arrives with nothing to type.
///
/// Its length is [kEmailOtpLength], which must track the dashboard's "Email
/// OTP length" setting.
class ConfirmEmailScreen extends StatefulWidget {
  const ConfirmEmailScreen({super.key, required this.email});

  final String email;

  @override
  State<ConfirmEmailScreen> createState() => _ConfirmEmailScreenState();
}

class _ConfirmEmailScreenState extends State<ConfirmEmailScreen> {
  // Length comes from supabase_config.dart so it tracks the dashboard's
  // "Email OTP length" setting in one place rather than being hardcoded here.
  static const _codeLength = kEmailOtpLength;

  /// Matches Supabase's own resend rate limit, so the button re-enables at
  /// roughly the moment a retry would actually be accepted.
  static const _resendCooldown = Duration(seconds: 60);

  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  bool _resending = false;
  String? _errorMessage;
  String? _noticeMessage;
  Timer? _cooldownTimer;
  int _secondsRemaining = 0;

  @override
  void initState() {
    super.initState();
    // The code was sent by the signUp call that pushed this screen, so the
    // cooldown starts immediately rather than after the first manual resend.
    _startCooldown();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _secondsRemaining = _resendCooldown.inSeconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _secondsRemaining--);
      if (_secondsRemaining <= 0) timer.cancel();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _errorMessage = null;
      _noticeMessage = null;
    });

    final error = await context.read<AuthProvider>().verifyEmailOtp(
          email: widget.email,
          token: _codeCtrl.text.trim(),
        );

    if (!mounted) return;
    setState(() => _loading = false);

    if (error != null) {
      setState(() => _errorMessage = error);
      return;
    }

    // Registration is finished and a session exists. Drop the register and
    // confirm screens so Back cannot return to a half-finished signup.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LibraryScreen()),
      (route) => false,
    );
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _errorMessage = null;
      _noticeMessage = null;
    });

    final error =
        await context.read<AuthProvider>().resendEmailOtp(widget.email);

    if (!mounted) return;
    setState(() {
      _resending = false;
      if (error != null) {
        _errorMessage = error;
      } else {
        _noticeMessage = 'A new code is on its way to ${widget.email}.';
        _codeCtrl.clear();
      }
    });

    if (error == null) _startCooldown();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final canResend = _secondsRemaining <= 0 && !_resending && !_loading;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.mark_email_unread_outlined,
                        size: 64, color: cs.primary),
                    const SizedBox(height: 24),
                    Text(
                      'Confirm your email',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'We sent a $_codeLength-digit code to',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: cs.onSurface.withValues(alpha: 0.6)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.email,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _codeCtrl,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      textAlign: TextAlign.center,
                      maxLength: _codeLength,
                      enabled: !_loading,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        letterSpacing: _codeLength > 6 ? 6 : 12,
                        fontWeight: FontWeight.bold,
                      ),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      autofillHints: const [AutofillHints.oneTimeCode],
                      decoration: InputDecoration(
                        labelText: 'Verification code',
                        counterText: '',
                        hintText: '0' * _codeLength,
                      ),
                      onChanged: (v) {
                        // Submit as soon as the last digit lands — the code is
                        // fixed-length, so an explicit tap adds nothing.
                        if (v.length == _codeLength && !_loading) _submit();
                      },
                      onFieldSubmitted: (_) => _submit(),
                      validator: (v) {
                        final value = v?.trim() ?? '';
                        if (value.isEmpty) {
                          return 'Enter the code from your email';
                        }
                        if (value.length != _codeLength) {
                          return 'The code is $_codeLength digits';
                        }
                        return null;
                      },
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: cs.onErrorContainer),
                        ),
                      ),
                    ],
                    if (_noticeMessage != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _noticeMessage!,
                          style: TextStyle(color: cs.onSecondaryContainer),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Confirm email'),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: canResend ? _resend : null,
                      child: _resending
                          ? const Text('Sending…')
                          : Text(_secondsRemaining > 0
                              ? 'Resend code in ${_secondsRemaining}s'
                              : 'Resend code'),
                    ),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                    builder: (_) => const LoginScreen()),
                                (route) => false,
                              ),
                      child: const Text('Back to login'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
