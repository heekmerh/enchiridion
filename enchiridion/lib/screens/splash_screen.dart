import 'package:flutter/material.dart' hide ThemeMode;
import 'package:provider/provider.dart';
import '../models/user_settings.dart';
import '../providers/settings_provider.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';
import 'library_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkAuthAndNavigate();
  }

  void _checkAuthAndNavigate() {
    if (_navigated) return;

    final authProvider = context.read<AuthProvider>();

    // Wait until auth status resolves from loading.
    if (authProvider.status == AuthStatus.loading) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _checkAuthAndNavigate();
      });
      return;
    }

    // Minimum splash display time.
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted || _navigated) return;
      _navigated = true;

      final destination = authProvider.isAuthenticated
          ? const LibraryScreen()
          : const LoginScreen();

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => destination,
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>().settings;
    final isDark = settings.theme == ThemeMode.dark;

    final backgroundColor =
        isDark ? const Color(0xFF0A0E27) : const Color(0xFFF8F9FA);
    final accentColor =
        isDark ? const Color(0xFFFF006E) : const Color(0xFF00D9FF);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/icon/logo.png', width: 280, height: 280),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Enchiridion',
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.7)
                            : Colors.black.withValues(alpha: 0.6),
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
