import 'package:flutter/material.dart';
import '/ble/ble_controller.dart';
import 'control_page.dart';

void main() {
  runApp(const AuraMaxxApp());
}

class AuraMaxxApp extends StatelessWidget {
  const AuraMaxxApp({super.key});

  @override
  Widget build(BuildContext context) {
    final bleController = BleController();

    final base = ThemeData.dark();
    final theme = base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: Colors.redAccent,
        secondary: Colors.redAccent.shade200,
        background: const Color(0xFF131313),
      ),
      scaffoldBackgroundColor: Colors.transparent,
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: Colors.redAccent,
        thumbColor: Colors.redAccent,
        overlayColor: Colors.redAccent.withOpacity(0.2),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.redAccent,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 6,
        ),
      ),
    );

    return MaterialApp(
      title: 'Auramaxx',
      theme: theme,
      debugShowCheckedModeBanner: false,
      home: SplashScreen(ble: bleController),
    );
  }
}

class SplashScreen extends StatefulWidget {
  final BleController ble;

  const SplashScreen({super.key, required this.ble});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();

    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ControlPage(ble: widget.ble)),
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
    return Scaffold(
      backgroundColor: const Color(0xFF131313),
      body: Center(
        child: FadeTransition(
          opacity: _animation,
          child: Image.asset(
            'assets/auramaxx_logo.png',
            fit: BoxFit.contain,
            width: MediaQuery.of(context).size.width * 0.7,
          ),
        ),
      ),
    );
  }
}
