import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ImageUploadScreen extends StatefulWidget {
  @override
  _ImageUploadScreenState createState() => _ImageUploadScreenState();
}

class _ImageUploadScreenState extends State<ImageUploadScreen> {
  File? _image;
  bool _isLoading = false;
  List<dynamic> _detections = [];
  String? _imageUrl;

  // Function to pick an image
  Future<void> pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  // Function to upload the image and get detection results from Flask server
  Future<void> uploadImageAndDetect() async {
    if (_image == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Send image to Flask server for processing
      var uri = Uri.parse("http://192.168.1.5:5000/predict");

      var request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('image', _image!.path));

      var response = await request.send();

      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        var data = json.decode(responseData);

        // Get the image URL and detections
        setState(() {
          _imageUrl = data['image_url']; // The image URL with bounding boxes
          _detections = data['detections'];
        });

        // Display the detected image (optional: if you want to display the output image)
        print('ImageURL: $_imageUrl');
        print('Detections: $_detections');
      } else {
        print('Failed to upload image and get detection data');
      }
    } catch (e) {
      print('Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Upload Image and Detect'),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
      ),
      body: SingleChildScrollView( // Wrapping the body with SingleChildScrollView
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _image == null
                  ? Padding(
                      padding: const EdgeInsets.only(top: 20.0),
                      child: Text(
                        'No image selected.',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        _image!,
                        width: MediaQuery.of(context).size.width - 32, // Constrain the image width
                        height: 300,
                        fit: BoxFit.contain, // Ensure the whole image is visible
                      ),
                    ),
              SizedBox(height: 20),
              ElevatedButton.icon(
  onPressed: pickImage,
  icon: Icon(Icons.image, size: 24),
  label: Text('Pick Image'),
  style: ElevatedButton.styleFrom(
    padding: EdgeInsets.symmetric(vertical: 14, horizontal: 24),
    backgroundColor: Colors.blueAccent,
    textStyle: TextStyle(
      fontSize: 18,
      fontFamily: 'Roboto',  // Custom font
      color: const Color.fromARGB(255, 201, 10, 10),  // Button text color (white in this case)
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    ),
  ),
),

              SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: uploadImageAndDetect,
                icon: Icon(Icons.upload_file, size: 24),
                label: Text('Upload and Detect'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 14, horizontal: 24), backgroundColor: Colors.green,
                  textStyle: TextStyle(
                    fontSize: 18,
                    fontFamily: 'Roboto',  // Custom font
                    color: const Color.fromARGB(255, 213, 6, 6),  // Button text color
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              SizedBox(height: 20),
              _isLoading
                  ? CircularProgressIndicator()
                  : SizedBox(),
              _detections.isNotEmpty
                  ? ListView.builder(
                      shrinkWrap: true,  // This makes the list scrollable without expanding
                      physics: NeverScrollableScrollPhysics(),  // Prevent scrolling inside this list
                      itemCount: _detections.length,
                      itemBuilder: (context, index) {
                        var detection = _detections[index];
                        return Card(
                          margin: EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${detection['label']}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Rect: x: ${detection['rect']['x']}, y: ${detection['rect']['y']}, w: ${detection['rect']['w']}, h: ${detection['rect']['h']}',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    )
                  : SizedBox(),
              // Display the processed image with bounding boxes if available
              _imageUrl != null
                  ? Padding(
                      padding: const EdgeInsets.only(top: 20.0),
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            _imageUrl!,
                            width: MediaQuery.of(context).size.width - 32, // Constrain the image width
                            height: 300,
                            fit: BoxFit.contain, // Ensure the whole image is visible
                          ),
                        ),
                      ),
                    )
                  : SizedBox(),
            ],
          ),
        ),
      ),
    );
  }
}
