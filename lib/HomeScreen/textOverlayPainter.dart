// import 'dart:io';
// import 'package:flutter/material.dart';

// class TextOverlayPainter extends CustomPainter {
//   final File image;
//   final List<dynamic> detections;

//   TextOverlayPainter(this.image, this.detections);

//   @override
//   void paint(Canvas canvas, Size size) {
//     final Paint paint = Paint()
//       ..color = Colors.red
//       ..style = PaintingStyle.fill;

//     final imageWidth = size.width;
//     final imageHeight = size.height;

//     // Load the image as a picture for drawing
//     final imageProvider = FileImage(image);
//     final imageSize = Size(imageWidth, imageHeight);

//     imageProvider.resolve(ImageConfiguration()).addListener(
//       ImageStreamListener((ImageInfo info, bool sync) {
//         canvas.drawImage(info.image, Offset(0, 0), paint);

//         // Draw the detected text on the image
//         for (var detection in detections) {
//           String text = detection['license_plate_text'] ?? '';
//           double x = detection['x1'];
//           double y = detection['y1'];
//           TextSpan span = TextSpan(
//             text: text,
//             style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
//           );
//           TextPainter textPainter = TextPainter(
//             text: span,
//             textDirection: TextDirection.ltr,
//           );
//           textPainter.layout();
//           textPainter.paint(canvas, Offset(x, y));
//         }
//       }),
//     );
//   }

//   @override
//   bool shouldRepaint(covariant CustomPainter oldDelegate) {
//     return false;
//   }
// }
