import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LiveDetectionScreen extends StatefulWidget {
  @override
  _LiveDetectionScreenState createState() => _LiveDetectionScreenState();
}

class _LiveDetectionScreenState extends State<LiveDetectionScreen> {
  late CameraController _controller;
  late List<CameraDescription> cameras;
  bool isDetecting = false;
  final String flaskUrl = 'http://192.168.1.5:5000/video_feed'; // Replace with Flask server IP

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  // Initialize the camera
  Future<void> _initializeCamera() async {
    cameras = await availableCameras();
    _controller = CameraController(
      cameras[0], 
      ResolutionPreset.medium,
    );
    await _controller.initialize();
    setState(() {});
  }

  // Capture the frame and send it to the server
  Future<void> _captureAndDetect() async {
    if (!isDetecting) {
      setState(() {
        isDetecting = true;
      });

      // Capture the current frame
      final image = await _controller.takePicture();
      final imageBytes = await image.readAsBytes();

      // Send image to the server for detection
      final response = await _sendImageToServer(imageBytes);
      if (response.statusCode == 200) {
        final detectionResults = jsonDecode(response.body);
        print('Detection Results: $detectionResults');
      } else {
        print('Detection failed: ${response.statusCode}');
      }

      setState(() {
        isDetecting = false;
      });
    }
  }

  // Send image to the Flask server
  Future<http.Response> _sendImageToServer(Uint8List imageBytes) async {
    final uri = Uri.parse(flaskUrl);
    final request = http.MultipartRequest('POST', uri)
      ..files.add(http.MultipartFile.fromBytes('image', imageBytes, filename: 'image.jpg'));

    final response = await request.send();
    return http.Response.fromStream(response);
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Live Camera Detection'),
      ),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: CameraPreview(_controller), // Show camera feed
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: _captureAndDetect, // Capture and detect when pressed
            child: isDetecting ? CircularProgressIndicator() : Text('Capture & Detect'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            if (_controller.value.isRecordingVideo) {
              _controller.stopVideoRecording();
            } else {
              _controller.startVideoRecording();
            }
          });
        },
        child: Icon(
          _controller.value.isRecordingVideo ? Icons.stop : Icons.videocam,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
