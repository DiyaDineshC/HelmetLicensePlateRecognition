// import 'dart:ui';

// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:helmet_license/HomeScreen/textOverlayPainter.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import 'package:image_picker/image_picker.dart';
// import 'dart:io';
// import 'package:google_ml_kit/google_ml_kit.dart';

// class ImageUploadScreen extends StatefulWidget {
//   @override
//   _ImageUploadScreenState createState() => _ImageUploadScreenState();
// }

// class _ImageUploadScreenState extends State<ImageUploadScreen> {
//   File? _image;
//   bool _isLoading = false;
//   List<dynamic> _detections = [];
//   String? _imageUrl;
//   String? _recognizedText;  // Add a string to store the recognized text

//   // Google ML Kit Text Recognizer
//   final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

//   // Function to pick an image
//   Future<void> pickImage() async {
//     final picker = ImagePicker();
//     final pickedFile = await picker.pickImage(source: ImageSource.gallery);

//     if (pickedFile != null) {
//       setState(() {
//         _image = File(pickedFile.path);
//       });
//     }
//   }

//   // Function to upload the image and get detection results from Flask server
//   Future<void> uploadImageAndDetect() async {
//     if (_image == null) return;

//     setState(() {
//       _isLoading = true;
//     });

//     try {
//       var uri = Uri.parse("http://192.168.1.6:5000/predict");

//       var request = http.MultipartRequest('POST', uri);
//       request.files.add(await http.MultipartFile.fromPath('image', _image!.path));

//       var response = await request.send();

//       if (response.statusCode == 200) {
//         var responseData = await response.stream.bytesToString();
//         var data = json.decode(responseData);

//         setState(() {
//           _imageUrl = data['image_url']; // The image URL with bounding boxes
//           _detections = data['detections'];
//         });

//         print('ImageURL: $_imageUrl');
//         print('Detections: $_detections');

//         // Perform text recognition for License Plates (if any)
//         await performTextRecognition(); // Add this line to ensure text recognition is done
//       } else {
//         print('Failed to upload image and get detection data');
//       }
//     } catch (e) {
//       print('Error: $e');
//     } finally {
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }

//   // Perform text recognition using Google ML Kit
//   Future<void> performTextRecognition() async {
//   if (_image == null) return;

//   final inputImage = InputImage.fromFile(_image!);

//   try {
//     final recognizedText = await textRecognizer.processImage(inputImage);

//     // Log the recognized text
//     print("Recognized Text: ${recognizedText.text}");

//     if (recognizedText.text.isNotEmpty) {
//       setState(() {
//         _recognizedText = recognizedText.text;
//       });
//     } else {
//       print("No text recognized");
//     }
//   } catch (e) {
//     print("Error during text recognition: $e");
//   }
// }


// Future<File?> cropImage(File imageFile, Rect boundingBox) async {
//   // Load image using image package
//   img.Image? image = img.decodeImage(await imageFile.readAsBytes());

//   // Get bounding box coordinates
//   int left = boundingBox.left.toInt();
//   int top = boundingBox.top.toInt();
//   int right = boundingBox.right.toInt();
//   int bottom = boundingBox.bottom.toInt();

//   // Crop the image
//   img.Image croppedImage = img.copyCrop(image!, left, top, right - left, bottom - top);

//   // Save the cropped image and return it
//   final croppedFile = File('${imageFile.parent.path}/cropped_image.jpg')..writeAsBytesSync(img.encodeJpg(croppedImage));
//   return croppedFile;
// }


//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(
//           'Upload Image and Detect',
//           style: TextStyle(
//             fontSize: 24.0,
//             fontWeight: FontWeight.bold,
//             fontFamily: GoogleFonts.habibi().fontFamily,
//             color: Color.fromARGB(255, 165, 52, 7),
//           ),
//           textAlign: TextAlign.center,
//         ),
//         backgroundColor: const Color.fromARGB(255, 242, 244, 246),
//         elevation: 0,
//       ),
//       body: Center(
//         child: SingleChildScrollView(
//           child: Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.center,
//               children: [
//                 _image == null
//                     ? Padding(
//                         padding: const EdgeInsets.only(top: 20.0),
//                         child: Text(
//                           'No image selected yet.',
//                           style: TextStyle(fontSize: 18, color: const Color.fromARGB(255, 73, 72, 72)),
//                         ),
//                       )
//                     : Container(
//                         width: MediaQuery.of(context).size.width - 32,
//                         height: 300,
//                         child: CustomPaint(
//                           painter: TextOverlayPainter(_image!, _detections),
//                         ),
//                       ),
//                 SizedBox(height: 20),
//                 ElevatedButton.icon(
//                   onPressed: pickImage,
//                   icon: Icon(Icons.image, size: 24),
//                   label: Text(
//                     'Pick Image',
//                     style: TextStyle(
//                       fontSize: 20.0,
//                       fontWeight: FontWeight.bold,
//                       fontFamily: GoogleFonts.habibi().fontFamily,
//                       color: Color.fromARGB(255, 20, 1, 79),
//                     ),
//                   ),
//                   style: ElevatedButton.styleFrom(
//                     padding: EdgeInsets.symmetric(vertical: 14, horizontal: 24),
//                     backgroundColor: const Color.fromARGB(255, 44, 237, 144),
//                     textStyle: TextStyle(
//                       fontSize: 18,
//                       fontFamily: GoogleFonts.habibi().fontFamily,
//                       color: const Color.fromARGB(255, 201, 10, 10),
//                     ),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(10),
//                     ),
//                   ),
//                 ),
//                 SizedBox(height: 16),
//                 ElevatedButton.icon(
//                   onPressed: uploadImageAndDetect,
//                   icon: Icon(Icons.upload_file, size: 24),
//                   label: Text(
//                     'Upload Image',
//                     style: TextStyle(
//                       fontSize: 20.0,
//                       fontWeight: FontWeight.bold,
//                       fontFamily: GoogleFonts.habibi().fontFamily,
//                       color: Color.fromARGB(255, 20, 1, 79),
//                     ),
//                   ),
//                   style: ElevatedButton.styleFrom(
//                     padding: EdgeInsets.symmetric(vertical: 14, horizontal: 24),
//                     backgroundColor: const Color.fromARGB(255, 255, 207, 15),
//                     textStyle: TextStyle(
//                       fontSize: 18,
//                       fontFamily: GoogleFonts.habibi().fontFamily,
//                       color: const Color.fromARGB(255, 201, 10, 10),
//                     ),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(10),
//                     ),
//                   ),
//                 ),
//                 SizedBox(height: 20),
//                 _isLoading
//                     ? CircularProgressIndicator()
//                     : SizedBox(),
//                 _recognizedText != null
//                     ? Container(
//                         margin: EdgeInsets.only(top: 20.0),
//                         padding: EdgeInsets.all(16.0),
//                         decoration: BoxDecoration(
//                           border: Border.all(color: Colors.black),
//                           borderRadius: BorderRadius.circular(10),
//                           color: Colors.white,
//                         ),
//                         child: Text(
//                           _recognizedText!,
//                           style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                         ),
//                       )
//                     : SizedBox(),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
