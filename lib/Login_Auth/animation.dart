import 'package:flutter/material.dart';
import 'LoginPage.dart';
import 'package:lottie/lottie.dart';

class AnimationWidget extends StatefulWidget {
  const AnimationWidget({super.key});

  @override
  State<AnimationWidget> createState() => _AnimationWidgetState();
}

class _AnimationWidgetState extends State<AnimationWidget> {
  @override
  void initState() {
    super.initState();

    Future.delayed(
      const Duration(seconds: 4),
      () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginPage()),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xffF7C2AD).withOpacity(0.8), // Lighter shade
                const Color(0xffEE8572), // Darker shade
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Lottie Animation with adjusted size
                SizedBox(
                  height: 300,
                  width: 300,
                  child: Lottie.asset('assets/Animation - 1727603704253.json'),
                ),

                const SizedBox(height: 60), // Increased spacing

                // Circular Progress Indicator (for loading effect)
                const SizedBox(
                  height: 50,
                  width: 50,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 4, // Increased stroke width
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}