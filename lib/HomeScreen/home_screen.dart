import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:helmet_license/HomeScreen/cameralive.dart';
import 'package:helmet_license/HomeScreen/imageUploadScreen.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    // Dynamic paddings and sizes
    double horizontalPadding = screenWidth * 0.05; // 5% of screen width
    double verticalPadding = screenHeight * 0.02; // 2% of screen height
    double featureCardIconSize = screenWidth * 0.1; // 10% of screen width
    double titleFontSize = screenWidth * 0.05; // Title font size based on screen width
    double descriptionFontSize = screenWidth * 0.035; // Description font size

    final List<String> roadSafetyTips = [
      "Use your phone’s camera to instantly detect helmet and license plate violations.",
      "Upload images to analyze helmet compliance and license plate visibility. Results stored securely in the cloud.",
      "Simplify violation detection and evidence storage for seamless traffic law enforcement.",
      "Empower users to promote helmet usage and compliance with road safety rules.",
      "All detections are securely saved in Firebase, ensuring you never lose crucial data.",
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '\t\t\t\t\t\t\t\t\t\tHelmet & License Plate\n\t\t\t\t\t\t\t\t\t\tDetection',
          style: TextStyle(
            fontSize: titleFontSize,
            fontWeight: FontWeight.bold,
            fontFamily: GoogleFonts.poppins().fontFamily,
            color: Color.fromARGB(255, 2, 26, 145),
          ),
          textAlign: TextAlign.center,
        ),
        backgroundColor: Color.fromARGB(255, 160, 222, 78),
        elevation: 0,
      ),
      body: Container(
        width: double.infinity, // Full width
        height: double.infinity, // Full height
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(255, 183, 238, 113),
              Color.fromARGB(255, 209, 107, 107),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: screenHeight * 0.02),

              // Carousel Slider for Road Safety Tips
              CarouselSlider(
                options: CarouselOptions(
                  height: screenHeight * 0.2,
                  autoPlay: true,
                  enlargeCenterPage: true,
                  viewportFraction: 0.8,
                  aspectRatio: 16 / 9,
                  initialPage: 0,
                ),
                items: roadSafetyTips.map((tip) {
                  return Builder(
                    builder: (BuildContext context) {
                      return Container(
                        width: screenWidth * 0.85,
                        margin: EdgeInsets.symmetric(horizontal: 5.0),
                        decoration: BoxDecoration(
                          color: Color.fromARGB(255, 255, 226, 226),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 5.0,
                              spreadRadius: 2.0,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              tip,
                              style: TextStyle(
                                fontSize: descriptionFontSize,
                                fontWeight: FontWeight.bold,
                                color: Color.fromARGB(255, 2, 26, 145),
                                fontFamily: GoogleFonts.roboto().fontFamily,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }).toList(),
              ),

              SizedBox(height: screenHeight * 0.05), // Spacing

              Text(
                'Key Features:',
                style: TextStyle(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.bold,
                  fontFamily: GoogleFonts.poppins().fontFamily,
                  color: Color.fromARGB(255, 0, 0, 0),
                ),
              ),

              SizedBox(height: screenHeight * 0.05), // Space before cards

              FeatureCard(
                icon: Icons.camera_alt,
                iconSize: featureCardIconSize,
                title: 'Real-time Detection',
                description: 'Tap to start detection and identify safety rule violations instantly.',
                titleFontSize: titleFontSize,
                descriptionFontSize: descriptionFontSize,
                onTap: () async {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CameraLive(),
                    ),
                  );
                },
                cardColor: Color.fromARGB(255, 210, 249, 183),
              ),

              SizedBox(height: screenHeight * 0.04), // Spacing between cards

              FeatureCard(
                icon: Icons.notifications,
                iconSize: featureCardIconSize,
                title: 'Upload Image and Detect',
                description: 'Upload images to detect helmet and license plate violations, ensuring safety and compliance.',
                titleFontSize: titleFontSize,
                descriptionFontSize: descriptionFontSize,
                onTap: () async {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ImageUploadScreen(),
                    ),
                  );
                },
                cardColor: Color.fromARGB(255, 210, 249, 183),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FeatureCard extends StatelessWidget {
  final IconData icon;
  final double iconSize;
  final String title;
  final String description;
  final double titleFontSize;
  final double descriptionFontSize;
  final VoidCallback onTap;
  final Color cardColor;

  FeatureCard({
    required this.icon,
    required this.iconSize,
    required this.title,
    required this.description,
    required this.titleFontSize,
    required this.descriptionFontSize,
    required this.onTap,
    required this.cardColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
      ),
      elevation: 10.0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(
                icon,
                size: iconSize,
                color: Color.fromARGB(255, 2, 26, 145),
              ),
              SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(255, 2, 26, 145),
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: descriptionFontSize,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
