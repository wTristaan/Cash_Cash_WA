import 'dart:convert';
import 'package:cash_cash/entities/yolo.dart';
import 'package:cash_cash/views/home.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';

class HistoriquePageWidget extends StatefulWidget {
  const HistoriquePageWidget({super.key});

  @override
  State<HistoriquePageWidget> createState() => _HistoriquePageWidgetState();
}

class _HistoriquePageWidgetState extends State<HistoriquePageWidget> {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  bool isOptionsExpanded = false;
  // Cette liste contient les éléments de l'historique
  late List<Map<String, dynamic>> items;
  TextEditingController? titleController;  // Contrôleur pour le champ de texte

  // Cet index garde la trace de l'élément actuellement en mode édition
  int? editingIndex;

  void getHistorique() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if(prefs.containsKey("historique") && prefs.getString("historique")!.isNotEmpty) {
      setState(() {
        items = List<Map<String, dynamic>>.from(jsonDecode(prefs.getString("historique")!));
      });
    } else {
      setState(() {
        items = [];
      });
    }
  }

  Future<void> eraseStoredData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    await prefs.remove("historique");
    await prefs.remove("nextIndex");
  }

  @override
  void initState() {
    super.initState();
    //eraseStoredData();
    setState(() {
      getHistorique();
    });

    titleController = TextEditingController();
  }

  @override
  void dispose() {
    titleController?.dispose();
    items = [];
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> loadData() async {
    //getHistorique();

    return items;
  }

  LinearGradient gradientCashcash() {
    return const LinearGradient(
      colors: [
        Color(0xFF4B39EF),
        Color(0xFFD6587F)
      ],
      stops: [0, 1],
      begin: AlignmentDirectional(0.87, -1),
      end: AlignmentDirectional(-0.87, 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: Colors.white,
        appBar: AppBar(
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF4B39EF),
                  Color(0xFFD6587F)
                ],
                stops: [0, 1],
                begin: AlignmentDirectional(0.87, -1),
                end: AlignmentDirectional(-0.87, 1),
              ),
            ),
          ),
          automaticallyImplyLeading: false,
          title: const Text(
            'Historique',
            style: TextStyle(
              fontFamily: 'Outfit',
              color: Colors.white,
              fontSize: 22,
              letterSpacing: 0,
            ),
          ),
          centerTitle: false,
          elevation: 4,
        ),
        body: SafeArea(
          top: true,
          child: Align(
            alignment: const AlignmentDirectional(1, 1),
            child: Stack(
              children: [
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: loadData(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(child: Text("Erreur lors du chargement des données"));
                    } else if (snapshot.data!.isEmpty) {
                      return const Center(child: Text("L'historique est vide"));
                    } else {
                      return ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          var item = items[index];
                          List<dynamic> itemsList = item['items']; // Accès à la liste 'items'
                          // Si l'index actuel est l'index d'édition, montrer le formulaire de modification du titre
                          if (index == editingIndex) {
                            titleController?.text = item['title'];  // Définir la valeur initiale du TextField

                            return Card(
                              margin: const EdgeInsets.all(8.0),
                              child: ListTile(
                                title: TextField(
                                  controller: titleController,
                                  autofocus: true,
                                  decoration: const InputDecoration(
                                    hintText: "Entrez un nouveau titre",
                                  ),
                                ),
                                trailing: Wrap(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.check),
                                      onPressed: () {
                                        // Valider les changements
                                        setState(() {
                                          if (titleController!.text.isNotEmpty == true) {
                                            String modifiedTitle = titleController!.text;
                                            items[index]['title'] = modifiedTitle;
                                            item['title'] = modifiedTitle;
                                            modifyHistorique(item['index'], modifiedTitle);
                                            editingIndex = null;
                                          }
                                        });
                                      },
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.close),
                                      onPressed: () {
                                        // Annuler les changements
                                        setState(() {
                                          editingIndex = null;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                        else {
                            return Card(
                              margin: EdgeInsets.all(8.0),
                              child: ExpansionTile(
                                title: Text(item['title']),
                                subtitle: Text("total : ${item['total']}"),
                                children: <Widget>[
                                  // image de la détection
                                  Container(
                                    width: double.infinity, // Assure que l'image prend la largeur complète de la card
                                    child: Image.network(
                                      "http://149.202.49.224:8001/${item['image_url']}", // Remplacez 'image_url' par la clé réelle dans item qui contient l'URL de l'image
                                      fit: BoxFit.cover, // Assure que l'image couvre l'espace disponible sans perdre ses proportions
                                    ),
                                  ),
                                  ListTile(
                                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10.0),
                                    title: Text(
                                        "Le montant détecté est de : ${item['total']}\n"
                                        "Le nombre de pièce détecté est de : ${item['nbr_pieces']}\n"
                                        "Le montant total de ces pièces est de : ${item['total_pieces']}\n"
                                        "Le nombre de billet détecté est de : ${item['nbr_billets']}\n"
                                        "Le montant total de ces billets est de : ${item['total_billets']}\n"
                                        "Voici le détails de la détection :"
                                    ),
                                  ),
                                  Container(
                                    width: double.infinity, // Assure que le container prend toute la largeur disponible
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: itemsList.map<Widget>((detailItem) {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10.0), // Appliquer un padding horizontal
                                          child: Text("${detailItem['quantity']}*${detailItem['name']} = ${detailItem['somme']}"),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      TextButton.icon(
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.white,
                                          backgroundColor: Colors.redAccent,
                                        ),
                                        onPressed: () {
                                          // Implémenter la suppression de l'élément courant
                                          setState(() {
                                            deleteHistorique(item["index"]);
                                            items.removeAt(index);
                                            SharedPreferences.getInstance().then((value) => print(value.getString("Historique")));
                                          });
                                        },
                                        icon: const Icon(Icons.delete),
                                        label: const Text("Effacer"),
                                      ),
                                      TextButton.icon(
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.white,
                                          backgroundColor: Colors.blueAccent,
                                        ),
                                        onPressed: () {
                                          // Passer en mode édition de l'élément courant
                                          setState(() {
                                            editingIndex = index;
                                          });
                                        },
                                        icon: const Icon(Icons.edit),
                                        label: const Text("Modifier"),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            );
                          }
                        },
                      );
                    }
                  },
                ),
                Align(
                  alignment: const AlignmentDirectional(0.90, 0.9),
                  child: burgerButton(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> modifyHistorique(int index, String title) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Récupérer la liste existante sous forme de chaîne JSON
    String? existingItemsJson = prefs.getString('historique');

    List<Map<String, dynamic>> itemsList = List<Map<String, dynamic>>.from(jsonDecode(existingItemsJson!));
    for(var element in itemsList) {
      element.forEach((key, value) {
        if(element["index"] == index) {
          element['title'] = title;
        }
      });
    }

    String updatedItemsJson = jsonEncode(itemsList);
    prefs.setString("historique", updatedItemsJson);
  }

  Future<void> deleteHistorique(int index) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? existingItemsJson = prefs.getString('historique');

    List<Map<String, dynamic>> itemsList = List<Map<String, dynamic>>.from(jsonDecode(existingItemsJson!));
    itemsList.removeWhere((element) => element['index'] == index);

    int nextIndex = prefs.getInt("nextIndex")!;
    nextIndex -= 1;

    String updatedItemsJson = jsonEncode(itemsList);
    prefs.setInt("nextIndex", nextIndex);
    prefs.setString("historique", updatedItemsJson);
  }

  Widget burgerButton() {
    return SpeedDial(
      icon: Icons.menu,
      activeIcon: Icons.close,
      gradient: gradientCashcash(),
      gradientBoxShape: BoxShape.circle,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      activeBackgroundColor: Colors.transparent,
      activeForegroundColor: Colors.white,
      visible: true,
      closeManually: false,
      curve: Curves.bounceIn,
      buttonSize: const Size(56.0, 56.0),
      children: [
        SpeedDialChild(
          child: const Icon(Icons.photo_outlined),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          label: 'Depuis la galerie',
          labelStyle: const TextStyle(fontSize: 18.0),
          onTap: () {
            YoloVideo(model: YoloModel()).openGallery();
          },
        ),
        SpeedDialChild(
          child: const Icon(Icons.camera),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          label: 'Prendre en photo',
          labelStyle: const TextStyle(fontSize: 18.0),
          onTap: () async {
            navigatorKey.currentState?.push(
              MaterialPageRoute(builder: (context) => YoloVideo(model: YoloModel())),
            );
          },
        ),
      ],
    );
  }
}
