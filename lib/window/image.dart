import 'dart:async';

import 'package:flutter/material.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../utils/dialog.dart';
import 'package:http_parser/http_parser.dart';
import 'package:fluttertoast/fluttertoast.dart';

Future<void> uploadImage(String imagePath) async {
  var uri = Uri.parse('http://149.202.49.224:8000/uploadfile/');
  var request = http.MultipartRequest('POST', uri);

  var mimeType = lookupMimeType(imagePath);
  if (mimeType == null) {
    Fluttertoast.showToast(
        msg: "Erreur : Lors de l'envoi de l'image",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 4,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0
    );
    return;
  }

  var file = await http.MultipartFile.fromPath(
    'file',
    imagePath,
    contentType: MediaType.parse(mimeType),
  );
  request.files.add(file);

  try {
    var response = await request.send();
    if (response.statusCode == 200) {
      Fluttertoast.showToast(
          msg: "L'image à bien été envoyée à notre serveur",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.TOP,
          timeInSecForIosWeb: 4,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 16.0
      );

    } else {
      Fluttertoast.showToast(
        msg: 'Erreur : ${response.statusCode}',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 4,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0
      );
    }
  } catch (e) {
    Fluttertoast.showToast(
        msg: "Erreur lors de l'envoi de l'image : $e",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 4,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0);
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
  late DraggableScrollableController controller;
  bool sheetIsExpanded = false;


  @override
  void initState() {
    super.initState();
    controller = DraggableScrollableController();

  }

  @override
  void dispose() {
    _animationController.dispose();
    controller.dispose();
    super.dispose();
  }

  void _toggleSheet() {
    final double targetSize = sheetIsExpanded ? 0.1 : 1.0;
    controller.animateTo(
      targetSize,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    sheetIsExpanded = !sheetIsExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.file(
              File(widget.imagePath),
              fit: BoxFit.contain,
            ),
          ),
          Positioned.fill(
            child: DraggableScrollableSheet(
              controller: controller,
              initialChildSize: 0.1,
              minChildSize: 0.1,
              maxChildSize: 1,
              builder: (BuildContext context, ScrollController scrollController) {
                return GestureDetector(
                  onTap: _toggleSheet,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30.0),
                        topRight: Radius.circular(30.0),
                      ),
                    ),
                    child: ListView(
                      controller: scrollController,
                      children: [
                        Transform.translate(
                          offset: const Offset(0, -20), // Déplacez le ListTile vers le haut de 10 pixels
                          child: const ListTile(
                            contentPadding: EdgeInsets.symmetric(vertical: 4.0, horizontal: 15.0),
                            leading: Icon(Icons.info),
                            title: Text('Détails'),
                          ),
                        ),
                        const ListTile(
                          leading: Icon(Icons.attach_money),
                          title: Text('Nombre de pièces'),
                          subtitle: Text('Somme: \$XXX.XX'),
                        ),
                        const ListTile(
                          leading: Icon(Icons.money_off),
                          title: Text('Nombre de billets'),
                          subtitle: Text('Somme: \$XXX.XX'),
                        ),
                        const ListTile(
                          leading: Icon(Icons.check),
                          title: Text('Nombre de chèques'),
                          subtitle: Text('Somme: \$XXX.XX'),
                        ),
                        const ListTile(
                          leading: Icon(Icons.receipt),
                          title: Text('Nombre de tickets de caisse'),
                          subtitle: Text('Somme: \$XXX.XX'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}