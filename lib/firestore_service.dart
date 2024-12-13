import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final CollectionReference _detections = FirebaseFirestore.instance.collection('detections');

  Future<void> addDetection(String licensePlate, String imageUrl) {
    return _detections.add({
      'license_plate': licensePlate,
      'image_url': imageUrl,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
