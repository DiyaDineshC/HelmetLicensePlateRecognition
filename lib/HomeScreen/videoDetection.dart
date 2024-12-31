// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:camera/camera.dart';
// import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

// List<CameraDescription> cameras = [];

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   cameras = await availableCameras(); // Get available cameras
//   runApp(MyApp());
// }

// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       home: LiveTextRecognition(),
//     );
//   }
// }

// class LiveTextRecognition extends StatefulWidget {
//   @override
//   _LiveTextRecognitionState createState() => _LiveTextRecognitionState();
// }

// class _LiveTextRecognitionState extends State<LiveTextRecognition> {
//   late CameraController _cameraController;
//   bool _isDetecting = false;
//   String _detectedText = "";
//   final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

//   @override
//   void initState() {
//     super.initState();
//     _initializeCamera();
//   }

//   Future<void> _initializeCamera() async {
//     _cameraController = CameraController(
//       cameras.first,
//       ResolutionPreset.medium,
//     );

//     await _cameraController.initialize();
//     _startDetection();
//   }

//   void _startDetection() {
//     _cameraController.startImageStream((CameraImage cameraImage) async {
//       if (_isDetecting) return;
//       _isDetecting = true;

//       try {
//         // Convert CameraImage to InputImage for ML Kit
//         final InputImage inputImage = _convertToInputImage(cameraImage);
//         final RecognizedText recognizedText =
//             await textRecognizer.processImage(inputImage);

//         // Process detected text
//         setState(() {
//           _detectedText = recognizedText.text;
//         });
//       } catch (e) {
//         debugPrint('Error detecting text: $e');
//       } finally {
//         _isDetecting = false;
//       }
//     });
//   }

//   InputImage _convertToInputImage(CameraImage cameraImage) {
//     // Convert cameraImage to InputImage for ML Kit
//     final WriteBuffer allBytes = WriteBuffer();
//     for (var plane in cameraImage.planes) {
//       allBytes.putUint8List(plane.bytes);
//     }

//     final inputImageFormat = InputImageFormatMethods.fromRawValue(
//       cameraImage.format.raw,
//     );

//     final inputImageData = InputImageData(
//       size: Size(
//         cameraImage.width.toDouble(),
//         cameraImage.height.toDouble(),
//       ),
//       imageRotation: InputImageRotation.rotation0deg, // Adjust for camera orientation
//       inputImageFormat: inputImageFormat!,
//       planeData: cameraImage.planes.map((Plane plane) {
//         return InputImagePlaneMetadata(
//           bytesPerRow: plane.bytesPerRow,
//           height: plane.height,
//           width: plane.width,
//         );
//       }).toList(),
//     );

//     return InputImage.fromBytes(
//       bytes: allBytes.done().buffer.asUint8List(),
//       inputImageData: inputImageData,
//     );
//   }

//   @override
//   void dispose() {
//     _cameraController.dispose();
//     textRecognizer.close();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Live Text Recognition')),
//       body: Stack(
//         children: [
//           // Camera preview
//           _cameraController.value.isInitialized
//               ? CameraPreview(_cameraController)
//               : Center(child: CircularProgressIndicator()),
//           // Detected text overlay
//           Align(
//             alignment: Alignment.bottomCenter,
//             child: Container(
//               color: Colors.black.withOpacity(0.5),
//               padding: const EdgeInsets.all(8.0),
//               child: Text(
//                 _detectedText,
//                 style: TextStyle(color: Colors.white, fontSize: 16),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
