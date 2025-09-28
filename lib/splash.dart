import 'package:flutter/material.dart';
import 'package:lakii/login.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final List<String> imagePaths = [
    'assets/2-Photoroom.png',
    'assets/3-Photoroom.png',
    'assets/5-Photoroom.png', // index 2 → pop from inside
    'assets/4-Photoroom.png',
    'assets/6-Photoroom.png',
    'assets/7-Photoroom.png',
  ];

  final List<bool> _visible = List.generate(6, (_) => false);

  @override
  void initState() {
    super.initState();

    // Show each image with staggered delay
    for (int i = 0; i < imagePaths.length; i++) {
      int delay = (i == 2) ? 1200 : i * 300; // Delay for 5th image after 4th
      Future.delayed(Duration(milliseconds: delay), () {
        if (mounted) {
          setState(() {
            _visible[i] = true;
          });
        }
      });
    }

    // Navigate to LoginPage after total duration
    Timer(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SizedBox(
          width: 400,
          height: 400,
          child: Stack(
            children: List.generate(imagePaths.length, (index) {
              final isInsidePop = index == 2;

              return AnimatedOpacity(
                opacity: _visible[index] ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 500),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    begin: _visible[index]
                        ? (isInsidePop ? 0.0 : 2.0)
                        : (isInsidePop ? 0.0 : 2.0),
                    end: _visible[index] ? 1.0 : (isInsidePop ? 0.0 : 2.0),
                  ),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutBack,
                  builder: (context, scale, child) {
                    return Transform.scale(
                      scale: scale,
                      child: child,
                    );
                  },
                  child: Image.asset(
                    imagePaths[index],
                    fit: BoxFit.cover,
                    width: 400,
                    height: 400,
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
