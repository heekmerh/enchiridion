import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/google_sign_in_config.dart';
import '../constants/about_config.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../widgets/auth/google_sign_in_button.dart';
import 'auth_gate.dart';
import 'confirm_email_screen.dart';
import 'legal_document_screen.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _referralCtrl = TextEditingController();
  bool _referralApplied = false;
  String _selectedRole = 'student';
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  bool _googleLoading = false;
  bool _termsAccepted = false;
  String? _errorMessage;
  final List<TapGestureRecognizer> _legalLinkRecognizers = [];

  static const _roles = ['student', 'clinician', 'other'];
  static const _referralAppliedKey = 'referral_code_applied';

  @override
  void initState() {
    super.initState();
    _loadReferralApplied();
  }

  Future<void> _loadReferralApplied() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(
        () => _referralApplied = prefs.getBool(_referralAppliedKey) ?? false);
  }

  @override
  void dispose() {
    for (final recognizer in _legalLinkRecognizers) {
      recognizer.dispose();
    }
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _referralCtrl.dispose();
    super.dispose();
  }

  TextSpan _legalLink(String label, LegalDocument document) {
    final recognizer = TapGestureRecognizer()
      ..onTap = () => LegalDocumentScreen.open(context, document);
    _legalLinkRecognizers.add(recognizer);
    return TextSpan(
      text: label,
      style: TextStyle(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w600,
        decoration: TextDecoration.underline,
      ),
      recognizer: recognizer,
    );
  }

  Future<void> _continueWithGoogle() async {
    if (!_termsAccepted) {
      setState(() => _errorMessage =
          'Please accept the Terms and Conditions to create an account.');
      return;
    }
    setState(() {
      _googleLoading = true;
      _errorMessage = null;
    });
    final result = await context
        .read<AuthProvider>()
        .signInWithGoogle(termsVersion: AboutConfig.termsVersion);
    if (!mounted) return;
    setState(() {
      _googleLoading = false;
      _errorMessage = result.error;
    });
    if (result.signedIn) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthGate()),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_termsAccepted) {
      setState(() => _errorMessage =
          'Please accept the Terms and Conditions and Privacy Policy to '
              'continue.');
      return;
    }
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final displayName = _nameCtrl.text.trim();
    final nameAvailable = await AuthService.isDisplayNameAvailable(displayName);
    if (!nameAvailable) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage =
            'That display name is already taken — please choose another.';
      });
      return;
    }

    final referralCode =
        _referralApplied ? '' : _referralCtrl.text.trim().toLowerCase();
    if (referralCode.isNotEmpty) {
      final referralValid = await AuthService.isReferralCodeValid(referralCode);
      if (!mounted) return;
      if (!referralValid) {
        setState(() {
          _loading = false;
          _errorMessage = 'That referral code was not found.';
        });
        return;
      }
    }

    if (!mounted) return;
    final error = await context.read<AuthProvider>().signUp(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          displayName: displayName,
          role: _selectedRole,
          termsVersion: AboutConfig.termsVersion,
          referredBy: referralCode.isEmpty ? null : referralCode,
        );

    if (referralCode.isNotEmpty &&
        (error == null || error == 'confirm_email')) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_referralAppliedKey, true);
    }

    if (!mounted) return;
    setState(() => _loading = false);

    if (error == 'confirm_email') {
      // Sign-up succeeded but there is no session yet. Hand off to the code
      // entry screen rather than stranding the user on this form.
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ConfirmEmailScreen(email: _emailCtrl.text.trim()),
        ),
      );
    } else if (error != null) {
      setState(() => _errorMessage = error);
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthGate()),
      );
    }
  }

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
              child: Form(
                key: _formKey,
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
                    const SizedBox(height: 24),
                    Text(
                      'Create account',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your pocket reference for clinical practice',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Display name
                    TextFormField(
                      controller: _nameCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Display name',
                        prefixIcon: Icon(Icons.person_outlined),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Display name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Email
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Email is required';
                        }
                        if (!v.contains('@')) return 'Enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Role
                    DropdownButtonFormField<String>(
                      initialValue: _selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Role',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      items: _roles
                          .map((r) => DropdownMenuItem(
                                value: r,
                                child: Text(
                                    '${r[0].toUpperCase()}${r.substring(1)}'),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _selectedRole = v ?? 'student'),
                    ),
                    const SizedBox(height: 16),

                    // Password
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Password is required';
                        }
                        if (v.length < 8) {
                          return 'Password must be at least 8 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Confirm password
                    TextFormField(
                      controller: _confirmCtrl,
                      obscureText: _obscureConfirm,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Confirm password',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirm
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined),
                          onPressed: () => setState(
                              () => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (v != _passwordCtrl.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),

                    if (!_referralApplied) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _referralCtrl,
                        textInputAction: TextInputAction.done,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'Referral code (optional)',
                          prefixIcon: Icon(Icons.card_giftcard_outlined),
                        ),
                        validator: (v) {
                          final code = v?.trim() ?? '';
                          if (code.isEmpty) return null;
                          return RegExp(r'^[A-Za-z0-9_-]{3,64}$').hasMatch(code)
                              ? null
                              : 'Enter a valid referral code';
                        },
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Play policy: the auto-renewal and legal terms must be
                    // accepted explicitly, and the acceptance is recorded
                    // against the account (profiles.terms_version).
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _termsAccepted,
                          onChanged: (v) => setState(() {
                            _termsAccepted = v ?? false;
                            if (_termsAccepted) _errorMessage = null;
                          }),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: RichText(
                              text: TextSpan(
                                style: theme.textTheme.bodySmall,
                                children: [
                                  const TextSpan(
                                      text: 'I am 18 or older and I agree to '
                                          'the '),
                                  _legalLink('Terms and Conditions',
                                      LegalDocument.terms),
                                  const TextSpan(text: ' and the '),
                                  _legalLink(
                                      'Privacy Policy', LegalDocument.privacy),
                                  const TextSpan(
                                      text: '. Enchiridion is a study aid, '
                                          'not a substitute for clinical '
                                          'judgement.'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Error
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
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

                    const SizedBox(height: 24),

                    FilledButton(
                      onPressed: (_loading || !_termsAccepted) ? null : _submit,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Create Account'),
                    ),
                    if (isGoogleSignInConfigured) ...[
                      const SizedBox(height: 20),
                      const AuthDivider(),
                      const SizedBox(height: 20),
                      GoogleSignInButton(
                        busy: _googleLoading,
                        onPressed: (_loading || !_termsAccepted)
                            ? null
                            : _continueWithGoogle,
                      ),
                    ],
                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            'Already have an account? ',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const LoginScreen()),
                          ),
                          child: const Text('Log in'),
                        ),
                      ],
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
