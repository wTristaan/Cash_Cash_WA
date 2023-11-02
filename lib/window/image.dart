import 'dart:async';

import 'package:flutter/material.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../utils/dialog.dart';
import '../utils/painter.dart';
import 'package:http_parser/http_parser.dart';

Future<void> uploadImage(String imagePath) async {
  var uri = Uri.parse('http://149.202.49.224:8000/uploadfile/');
  var request = http.MultipartRequest('POST', uri);

  var mimeType = lookupMimeType(imagePath);
  if (mimeType == null) {
    print('Cannot determine MIME type for the image.');
    return;
  }

  var file = await http.MultipartFile.fromPath('file', imagePath, contentType: MediaType.parse(mimeType));
  request.files.add(file);

  try {
    var response = await request.send();
    if (response.statusCode == 200) {
      print('Image uploaded successfully');
    } else {
      print('Failed to upload image. Status code: ${response.statusCode}');
    }
  } catch (e) {
    print('Error uploading image: $e');
  }
}

class ImageViewer extends StatelessWidget {
  final String imagePath;
  const ImageViewer({super.key, required this.imagePath});

  Future<ImageInfo> _loadImage(String imagePath) async {
    final Completer<ImageInfo> completer = Completer();
    final ImageStream stream = FileImage(File(imagePath)).resolve(const ImageConfiguration());
    final ImageStreamListener listener = ImageStreamListener((ImageInfo info, bool _) {
      completer.complete(info);
    });
    stream.addListener(listener);
    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<ImageInfo>(
        future: _loadImage(imagePath),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          } else if (snapshot.hasError) {
            return const Center(
              child: Text('Erreur de chargement de l\'image'),
            );
          } else {
            return Stack(
              children: [
                Center(
                  child: Image.file(
                    File(imagePath),
                    fit: BoxFit.contain,
                  ),
                ),
                Positioned(
                  bottom: 20,
                  left: 20,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('Reprendre'),
                  ),
                ),
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: ElevatedButton(
                    onPressed: () async {
                      SharedPreferences prefs = await SharedPreferences.getInstance();
                      bool? alreadyConfirmed = prefs.getBool('confirmed');

                      if (alreadyConfirmed == null) {
                        showDialog(
                          context: navigatorKey.currentContext!,
                          builder: (BuildContext context) {
                            return ConfirmDialog(
                              imagePath: imagePath,
                              onConfirm: () {
                                Navigator.of(context).pop();
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => ImageDetailsPage(imagePath: imagePath),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      } else {
                        if(alreadyConfirmed){
                          uploadImage(imagePath);
                        }
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => ImageDetailsPage(imagePath: imagePath),
                          ),
                        );
                      }
                    },
                    child: const Text('Valider'),
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  }
}

class ImageDetailsPage extends StatefulWidget {
  final String imagePath;
  const ImageDetailsPage({Key? key, required this.imagePath}) : super(key: key);
  @override
  State<ImageDetailsPage> createState() => _ImageDetailsPageState();
}

class _ImageDetailsPageState extends State<ImageDetailsPage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0, end: 10).animate(_animationController)
      ..addListener(() {
        setState(() {});
      });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Image.file(
                  File(widget.imagePath),
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: MediaQuery.of(context).size.height,
                ),
                Padding(
                  padding: EdgeInsets.only(bottom: _animation.value + 10),
                  child: const ArrowIcon(),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(16.0),
              child: const Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.attach_money),
                    title: Text('Nombre de pièces'),
                    subtitle: Text('Somme: \$XXX.XX'),
                  ),
                  ListTile(
                    leading: Icon(Icons.money_off),
                    title: Text('Nombre de billets'),
                    subtitle: Text('Somme: \$XXX.XX'),
                  ),
                  ListTile(
                    leading: Icon(Icons.check),
                    title: Text('Nombre de chèques'),
                    subtitle: Text('Somme: \$XXX.XX'),
                  ),
                  ListTile(
                    leading: Icon(Icons.receipt),
                    title: Text('Nombre de tickets de caisse'),
                    subtitle: Text('Somme: \$XXX.XX'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}