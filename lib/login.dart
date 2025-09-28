import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'home.dart'; // Assuming you have a home.dart file

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pink Login',
      theme: ThemeData(
        primarySwatch: Colors.pink, // Main color is now pink
      ),
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 135.0),
              child: Image.asset(
                "assets/logo.png",
                width: 200,
                height: 200,
              ).animate().fadeIn(duration: 800.ms).move(begin: Offset(0, -50), end: Offset(0, 0), duration: 800.ms),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "Login",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.pink,
                    ),
                  ).animate().fadeIn(duration: 800.ms).move(begin: Offset(0, 50), end: Offset(0, 0), duration: 800.ms),
                  const SizedBox(height: 5),
                  Text(
                    "Sign in to continue",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.pink,
                    ),
                  ).animate().fadeIn(duration: 800.ms).move(begin: Offset(0, 50), end: Offset(0, 0), duration: 800.ms),
                  const SizedBox(height: 30),
                  TextField(
                    controller: usernameController,
                    keyboardType: TextInputType.text,
                    decoration: InputDecoration(
                      hintText: "Username",
                      filled: true,
                      fillColor: Colors.pink.shade100,
                      prefixIcon: const Icon(Icons.person, color: Colors.pink),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: const TextStyle(height: 0.8),
                  ).animate().fadeIn(duration: 800.ms).move(begin: Offset(0, 50), end: Offset(0, 0), duration: 800.ms),
                  const SizedBox(height: 15),
                  TextField(
                    controller: passwordController,
                    obscureText: !_isPasswordVisible,
                    decoration: InputDecoration(
                      hintText: "Password",
                      filled: true,
                      fillColor: Colors.pink.shade100,
                      prefixIcon: const Icon(Icons.lock, color: Colors.pink),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                          color: Colors.pink,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: const TextStyle(height: 0.8),
                  ).animate().fadeIn(duration: 800.ms).move(begin: Offset(0, 50), end: Offset(0, 0), duration: 800.ms),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      // Add your authentication logic here
                      String username = usernameController.text;
                      String password = passwordController.text;

                      // For now, just navigate to HomePage
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => HomePage()),
                      );
                    },
                    child: const Text(
                      "Log In",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ).animate().fadeIn(duration: 800.ms).move(begin: Offset(0, 50), end: Offset(0, 0), duration: 800.ms),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}