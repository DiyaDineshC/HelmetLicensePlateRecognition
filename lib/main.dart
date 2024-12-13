import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:helmet_license/HomeScreen/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();  // Ensures the app is initialized
  await Firebase.initializeApp();  // Initialize Firebase

  runApp(MyApp());
  try {
  await Firebase.initializeApp();
} catch (e) {
  print('Firebase initialization error: $e');
}

}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Firebase',
      theme: ThemeData(primarySwatch: Colors.blue),
      home:HomeScreen(),  // Your main app screen
    );
  }
}



class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _dataController = TextEditingController();
  final CollectionReference _collection = FirebaseFirestore.instance.collection('dataCollection');

  Future<void> addItem() async {
    if (_dataController.text.isNotEmpty) {
      await _collection.add({'data': _dataController.text});
      _dataController.clear();
    }
  }

  Future<void> updateItem(String docId, String newData) async {
    await _collection.doc(docId).update({'data': newData});
  }

  Future<void> deleteItem(String docId) async {
    await _collection.doc(docId).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Flutter-Firebase CRUD')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _dataController,
              decoration: InputDecoration(labelText: 'Enter Data'),
            ),
          ),
          ElevatedButton(onPressed: addItem, child: Text('Add Data')),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _collection.snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }
                return ListView(
                  children: snapshot.data!.docs.map((doc) {
                    String data = doc['data'];
                    return ListTile(
                      title: Text(data),
                      trailing: IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () => deleteItem(doc.id),
                      ),
                      onTap: () {
                        _dataController.text = data;
                        showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: Text('Edit Data'),
                              content: TextField(
                                controller: _dataController,
                              ),
                              actions: [
                                ElevatedButton(
                                  onPressed: () {
                                    updateItem(doc.id, _dataController.text);
                                    Navigator.pop(context);
                                  },
                                  child: Text('Save'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}



// import 'package:flutter/material.dart';
// import 'package:helmet_license/MySplashScreen.dart';

// import 'package:camera/camera.dart';

// late List<CameraDescription> cameras;

// Future<void> main() async {

//   WidgetsFlutterBinding.ensureInitialized();
//   cameras = await availableCameras();
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   // This widget is the root of your application.
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Yolo Object Detection and License Plate Recognition',
//       home: MySplashPage(),
//     );
//   }
// }


