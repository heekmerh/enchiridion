import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/about_config.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import 'auth_gate.dart';
import 'confirm_email_screen.dart';
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
  String _selectedRole = 'student';
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  bool _termsAccepted = false;
  String? _errorMessage;
  final List<TapGestureRecognizer> _legalLinkRecognizers = [];

  static const _roles = ['student', 'clinician', 'other'];

  @override
  void dispose() {
    for (final recognizer in _legalLinkRecognizers) {
      recognizer.dispose();
    }
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _openLegalLink(String url) async {
    final messenger = ScaffoldMessenger.of(context);
    bool opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (!opened) {
      await Clipboard.setData(ClipboardData(text: url));
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Link copied to clipboard.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  TextSpan _legalLink(String label, String url) {
    final recognizer = TapGestureRecognizer()
      ..onTap = () => _openLegalLink(url);
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
    final nameAvailable =
        await AuthService.isDisplayNameAvailable(displayName);
    if (!nameAvailable) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage =
            'That display name is already taken — please choose another.';
      });
      return;
    }

    if (!mounted) return;
    final error = await context.read<AuthProvider>().signUp(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          displayName: displayName,
          role: _selectedRole,
          termsVersion: AboutConfig.termsVersion,
        );

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
                        if (v == null || v.isEmpty)
                          return 'Password is required';
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
                                      AboutConfig.termsUrl),
                                  const TextSpan(text: ' and the '),
                                  _legalLink('Privacy Policy',
                                      AboutConfig.privacyPolicyUrl),
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
