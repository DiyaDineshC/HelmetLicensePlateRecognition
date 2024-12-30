//

import 'dart:math';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_vision/flutter_vision.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:permission_handler/permission_handler.dart';

Future<void> saveResultsToFirebase(List<Map<String, dynamic>> results) async {
  try {
    final firestore = FirebaseFirestore.instance;
    final detectionsCollection = firestore.collection('detections');

    final data = {
      'timestamp': FieldValue.serverTimestamp(),
      'results': results, // Store the detection results
    };

    await detectionsCollection.add(data);

    print("Results saved to Firebase successfully!");
  } catch (e) {
    print("Error saving results to Firebase: $e");
  }
}

class CameraLive extends StatefulWidget {
  const CameraLive({Key? key}) : super(key: key);

  @override
  State<CameraLive> createState() => _CameraLiveState();
}

class _CameraLiveState extends State<CameraLive> {
  late CameraController controller;
  late FlutterVision vision;
  List<Map<String, dynamic>> yoloResults = [];
  CameraImage? cameraImage;
  bool isLoaded = false;
  bool isDetecting = false;
  bool isLicensePlateDetected = false;
  double confidenceThreshold = 0.5;
  late String screenshotPath;

  late TextRecognizer textRecognizer;

  final GlobalKey _boundaryKey = GlobalKey(); // Key for RepaintBoundary

  @override
  void initState() {
    super.initState();
    init();
    textRecognizer = GoogleMlKit.vision.textRecognizer();
  }

  init() async {
    final cameras = await availableCameras();
    controller = CameraController(cameras[0], ResolutionPreset.high);
    await controller.initialize();
    vision = FlutterVision();
    await loadYoloModel();

    setState(() {
      isLoaded = true;
    });
  }

  @override
  void dispose() {
    controller.dispose();
    vision.closeYoloModel();
    textRecognizer.close();
    super.dispose();
  }

  Future<void> loadYoloModel() async {
    await vision.loadYoloModel(
      labels: 'assets/classes.txt',
      modelPath: 'assets/best_float32.tflite',
      modelVersion: "yolov8",
      numThreads: 4,
      useGpu: true,
    );
  }

  Future<void> yoloOnFrame(CameraImage cameraImage) async {
    final result = await vision.yoloOnFrame(
      bytesList: cameraImage.planes.map((plane) => plane.bytes).toList(),
      imageHeight: cameraImage.height,
      imageWidth: cameraImage.width,
      iouThreshold: 0.4,
      confThreshold: 0.4,
      classThreshold: 0.5,
    );
    if (result.isNotEmpty) {
      setState(() {
        yoloResults = result;
      });
      for (var detection in result) {
        if (detection['tag'] == 'license plate') {
          await captureAndProcessRegion();
          setState(() {
            isLicensePlateDetected = true;
          });
          await saveResultsToFirebase(result);
          break;
        }
      }
    }
  }

  Future<void> captureAndProcessRegion() async {
    final renderObject = _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary;
    if (renderObject != null) {
      final image = await renderObject.toImage(pixelRatio: 3.0); // Get the image
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final buffer = byteData!.buffer.asUint8List();
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/screenshot.png';
      final file = File(filePath);
      await file.writeAsBytes(buffer);

      setState(() {
        screenshotPath = filePath;
      });

      // Get bounding box for license plate detection (assuming only one detection for simplicity)
      final detection = yoloResults.firstWhere((result) => result['tag'] == 'license plate', orElse: () => {});
      if (detection.isNotEmpty) {

        // Extract the bounding box coordinates
        //To do: Figure out proper coordinates

        final box = detection["box"];
        final x = box[0]; // x1: left
        final y = box[1]; // y1: top
        final width = box[2] - box[0]; // width
        final height = box[3] - box[1]; // height

        // Crop the image based on the bounding box coordinates
        final croppedFile = await cropImage(file, x, y, width, height);

        // Use the cropped image for OCR
        await recognizeTextFromImage(file); //replace with croppedFile to test cropping functionality
      } else {
        print("No license plate detected.");
      }
    }
  }

  Future<File> cropImage(File imageFile, double x, double y, double width, double height) async {
    final img.Image image = img.decodeImage(await imageFile.readAsBytes())!; // Decode image

    // Perform the crop
    final img.Image croppedImage = img.copyCrop(image, x.toInt(), y.toInt(), width.toInt(), height.toInt());

    // Save the cropped image as a temporary file
    final directory = await getTemporaryDirectory();
    final croppedFilePath = '${directory.path}/cropped_screenshot.png';
    final croppedFile = File(croppedFilePath);
    await croppedFile.writeAsBytes(img.encodePng(croppedImage)); // Save locally

    return croppedFile;
  }

  Future<void> recognizeTextFromImage(File imageFile) async {
    try {
      // Create an InputImage from the screenshot
      final inputImage = InputImage.fromFilePath(imageFile.path);

      // Process the image for text recognition
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);

      // Extract the recognized text
      String text = recognizedText.text;
      print("Recognized text: $text");

      // Save text recognition result to Firestore
      await saveTextRecognitionToFirebase(text);

    } catch (e) {
      print("Error recognizing text: $e");
    }
  }

  Future<void> saveTextRecognitionToFirebase(String recognizedText) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final textRecognitionsCollection = firestore.collection('text_recognitions');

      final data = {
        'timestamp': FieldValue.serverTimestamp(),
        'recognized_text': recognizedText, // Store the recognized text
      };

      await textRecognitionsCollection.add(data);

      print("Text recognition results saved to Firebase successfully!");
    } catch (e) {
      print("Error saving text recognition results to Firebase: $e");
    }
  }


  Future<void> startDetection() async {
    setState(() {
      isDetecting = true;
    });
    await controller.startImageStream((image) async {
      if (isDetecting) {
        cameraImage = image;
        await yoloOnFrame(image);
      }
    });
  }

  Future<void> stopDetection() async {
    setState(() {
      isDetecting = false;
      yoloResults.clear();
    });
  }

  List<Widget> displayBoxesAroundRecognizedObjects(Size screen) {
    if (yoloResults.isEmpty) return [];

    double factorX = screen.width / (cameraImage?.height ?? 1);
    double factorY = screen.height / (cameraImage?.width ?? 1);

    return yoloResults.map((result) {
      double objectX = result["box"][0] * factorX;
      double objectY = result["box"][1] * factorY;
      double objectWidth = (result["box"][2] - result["box"][0]) * factorX;
      double objectHeight = (result["box"][3] - result["box"][1]) * factorY;

      return Positioned(
        left: objectX,
        top: objectY,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "${result['tag']}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16.0,
                ),
              ),
            ),
            Container(
              width: objectWidth,
              height: objectHeight,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.pink, width: 2.0),
                borderRadius: BorderRadius.circular(10.0),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;

    if (!isLoaded) {
      return const Scaffold(
        body: Center(child: Text("Model not loaded, waiting for it")),
      );
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            key: _boundaryKey,
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: CameraPreview(controller),
            ),
          ),
          ...displayBoxesAroundRecognizedObjects(size),
          Positioned(
            bottom: 75,
            width: MediaQuery.of(context).size.width,
            child: Container(
              height: 80,
              width: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(width: 5, color: Colors.white),
              ),
              child: isDetecting
                  ? IconButton(
                onPressed: stopDetection,
                icon: const Icon(Icons.stop, color: Colors.red),
                iconSize: 50,
              )
                  : IconButton(
                onPressed: startDetection,
                icon: const Icon(Icons.play_arrow, color: Colors.white),
                iconSize: 50,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: CameraLive()));
}
// import 'dart:math';
// import 'package:firebase_storage/firebase_storage.dart';
// import 'package:image/image.dart' as img;
// import 'package:flutter/material.dart';
// import 'package:camera/camera.dart';
// import 'package:flutter/rendering.dart';
// import 'package:flutter_vision/flutter_vision.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'dart:io';
// import 'package:google_ml_kit/google_ml_kit.dart';
// import 'package:path_provider/path_provider.dart';
// import 'dart:ui' as ui;
// import 'dart:typed_data';
//
// import 'package:permission_handler/permission_handler.dart';
//
// Future<void> saveResultsToFirebase(List<Map<String, dynamic>> results) async {
//   try {
//     final firestore = FirebaseFirestore.instance;
//     final detectionsCollection = firestore.collection('detections');
//
//     final data = {
//       'timestamp': FieldValue.serverTimestamp(),
//       'results': results, // Store the detection results
//     };
//
//     await detectionsCollection.add(data);
//
//     print("Results saved to Firebase successfully!");
//   } catch (e) {
//     print("Error saving results to Firebase: $e");
//   }
// }
//
// class CameraLive extends StatefulWidget {
//   const CameraLive({Key? key}) : super(key: key);
//
//   @override
//   State<CameraLive> createState() => _CameraLiveState();
// }
//
// class _CameraLiveState extends State<CameraLive> {
//   late CameraController controller;
//   late FlutterVision vision;
//   List<Map<String, dynamic>> yoloResults = [];
//   CameraImage? cameraImage;
//   bool isLoaded = false;
//   bool isDetecting = false;
//   bool isLicensePlateDetected = false;
//   double confidenceThreshold = 0.5;
//   late String screenshotPath;
//
//   late TextRecognizer textRecognizer;
//
//   final GlobalKey _boundaryKey = GlobalKey(); // Key for RepaintBoundary
//
//   @override
//   void initState() {
//     super.initState();
//     init();
//     textRecognizer = GoogleMlKit.vision.textRecognizer();
//   }
//
//   init() async {
//     final cameras = await availableCameras();
//     controller = CameraController(cameras[0], ResolutionPreset.high);
//     await controller.initialize();
//     vision = FlutterVision();
//     await loadYoloModel();
//
//     setState(() {
//       isLoaded = true;
//     });
//   }
//
//   @override
//   void dispose() {
//     controller.dispose();
//     vision.closeYoloModel();
//     textRecognizer.close();
//     super.dispose();
//   }
//
//   Future<void> loadYoloModel() async {
//     await vision.loadYoloModel(
//       labels: 'assets/classes.txt',
//       modelPath: 'assets/best_float32.tflite',
//       modelVersion: "yolov8",
//       numThreads: 4,
//       useGpu: true,
//     );
//   }
//
//   Future<void> yoloOnFrame(CameraImage cameraImage) async {
//     final result = await vision.yoloOnFrame(
//       bytesList: cameraImage.planes.map((plane) => plane.bytes).toList(),
//       imageHeight: cameraImage.height,
//       imageWidth: cameraImage.width,
//       iouThreshold: 0.4,
//       confThreshold: 0.4,
//       classThreshold: 0.5,
//     );
//     if (result.isNotEmpty) {
//       setState(() {
//         yoloResults = result;
//       });
//       for (var detection in result) {
//         if (detection['tag'] == 'license plate') {
//           await captureAndProcessRegion();
//           setState(() {
//             isLicensePlateDetected = true;
//           });
//           await saveResultsToFirebase(result);
//           stopDetection();
//           break;
//         }
//       }
//     }
//   }
//
//   Future<void> captureAndProcessRegion() async {
//     final renderObject = _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary;
//     if (renderObject != null) {
//       final image = await renderObject.toImage(pixelRatio: 3.0); // Get the image
//       final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
//       final buffer = byteData!.buffer.asUint8List();
//       final directory = await getTemporaryDirectory();
//       final filePath = '${directory.path}/screenshot.png';
//       final file = File(filePath);
//       await file.writeAsBytes(buffer);
//
//       setState(() {
//         screenshotPath = filePath;
//       });
//
//       // Get bounding box for license plate detection (assuming only one detection for simplicity)
//       final detection = yoloResults.firstWhere((result) => result['tag'] == 'license plate', orElse: () => {});
//       if (detection.isNotEmpty) {
//         // Extract the bounding box coordinates
//         final box = detection["box"];
//         final x = box[0]; // x1: left
//         final y = box[1]; // y1: top
//         final width = box[2] + box[0]; // x2 - x1: width
//         final height = box[3] + box[1]; // y2 - y1: height
//
//         // Crop the image based on the bounding box coordinates
//         await cropImage(file, x, y, width, height);
//       } else {
//         print("No license plate detected.");
//       }
//     }
//   }
//   Future<void> cropImage(File imageFile, double x, double y, double width, double height) async {
//     try {
//       final img.Image image = img.decodeImage(await imageFile.readAsBytes())!; // Decode image to a format that allows cropping
//
//       // Perform the crop
//       final img.Image croppedImage = img.copyCrop(image, x.toInt(), y.toInt(), width.toInt(), height.toInt());
//
//       // Save the cropped image as a temporary file
//       final directory = await getTemporaryDirectory();
//       final croppedFilePath = '${directory.path}/cropped_screenshot.png';
//       final croppedFile = File(croppedFilePath);
//       await croppedFile.writeAsBytes(img.encodePng(croppedImage)); // Save the image data locally
//
//       print("Cropped image temporarily saved at $croppedFilePath");
//
//       // Upload the cropped image to Firebase Storage
//       final firebaseStorage = FirebaseStorage.instance;
//       final storageRef = firebaseStorage.ref().child('cropped_images/cropped_screenshot_${DateTime.now().millisecondsSinceEpoch}.png');
//
//       final uploadTask = storageRef.putFile(croppedFile);
//
//       // Monitor upload progress (optional)
//       uploadTask.snapshotEvents.listen((event) {
//         print('Upload progress: ${(event.bytesTransferred / event.totalBytes) * 100}%');
//       });
//
//       final snapshot = await uploadTask.whenComplete(() {});
//       final downloadUrl = await snapshot.ref.getDownloadURL();
//
//       print("Cropped image uploaded to Firebase Storage. URL: $downloadUrl");
//
//       // Optionally update the state or notify the user
//       setState(() {
//         screenshotPath = downloadUrl; // Save the Firebase Storage URL instead of file path
//       });
//
//     } catch (e) {
//       print("Error cropping and uploading image: $e");
//     }
//   }
//   Future<void> recognizeTextFromImage(File imageFile) async {
//     try {
//       // Create an InputImage from the screenshot
//       final inputImage = InputImage.fromFilePath(imageFile.path);
//
//       // Process the image for text recognition
//       final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
//
//       // Extract the recognized text
//       String text = recognizedText.text;
//       print("Recognized text: $text");
//
//       // Optionally: Log the recognized text blocks and lines
//       for (TextBlock block in recognizedText.blocks) {
//         final Rect rect = block.boundingBox;
//         final List<Point<int>> cornerPoints = block.cornerPoints;
//         final String blockText = block.text;
//         final List<String> languages = block.recognizedLanguages;
//
//         for (TextLine line in block.lines) {
//           for (TextElement element in line.elements) {
//             print("Element text: ${element.text}");
//           }
//         }
//       }
//     } catch (e) {
//       print("Error recognizing text: $e");
//     }
//   }
//
//   Future<void> startDetection() async {
//     setState(() {
//       isDetecting = true;
//     });
//     await controller.startImageStream((image) async {
//       if (isDetecting) {
//         cameraImage = image;
//         await yoloOnFrame(image);
//       }
//     });
//   }
//
//   Future<void> stopDetection() async {
//     setState(() {
//       isDetecting = false;
//       yoloResults.clear();
//     });
//   }
//
//   List<Widget> displayBoxesAroundRecognizedObjects(Size screen) {
//     if (yoloResults.isEmpty) return [];
//
//     double factorX = screen.width / (cameraImage?.height ?? 1);
//     double factorY = screen.height / (cameraImage?.width ?? 1);
//
//     return yoloResults.map((result) {
//       double objectX = result["box"][0] * factorX;
//       double objectY = result["box"][1] * factorY;
//       double objectWidth = (result["box"][2] - result["box"][0]) * factorX;
//       double objectHeight = (result["box"][3] - result["box"][1]) * factorY;
//
//       return Positioned(
//         left: objectX,
//         top: objectY,
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Container(
//               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//               decoration: BoxDecoration(
//                 color: Colors.black54,
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               child: Text(
//                 "${result['tag']}",
//                 style: const TextStyle(
//                   color: Colors.white,
//                   fontSize: 16.0,
//                 ),
//               ),
//             ),
//             Container(
//               width: objectWidth,
//               height: objectHeight,
//               decoration: BoxDecoration(
//                 border: Border.all(color: Colors.pink, width: 2.0),
//                 borderRadius: BorderRadius.circular(10.0),
//               ),
//             ),
//           ],
//         ),
//       );
//     }).toList();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final Size size = MediaQuery.of(context).size;
//
//     if (!isLoaded) {
//       return const Scaffold(
//         body: Center(child: Text("Model not loaded, waiting for it")),
//       );
//     }
//
//     return Scaffold(
//       body: Stack(
//         fit: StackFit.expand,
//         children: [
//             RepaintBoundary(
//               key: _boundaryKey,
//               child: AspectRatio(
//                 aspectRatio: controller.value.aspectRatio,
//                 child: CameraPreview(controller),
//               ),
//             ),
//           ...displayBoxesAroundRecognizedObjects(size),
//           Positioned(
//             bottom: 75,
//             width: MediaQuery.of(context).size.width,
//             child: Container(
//               height: 80,
//               width: 80,
//               decoration: BoxDecoration(
//                 shape: BoxShape.circle,
//                 border: Border.all(width: 5, color: Colors.white),
//               ),
//               child: isDetecting
//                   ? IconButton(
//                 onPressed: stopDetection,
//                 icon: const Icon(Icons.stop, color: Colors.red),
//                 iconSize: 50,
//               )
//                   : IconButton(
//                 onPressed: startDetection,
//                 icon: const Icon(Icons.play_arrow, color: Colors.white),
//                 iconSize: 50,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// void main() {
//   WidgetsFlutterBinding.ensureInitialized();
//   runApp(const MaterialApp(home: CameraLive()));
// }



// import 'package:flutter/material.dart';
// import 'package:camera/camera.dart';
// import 'package:flutter_vision/flutter_vision.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
//
//
// Future<void> saveResultsToFirebase(List<Map<String, dynamic>> results) async {
//   try {
//     final firestore = FirebaseFirestore.instance;
//     final detectionsCollection = firestore.collection('detections');
//
//     final data = {
//       'timestamp': FieldValue.serverTimestamp(),
//       'results': results, // Store the detection results
//     };
//
//     await detectionsCollection.add(data);
//
//     print("Results saved to Firebase successfully!");
//   } catch (e) {
//     print("Error saving results to Firebase: $e");
//   }
// }
//
//
//
//
// class CameraLive extends StatefulWidget {
//   const CameraLive({Key? key}) : super(key: key);
//
//   @override
//   State<CameraLive> createState() => _CameraLiveState();
// }
//
// class _CameraLiveState extends State<CameraLive> {
//   late CameraController controller;
//   late FlutterVision vision;
//   List<Map<String, dynamic>> yoloResults = [];
//   List<dynamic> previousResult = [];
//
//   CameraImage? cameraImage;
//   bool isLoaded = false;
//   bool isDetecting = false;
//   double confidenceThreshold = 0.5;
//
//   @override
//   void initState() {
//     super.initState();
//     init();
//   }
//
//   init() async {
//     // Initialize the camera
//     final cameras = await availableCameras();
//     controller = CameraController(cameras[0], ResolutionPreset.high);
//     await controller.initialize();
//     vision = FlutterVision();
//
//     // Load the YOLO model
//     await loadYoloModel();
//
//     setState(() {
//       isLoaded = true;
//     });
//   }
//
//   @override
//   void dispose() {
//     controller.dispose();
//     vision.closeYoloModel();
//     super.dispose();
//   }
//
//   Future<void> loadYoloModel() async {
//     await vision.loadYoloModel(
//       labels: 'assets/classes.txt',
//       modelPath: 'assets/best_float32.tflite',
//       modelVersion: "yolov8",
//       numThreads: 4,
//       useGpu: true,
//     );
//   }
//
//   // Detect objects from camera frames
//   Future<void> yoloOnFrame(CameraImage cameraImage) async {
//     final result = await vision.yoloOnFrame(
//       bytesList: cameraImage.planes.map((plane) => plane.bytes).toList(),
//       imageHeight: cameraImage.height,
//       imageWidth: cameraImage.width,
//       iouThreshold: 0.4,
//       confThreshold: 0.4,
//       classThreshold: 0.5,
//     );
//     if (result.isNotEmpty) {
//       setState(() {
//         yoloResults = result;
//         previousResult = result;
//       });
//       for (var detection in result) {
//         if (detection['tag'] == 'license plate') {
//           print(result);
//         }
//       }
//       await saveResultsToFirebase(result);
//     }
//   }
//
//   // Start detection
//   Future<void> startDetection() async {
//     setState(() {
//       isDetecting = true;
//     });
//     await controller.startImageStream((image) async {
//       if (isDetecting) {
//         cameraImage = image;
//         await yoloOnFrame(image);
//       }
//     });
//   }
//
//   // Stop detection
//   Future<void> stopDetection() async {
//     setState(() {
//       isDetecting = false;
//       yoloResults.clear();
//     });
//   }
//
//   // Draw bounding boxes around detected objects
//   List<Widget> displayBoxesAroundRecognizedObjects(Size screen) {
//     if (yoloResults.isEmpty) return [];
//
//     double factorX = screen.width / (cameraImage?.height ?? 1);
//     double factorY = screen.height / (cameraImage?.width ?? 1);
//
//     return yoloResults.map((result) {
//       double objectX = result["box"][0] * factorX;
//       double objectY = result["box"][1] * factorY;
//       double objectWidth = (result["box"][2] - result["box"][0]) * factorX;
//       double objectHeight = (result["box"][3] - result["box"][1]) * factorY;
//
//       return Positioned(
//         left: objectX,
//         top: objectY,
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Container(
//               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//               decoration: BoxDecoration(
//                 color: Colors.black54,
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               child: Text(
//                 "${result['tag']}",
//                 style: const TextStyle(
//                   color: Colors.white,
//                   fontSize: 16.0,
//                 ),
//               ),
//             ),
//             Container(
//               width: objectWidth,
//               height: objectHeight,
//               decoration: BoxDecoration(
//                 border: Border.all(color: Colors.pink, width: 2.0),
//                 borderRadius: BorderRadius.circular(10.0),
//               ),
//             ),
//           ],
//         ),
//       );
//     }).toList();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final Size size = MediaQuery.of(context).size;
//
//     if (!isLoaded) {
//       return const Scaffold(
//         body: Center(child: Text("Model not loaded, waiting for it")),
//       );
//     }
//
//     return Scaffold(
//       body: Stack(
//         fit: StackFit.expand,
//         children: [
//           AspectRatio(
//             aspectRatio: controller.value.aspectRatio,
//             child: CameraPreview(controller),
//           ),
//           ...displayBoxesAroundRecognizedObjects(size),
//           Positioned(
//             bottom: 75,
//             width: MediaQuery.of(context).size.width,
//             child: Container(
//               height: 80,
//               width: 80,
//               decoration: BoxDecoration(
//                 shape: BoxShape.circle,
//                 border: Border.all(width: 5, color: Colors.white),
//               ),
//               child: isDetecting
//                   ? IconButton(
//                       onPressed: stopDetection,
//                       icon: const Icon(Icons.stop, color: Colors.red),
//                       iconSize: 50,
//                     )
//                   : IconButton(
//                       onPressed: startDetection,
//                       icon: const Icon(Icons.play_arrow, color: Colors.white),
//                       iconSize: 50,
//                     ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// void main() {
//   WidgetsFlutterBinding.ensureInitialized();
//   runApp(const MaterialApp(home: CameraLive()));
// }