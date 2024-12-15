import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ViolationHistoryScreen extends StatefulWidget {
  @override
  _ViolationHistoryScreenState createState() => _ViolationHistoryScreenState();
}

class _ViolationHistoryScreenState extends State<ViolationHistoryScreen> {
  late FirebaseFirestore _firestore;
  late CollectionReference _violationsCollection;
  bool _isLoading = true;
  List<Map<String, dynamic>> _violations = [];

  @override
  void initState() {
    super.initState();
    _firestore = FirebaseFirestore.instance;
    _violationsCollection = _firestore.collection('violations');
    _loadViolations();
  }

  // Fetch violations from Firestore
  Future<void> _loadViolations() async {
    try {
      QuerySnapshot querySnapshot = await _violationsCollection.orderBy('timestamp', descending: true).get();
      setState(() {
        _violations = querySnapshot.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading violations: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Store violation data when label is 'no helmet'
  Future<void> storeViolationData(String label, String licensePlate, String imageUrl, Map<String, dynamic> rect) async {
  print('Storing violation data...');
  if (label == 'no helmet') {
    try {
      await _violationsCollection.add({
        'label': label,
        'license_plate': licensePlate,
        'image_url': imageUrl,
        'rect': rect,
        'timestamp': FieldValue.serverTimestamp(),
      });
      print('Violation stored successfully');
    } catch (e) {
      print('Error storing violation: $e');
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Violation History'),
        backgroundColor: Colors.blueAccent,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _violations.isEmpty
              ? Center(child: Text('No violations found'))
              : ListView.builder(
                  itemCount: _violations.length,
                  itemBuilder: (context, index) {
                    final violation = _violations[index];
                    return Card(
                      margin: EdgeInsets.all(8),
                      child: ListTile(
                        contentPadding: EdgeInsets.all(16),
                        title: Text(
                          'Violation: ${violation['label']}',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('License Plate: ${violation['license_plate']}'),
                            SizedBox(height: 8),
                            Text('Rect Coordinates: ${violation['rect'].toString()}'),
                            SizedBox(height: 8),
                            violation['image_url'] != null
                                ? Image.network(
                                    violation['image_url'],
                                    width: MediaQuery.of(context).size.width - 32,
                                    height: 200,
                                    fit: BoxFit.cover,
                                  )
                                : Container(),
                            SizedBox(height: 8),
                            Text(
                              'Date: ${violation['timestamp'] != null ? violation['timestamp'].toDate() : 'N/A'}',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
