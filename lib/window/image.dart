import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:mime/mime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../utils/dialog.dart';
import 'package:http_parser/http_parser.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'historique.dart';

dynamic uploadImage(String imagePath) async {
  var uri = Uri.parse('http://149.202.49.224:8001/uploadfile/');
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
      var responseData = await http.Response.fromStream(response);
      var dataDict = json.decode(responseData.body);
      return dataDict;
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

class ImageViewer extends StatefulWidget {
  final String imagePath;

  const ImageViewer({super.key, required this.imagePath});

  @override
  State<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer> {
  bool isUploading = false;
  bool isHisto = false;

  Future<ImageInfo> _loadImage(String imagePath) async {
    final Completer<ImageInfo> completer = Completer();
    final ImageStream stream = FileImage(File(imagePath)).resolve(const ImageConfiguration());
    final ImageStreamListener listener = ImageStreamListener((ImageInfo info, bool _) {
      completer.complete(info);
    });
    stream.addListener(listener);
    return completer.future;
  }

  /*dynamic uploadImagept(String imagePath) async {
    setState(() {
      isUploading = true;
    });
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
        var responseData = await http.Response.fromStream(response);
        var dataDict = json.decode(responseData.body);
        setState(() {
          isUploading = false;
        });
        return dataDict;
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
  }*/

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<ImageInfo>(
        future: _loadImage(widget.imagePath),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting || isUploading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          } else if (snapshot.hasError) {
            return const Center(
              child: Text('Erreur de chargement de l\'image'),
            );
          } else {
            isHisto = false;

            return Stack(
              children: [
                Center(
                  child: Image.file(
                    File(widget.imagePath),
                    fit: BoxFit.contain,
                  ),
                ),
                Positioned(
                  bottom: 20,
                  left: 20,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      isHisto = false;
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
                              imagePath: widget.imagePath,
                              onConfirm: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => ImageDetailsPage(imagePath: widget.imagePath, totalSum: 0.0, countDict: null),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      } else {
                        var dataDict = await uploadImage(widget.imagePath);
                        var filePath = dataDict['file_path'];
                        var totalSum = dataDict['total_sum'].toDouble();
                        Map<String, dynamic> countDict = dataDict['count'];
                        bool truc = false;
                        double somme = 0.0;
                        for(var count in countDict.entries) {
                          somme += count.value;
                        }
                        if(somme > 0.0) {
                          truc = true;
                        }

                        if(truc && !isHisto) {
                          await historiser(dataDict);
                          isHisto = true;
                        }
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => ImageDetailsPage(imagePath: filePath, totalSum: totalSum, countDict: countDict),
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

// -----------------------------
// Historisation
// -----------------------------
Future<void> historiser(Map<String, dynamic> dataHistorique) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();

  if(prefs.containsKey("nextIndex")) {
    int prefsKey = prefs.getInt("nextIndex")!;
    prefsKey += 1;
    prefs.setInt("nextIndex", prefsKey);
  } else {
    prefs.setInt("nextIndex", 1);
  }

  int nextIndex = prefs.getInt("nextIndex")!;

  final DateTime now = DateTime.now();
  final DateFormat formatter = DateFormat('yyyy-MM-dd H:mm');
  final String date = formatter.format(now);
  String titleHistoryCard = date;

  Map<String, dynamic> head = {
    "index": nextIndex,
    "title": titleHistoryCard,
    "image_url": dataHistorique['file_path']
  };
  Map<String, dynamic> tail = calculateDetails(dataHistorique);
  Map<String, dynamic> historique = {};
  historique.addAll(head);
  historique.addAll(tail);

  addNewItemToHistory(historique);
}

Future<void> addNewItemToHistory(Map<String, dynamic> newItem) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();

  // Récupérer la liste existante sous forme de chaîne JSON
  String? existingItemsJson = prefs.getString('historique');
  List<Map<String, dynamic>> itemsList;

  if (existingItemsJson != null) {
    // Convertir la chaîne JSON en liste d'objets si elle existe déjà
    itemsList = List<Map<String, dynamic>>.from(jsonDecode(existingItemsJson));
  } else {
    // Initialiser une nouvelle liste si aucune liste n'existe
    itemsList = [];
  }

  // Ajouter le nouvel objet à la liste
  itemsList.add(newItem);

  // Convertir la liste mise à jour en chaîne JSON
  String updatedItemsJson = jsonEncode(itemsList);

  // Sauvegarder la liste mise à jour dans SharedPreferences
  try {
    await prefs.setString('historique', updatedItemsJson);
  } on Exception catch (e) {
    print("une erreur est survenu: $e");
  }
}

Map<String, dynamic> calculateDetails(Map<String, dynamic> data) {
  // Extraire les totaux et les comptes généraux
  double totalSum = data['total_sum'];
  int countPieces = data['count']['count_pieces'];
  int countBillets = data['count']['count_billets'];
  double sumPieces = data['count']['sum_pieces'];
  double sumBillets = data['count']['sum_billets'];

  // Détail des articles
  List<Map<String, dynamic>> itemDetails = [];

  // Unité de prix pour chaque type de monnaie
  Map<String, double> unitPrices = {
    '1 centime': 0.01, '2 centimes': 0.02, '5 centimes': 0.05, '10 centimes': 0.10,
    '20 centimes': 0.20, '50 centimes': 0.50, '1 euro': 1.00, '2 euros': 2.00,
    '5 euros': 5.00, '10 euros': 10.00, '20 euros': 20.00, '50 euros': 50.00,
    '100 euros': 100.00, '200 euros': 200.00, '500 euros': 500.00
  };

  // Calculer les détails pour chaque type de monnaie
  data['count'].forEach((key, value) {
    if (value > 0 && unitPrices.containsKey(key)) {
      double unitPrice = unitPrices[key]!;
      double sum = unitPrice * value;
      itemDetails.add({
        'name': key,
        'price': '${unitPrice.toStringAsFixed(2)}€',
        'quantity': value,
        'somme': '${sum.toStringAsFixed(2)}€'
      });
    }
  });

  // Retourner le résultat formaté
  return {
    'total': '${totalSum.toStringAsFixed(2)}€',
    'nbr_pieces': countPieces.toString(),
    'total_pieces': '${sumPieces.toStringAsFixed(2)}€',
    'nbr_billets': countBillets.toString(),
    'total_billets': '${sumBillets.toStringAsFixed(2)}€',
    'items': itemDetails
  };
}


class ImageDetailsPage extends StatefulWidget {
  final String imagePath;
  final double totalSum;
  final dynamic countDict;
  const ImageDetailsPage({Key? key, required this.imagePath, required this.totalSum,  required this.countDict}) : super(key: key);
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

  Widget _retourButtonWidget() {
    return SafeArea(
        top: true,
        child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                child: IconButton(
                  onPressed: () {
                    navigatorKey.currentState?.push(
                      MaterialPageRoute(
                        builder: (context) => const HistoriquePageWidget()
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 30.0,
                  ),
                ),
              ),
            ])
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Center(
              child: RotatedBox(
                quarterTurns: 1, // Ajustez le nombre de quart de tours pour obtenir l'orientation souhaitée
                child: Image.network(
                  "http://149.202.49.224:8001/${widget.imagePath}",
                  fit: BoxFit.contain,
                  loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                  errorBuilder: (BuildContext context, Object exception, StackTrace? stackTrace) {
                    return const Text('Erreur lors du chargement de l\'image réseau');
                  },
                ),
              ),
            ),
          ),
          _retourButtonWidget(),
          Positioned.fill(
            child: DraggableScrollableSheet(
              controller: controller,
              initialChildSize: 0.1,
              minChildSize: 0.1,
              maxChildSize: 0.9,
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
                      padding: const EdgeInsets.only(top: 8.0),
                      children: [
                        const ListTile(
                          leading: Icon(Icons.info),
                          title: Text('Détails'),
                        ),
                        if (widget.countDict != null) ...[
                          ListTile(
                            leading: Icon(Icons.attach_money),
                            title: Text('Total'),
                            subtitle: Text("Somme: ${widget.totalSum.toStringAsFixed(2)}€"),
                          ),
                          ListTile(
                            leading: Icon(Icons.money_off),
                            title: Text("Nombre de pièces: ${widget.countDict["count_pieces"]}"),
                            subtitle: Text("Somme: ${widget.countDict["sum_pieces"]}"),
                          ),
                          ListTile(
                            leading: Icon(Icons.money_off),
                            title: Text("Nombre de billets: ${widget.countDict["count_billets"]}"),
                            subtitle: Text("Somme: ${widget.countDict["sum_billets"]}"),
                          ),
                          ListTile(
                            leading: Icon(Icons.check),
                            title: Text("Nombre de chèques: ${widget.countDict["count_cheques"]}"),
                            subtitle: Text('Somme: \$XXX.XX'),
                          ),
                          ListTile(
                            leading: Icon(Icons.receipt),
                            title: Text("Nombre de tickets de caisse: ${widget.countDict["count_tickets"]}"),
                            subtitle: Text('Somme: \$XXX.XX'),
                          ),
                        ],
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