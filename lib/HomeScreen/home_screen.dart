import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:helmet_license/HomeScreen/cameralive.dart';
import 'package:helmet_license/HomeScreen/imageUploadScreen.dart';


class HomeScreen extends StatelessWidget {



  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double horizontalPadding = screenWidth * 0.05;
    double featureCardIconSize = screenWidth * 0.1;

    return Scaffold(
      appBar: AppBar(
        title: Text('Helmet & License Plate Detect Karo!'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome to the Detection App',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text(
              'Key Features:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            FeatureCard(
              icon: Icons.camera_alt,
              iconSize: featureCardIconSize,
              title: 'Real-time Detection',
              description: 'Monitor helmets and license plates in real-time.',
              onTap: () async {
                
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CameraLive(),
                        ),
                      );
              } 
            ),
            FeatureCard(
              icon: Icons.notifications,
              iconSize: featureCardIconSize,
              title: 'Start Detection',
              description: 'Receive alerts when violations are detected.',
              onTap: () async {
                
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ImageUploadScreen(),
                        ),
                      );
              } ) , 
            FeatureCard(
              icon: Icons.history,
              iconSize: featureCardIconSize,
              title: 'Violation History',
              description: 'View history of detected violations.',
              onTap: () {
                // Navigate to history page
              },
            ),
            FeatureCard(
              icon: Icons.map,
              iconSize: featureCardIconSize,
              title: 'Geolocation Tracking',
              description: 'Track locations of detected violations.',
              onTap: () {
                // Navigate to map page
                
              },
            ),
            FeatureCard(
              icon: Icons.analytics,
              iconSize: featureCardIconSize,
              title: 'Reporting & Analytics',
              description: 'Generate reports and analyze data.',
              onTap: () {
                // Navigator.push(
                //         context,
                //         MaterialPageRoute(
                //           builder: (context) => DetectionList(),
                //         ),
                //       );
                

              },
            ),
            SizedBox(height: 20),
            // ElevatedButton(
            //   onPressed: () {
            //     // Add logic to start detection
            //   },
            //   child: Text('Start Detection'),
            //   style: ElevatedButton.styleFrom(
            //     padding: EdgeInsets.symmetric(vertical: 16),
            //     textStyle: TextStyle(fontSize: screenWidth * 0.045),
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final String modelPath;
  final Function(List<dynamic> recognitions, int height, int width) onRecognitions;

  const CameraScreen({
    Key? key,
    required this.cameras,
    required this.modelPath,
    required this.onRecognitions,
  }) : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    _controller = CameraController(widget.cameras.first, ResolutionPreset.high);
    await _controller.initialize();
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      appBar: AppBar(
        title: Text("Real-time Detection"),
      ),
      body: CameraPreview(_controller),
    );
  }
}


class FeatureCard extends StatelessWidget {
  final IconData icon;
  final double iconSize;
  final String title;
  final String description;
  final VoidCallback onTap;

  const FeatureCard({
    Key? key,
    required this.icon,
    required this.iconSize,
    required this.title,
    required this.description,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4,
        margin: EdgeInsets.symmetric(vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(
                icon,
                size: iconSize,
                color: Colors.blue,
              ),
              SizedBox(width: screenWidth * 0.04),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontSize: screenWidth * 0.045, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: screenWidth * 0.02),
                    Text(
                      description,
                      style: TextStyle(fontSize: screenWidth * 0.04),
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
