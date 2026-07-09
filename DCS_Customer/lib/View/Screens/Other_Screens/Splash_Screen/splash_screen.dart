import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Dadacabs/View/Screens/Other_Screens/Splash_Screen/splash_logics.dart';
import 'package:Dadacabs/View/Themes/indian_heritage_theme.dart';
import 'package:Dadacabs/View/Widgets/translated_text.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    try {
      SplashLogics().checkPermissions(context, ref);
    } catch (e) {
      // Firebase not available (desktop smoke test env). Proceed with login flow.
      // ignore: avoid_print
      print('SplashLogics init skipped: $e');
      Future.delayed(const Duration(seconds: 3), () {
        if (context.mounted) {
          SplashLogics().initializeUser(context, ref);
        }
      });
    }
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.sizeOf(context);
    
    return Scaffold(
      backgroundColor: IndianHeritageColors.primaryYellow,
      body: Stack(
        children: [
          // Main Content
          Center(
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                        // Logo
                        Container(
                          width: size.width * 0.6,
                          height: size.width * 0.6,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 30,
                                offset: const Offset(0, 15),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(25),
                          child: Image.asset(
                            'assets/imgs/logo.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 32),
                        // App Name
                        const TranslatedText(
                          'Dada Cabs',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TranslatedText(
                          'Riding Made Simple',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black.withOpacity(0.6),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Bottom Loading
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                children: [
                  const SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Dada Cab Services Pvt Ltd',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black.withOpacity(0.4),
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
