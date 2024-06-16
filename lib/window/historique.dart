import 'dart:math' as math;
import 'package:cash_cash/entities/yolo.dart';
import 'package:cash_cash/views/home.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';

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

  @override
  void initState() {
    super.initState();

    items = [
      {'title': 'Événement 1', 'total': '35€', 'details': 'Détails de l\'événement 1'},
      {'title': 'Événement 2', 'total': '100€', 'details': 'Détails de l\'événement 2'},
      {'title': 'Événement 3', 'total': '6€', 'details': 'Détails de l\'événement 3'},
    ];

    titleController = TextEditingController();
  }

  @override
  void dispose() {
    titleController?.dispose();
    super.dispose();
  }

  // Cette méthode génère une couleur aléatoire parmi une liste prédéfinie
  Color getRandomColor() {
    List<Color> colors = [
      Colors.blue,
      Colors.redAccent,
      Colors.purple,
      Colors.orange,
      Colors.yellow,
    ];
    return colors[math.Random().nextInt(colors.length)];
  }

  Future<List<Map<String, dynamic>>> loadData() async {
    return items;
  }

  LinearGradient gradient_cashcash() {
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
          automaticallyImplyLeading: true,
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
                                            items[index]['title'] = titleController!.text;
                                            item['title'] = titleController!.text;
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
                                  ListTile(
                                    title: Text(item['details']),
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
                                            //item.removeAt(index);
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

  Widget burgerButton() {
    return SpeedDial(
      icon: Icons.menu,
      activeIcon: Icons.close,
      gradient: gradient_cashcash(),
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
            // TODO: rejoindre directement la galerie
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
