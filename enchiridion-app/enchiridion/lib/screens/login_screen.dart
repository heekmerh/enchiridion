import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/google_sign_in_config.dart';
import '../constants/about_config.dart';
import '../providers/auth_provider.dart';
import '../services/biometric_sign_in_service.dart';
import '../widgets/auth/google_sign_in_button.dart';
import 'legal_document_screen.dart';
import 'auth_gate.dart';
import 'register_screen.dart';
import 'password_reset_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;
  bool _googleLoading = false;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  bool _saveBiometric = false;
  bool get _busy => _loading || _googleLoading;

  @override
  void initState() {
    super.initState();
    _loadBiometrics();
  }

  Future<void> _loadBiometrics() async {
    try {
      final service = BiometricSignInService.instance;
      final available = await service.isAvailable();
      final enabled = await service.isEnabled();
      if (!mounted) return;
      setState(() {
        _biometricAvailable = available;
        _biometricEnabled = enabled;
      });
    } catch (_) {}
  }

  Future<void> _forgetBiometrics() async {
    if (_busy) return;
    setState(() => _loading = true);
    try {
      await BiometricSignInService.instance.disable();
      if (!mounted) return;
      setState(() {
        _biometricEnabled = false;
        _saveBiometric = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage =
            'Could not remove fingerprint sign-in. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithBiometrics() async {
    if (_busy) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    final result = await BiometricSignInService.instance.signIn();
    if (!mounted) return;
    setState(() => _loading = false);
    if (result == BiometricSignInResult.signedIn) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthGate()),
      );
      return;
    }
    setState(() => _errorMessage = switch (result) {
          BiometricSignInResult.expired =>
            'Please sign in with your password and enable fingerprint sign-in again.',
          BiometricSignInResult.unavailable =>
            'Fingerprint sign-in is unavailable. Use your password.',
          BiometricSignInResult.canceled => null,
          _ =>
            'Fingerprint sign-in did not complete. Try again or use your password. An internet connection is required.',
        });
    await _loadBiometrics();
  }

  String? _errorMessage;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _continueWithGoogle() async {
    if (_busy) return;
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
      try {
        if (await BiometricSignInService.instance.isEnabled()) {
          await BiometricSignInService.instance.disable();
        }
      } catch (_) {}
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthGate()),
      );
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final error = await context.read<AuthProvider>().signIn(
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
        );

    if (!mounted) return;
    if (error != null) {
      setState(() {
        _loading = false;
        _errorMessage = error;
      });
    } else {
      try {
        if (_saveBiometric) {
          await BiometricSignInService.instance.enable(
            _emailCtrl.text.trim(),
            _passwordCtrl.text,
          );
        } else if (await BiometricSignInService.instance.isEnabled()) {
          await BiometricSignInService.instance.disable();
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Signed in. Fingerprint setup did not complete; you can try again on your next password login.'),
          ));
        }
      }
      _passwordCtrl.clear();
      if (!mounted) return;
      setState(() => _loading = false);
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
                    // Logo
                    Center(
                      child: Image.asset(
                        'assets/icon/logo.png',
                        width: 80,
                        height: 80,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Welcome back',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in to your Enchiridion account',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 32),

                    if (_biometricEnabled) ...[
                      OutlinedButton.icon(
                        onPressed: _busy || !_biometricAvailable
                            ? null
                            : _signInWithBiometrics,
                        icon: const Icon(Icons.fingerprint),
                        label: const Text('Sign in with fingerprint'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                      TextButton(
                        onPressed: _busy ? null : _forgetBiometrics,
                        child: const Text(
                            'Forget fingerprint sign-in on this device'),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Email
                    TextFormField(
                      controller: _emailCtrl,
                      enabled: !_busy,
                      autofillHints: const [AutofillHints.username],
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

                    // Password
                    TextFormField(
                      controller: _passwordCtrl,
                      enabled: !_busy,
                      autofillHints: const [AutofillHints.password],
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
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
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),

                    if (_biometricAvailable)
                      CheckboxListTile(
                        value: _saveBiometric,
                        onChanged: _busy
                            ? null
                            : (value) =>
                                setState(() => _saveBiometric = value ?? false),
                        title: const Text('Use fingerprint next time'),
                        subtitle: const Text(
                            'Save this login securely on this device. Anyone with an enrolled fingerprint can use it.'),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),

                    // Forgot password
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const PasswordResetScreen()),
                        ),
                        child: const Text('Forgot password?'),
                      ),
                    ),

                    // Error message
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 8),
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

                    // Sign in button
                    FilledButton(
                      onPressed: _busy ? null : _submit,
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
                          : const Text('Sign In'),
                    ),
                    if (isGoogleSignInConfigured) ...[
                      const SizedBox(height: 20),
                      const AuthDivider(),
                      const SizedBox(height: 20),
                      GoogleSignInButton(
                        busy: _googleLoading,
                        onPressed: _busy ? null : _continueWithGoogle,
                      ),
                      TextButton(
                        onPressed: () => LegalDocumentScreen.open(
                            context, LegalDocument.terms),
                        child: Text(
                          'By continuing with Google you agree to the Terms '
                          'and Conditions and Privacy Policy.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Register link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: theme.textTheme.bodyMedium,
                        ),
                        TextButton(
                          onPressed: () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const RegisterScreen()),
                          ),
                          child: const Text('Sign up'),
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
