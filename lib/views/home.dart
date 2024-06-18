import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image/image.dart' as imglib;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_pytorch/pigeon.dart';
import 'package:flutter_pytorch/flutter_pytorch.dart';
import '../main.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../entities/yolo.dart';
import '../window/image.dart';
/*
* LA PARTIE COMMENTEE FAIT PARTIE DU CODE DE LA DETECTION SUR UNE PHOTO, VOUS POUVEZ L'ENLEVER SI VOUS VOULEZ
*/

enum Options { none, imagev8, frame }
late List<CameraDescription> cameras;

class StartApp extends StatefulWidget {
  const StartApp({super.key});
  @override
  State<StartApp> createState() => _MyAppState();
}

class _MyAppState extends State<StartApp> {
  Options option = Options.none;
  YoloModel model = YoloModel();


  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() async {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: task(option),
      floatingActionButton: SpeedDial(
        icon: Icons.menu,
        activeIcon: Icons.close,
        backgroundColor: Colors.black12,
        foregroundColor: Colors.white,
        activeBackgroundColor:
        Colors.deepPurpleAccent,
        activeForegroundColor: Colors.white,
        visible: true,
        closeManually: false,
        curve: Curves.bounceIn,
        overlayColor: Colors.black,
        overlayOpacity: 0.5,
        buttonSize: const Size(56.0, 56.0),
        children: [
          SpeedDialChild(
            child: const Icon(Icons.video_call),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            label: 'Yolo on Frame',
            labelStyle: const TextStyle(fontSize: 18.0),
            onTap: () {
              setState(() {
                option = Options.frame;
              });
            },
          ),
          SpeedDialChild(
            child: const Icon(Icons.camera),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            label: 'YoloV8 on Image',
            labelStyle: const TextStyle(fontSize: 18.0),
            onTap: () {
              setState(() {
                option = Options.imagev8;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget task(Options option) {
    if (option == Options.frame) {
      return YoloVideo(model: model);
    }
    if (option == Options.imagev8) {
      //return YoloImageV8(model: model);
    }
    return const Center(child: Text("Choose Task"));
  }
}

class YoloVideo extends StatefulWidget {
  final YoloModel model;
  const YoloVideo({super.key, required this.model});

  goToPreview(image) async {
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => ImageViewer(imagePath: image.path),
      ),
    );
  }

  Future<void> openGallery() async {
    var status = await Permission.photos.request();
    if (!status.isGranted) {
      status = await Permission.storage.request();
    }
    if (status.isGranted) {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        goToPreview(pickedFile);
      }else{
        Fluttertoast.showToast(
            msg: "Aucune image chargée",
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.TOP,
            timeInSecForIosWeb: 4,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            fontSize: 16.0
        );
      }
    }
  }

  @override
  State<YoloVideo> createState() => _YoloVideoState();
}

class _YoloVideoState extends State<YoloVideo> {
  String? _imagePrediction;
  List? _prediction;
  File? _image;
  List<ResultObjectDetection?> objDetect = [];
  ClassificationModel? _imageModel;
  late ModelObjectDetection _objectModel;
  bool isCams = false;
  bool camsPermissionIsGranted = false;
  bool _isFlashOn = false;
  late IconData _flashIcon = Icons.flash_off;
  bool isTaking = false;
  late XFile pic ;
  late ImagePicker _picker;
  late CameraController controller;
  late List<Map<String, dynamic>> yoloResults;
  CameraImage? cameraImage;
  bool isLoaded = false;
  bool isDetecting = false;
  //late ModelObjectDetection _objectModel;
  bool isBusy = false;
  bool isgranted = false;
  late List<Map<String, dynamic>> result = [];
  late double factorX;
  late double factorY;
  Color colorPick = const Color.fromARGB(255, 50, 233, 30);
  late imglib.Image emptyImage;
  int countFrame = 0;
  List<String> classes = [
    "1 centime",
    "2 centimes",
    "5 centimes",
    "10 centimes",
    "20 centimes",
    "50 centimes",
    "1 euro",
    "2 euros",
    "5 euros",
    "10 euros",
    "20 euros",
    "50 euros",
    "100 euros",
    "200 euros",
    "500 euros",
    "Cheques",
    "Tickets de caisse",
    "tickets de caisse"
  ];
  String cachePath = "";

  @override
  void initState() {
    super.initState();
    _picker = ImagePicker();
    init();
  }

  init() async {
    cameras = await availableCameras();
    controller = CameraController(
      cameras[0],
      ResolutionPreset.high,
      enableAudio: false,
    );
    controller.initialize().then((value) {
      loadYoloModel().then((value) {
        setState(() {
          isLoaded = true;
          isDetecting = false;
          yoloResults = [];
        });
      });
    });
    await controller.initialize();
    await controller.setFlashMode(FlashMode.off);

    if (!mounted) {
      return;
    }

    setState(() {
      camsPermissionIsGranted = true;
      isCams = true;
    });
  }

  @override
  void dispose() async {
    super.dispose();
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    if (!isLoaded) {
      return const Scaffold(
        body: Center(
          child: Text("Model not loaded, waiting for it"),
        ),
      );
    }
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: CameraPreview(controller),
          ),
          ...displayBoxesAroundRecognizedObjects(size),
          Positioned(
            bottom: 75,
            left: -20,
            width: MediaQuery.of(context).size.width,
            child: Container(
              height: 80,
              width: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    width: 3, color: Colors.white, style: BorderStyle.solid),
              ),
              child: IconButton(
                onPressed: () async {
                  if (isDetecting) {
                    stopDetection();
                    print("Detecteds: ${yoloResults.length}");
                  } else {
                    startDetection();
                  }
                },
                icon: Icon(
                  isDetecting ? Icons.stop : Icons.play_arrow,
                  color: isDetecting ? Colors.red : Colors.white,
                ),
                iconSize: 50,
              ),
            ),
          ),
          Positioned.fill(
            child: Stack(
            children: [
              _retourButtonWidget(),
              if (camsPermissionIsGranted && isCams) ...[
                //_cameraIconWidget(),    // L'icône de l'appareil photo
                //_galleryIconWidget(),   // L'icône de la galerie
                //_flashIconWidget(),     // L'icône du flash
              ]
              else if (!camsPermissionIsGranted && !isCams) ...[
                //_cameraIconWidget(),    // L'icône de l'appareil photo
                //_galleryIconWidget(),   // L'icône de la galerie
              ]
              else ...[
                const Center(
                child: CircularProgressIndicator(),
                ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
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
                  Navigator.pop(context);
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

  /*void _toggleFlash() async {
    if (controller != null) {
      setState(() {
        _isFlashOn = !_isFlashOn;
        _flashIcon = _isFlashOn ? Icons.flash_on : Icons.flash_off;
      });
      await controller.setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
    }
  }

  Widget _flashIconWidget() {
    return Positioned(
      top: 0,
      left: 30.0,
      child: GestureDetector(
        onTap: _toggleFlash,
        child: Icon(
          _flashIcon,
          color: _isFlashOn ? Colors.yellow : Colors.grey,
          size: 30.0,
        ),
      ),
    );
  }

  Widget _cameraIconWidget() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: GestureDetector(
        onTap: () async {
          if (!camsPermissionIsGranted && !isCams) {
            openAppSettings();
          }else{
            try {
              if (controller != null) {
                setState(() {
                  _isFlashOn = false;
                  _flashIcon = Icons.flash_off;
                });
                await controller.setFlashMode(FlashMode.off);
              }
              final image = await controller.takePicture();
              goToPreview(image);
            } catch (e) {
              print('Error taking picture: $e');
            }
          }
        },
        child: Padding(
          padding: const EdgeInsets.only(bottom: 20.0),
          child: Image.asset(
            'assets/photo.png',
            width: 80.0,
            height: 80.0,
          ),
        ),
      ),
    );
  }

  Widget _galleryIconWidget() {
    return Positioned(
      bottom: 40.0,
      right: 90.0,
      child: GestureDetector(
        onTap: () {
          _openGallery();
        },
        child: Image.asset(
          'assets/gallery.png',
          width: 30.0,
          height: 30.0,
        ),
      ),
    );
  }

  Future<void> _openGallery() async {
    var status = await Permission.photos.request();
    if (!status.isGranted) {
      status = await Permission.storage.request();
    }
    if (status.isGranted) {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        goToPreview(pickedFile);
      } else {
        Fluttertoast.showToast(
            msg: "Aucune image chargée",
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.TOP,
            timeInSecForIosWeb: 4,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            fontSize: 16.0
        );
      }
    }
  }
  goToPreview(image) async {
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => ImageViewer(imagePath: image.path),
      ),
    );
  }

  //load your model
  Future loadModel() async {
    String pathImageModel = "assets/models/model_classification.pt";
    //String pathCustomModel = "assets/models/custom_model.ptl";
    String pathObjectDetectionModel = "assets/models/yolov5s.torchscript";
    try {
      //_imageModel = await FlutterPytorch.loadClassificationModel(
          //pathImageModel, 224, 224,
          //labelPath: "assets/labels.txt");
      //_customModel = await PytorchLite.loadCustomModel(pathCustomModel);
      _objectModel = await FlutterPytorch.loadObjectDetectionModel(
          pathObjectDetectionModel, 80, 640, 640,
          labelPath: "assets/labels.txt");
    } catch (e) {
      if (e is PlatformException) {
        print("only supported for android, Error is $e");
      } else {
        print("Error is $e");
      }
    }
  }

  Future runObjectDetection() async {
    //pick a random image
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    objDetect = await _objectModel.getImagePrediction(
        await File(image!.path).readAsBytes(),
        minimumScore: 0.1,
        IOUThershold: 0.3);
    objDetect.forEach((element) {
      print({
        "score": element?.score,
        "className": element?.className,
        "class": element?.classIndex,
        "rect": {
          "left": element?.rect.left,
          "top": element?.rect.top,
          "width": element?.rect.width,
          "height": element?.rect.height,
          "right": element?.rect.right,
          "bottom": element?.rect.bottom,
        },
      });
    });
    setState(() {
      //this.objDetect = objDetect;
      _image = File(image.path);
    });
  }

  Future runClassification() async {
    objDetect = [];
    //pick a random image
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    //get prediction
    //labels are 1000 random english words for show purposes
    print(image!.path);
    _imagePrediction = await _imageModel!
        .getImagePrediction(await File(image!.path).readAsBytes());

    List<double?>? predictionList = await _imageModel!.getImagePredictionList(
      await File(image.path).readAsBytes(),
    );

    print(predictionList);
    List<double?>? predictionListProbabilites =
    await _imageModel!.getImagePredictionListProbabilities(
      await File(image.path).readAsBytes(),
    );
    //Gettting the highest Probability
    double maxScoreProbability = double.negativeInfinity;
    double sumOfProbabilites = 0;
    int index = 0;
    for (int i = 0; i < predictionListProbabilites!.length; i++) {
      if (predictionListProbabilites[i]! > maxScoreProbability) {
        maxScoreProbability = predictionListProbabilites[i]!;
        sumOfProbabilites = sumOfProbabilites + predictionListProbabilites[i]!;
        index = i;
      }
    }
    print(predictionListProbabilites);
    print(index);
    print(sumOfProbabilites);
    print(maxScoreProbability);

    setState(() {
      //this.objDetect = objDetect;
      _image = File(image.path);
    });
  }*/

/*------------------------------------------------------------------------------------------------------------------------------*/

  Future<void> loadYoloModel() async {
    final byteData = await rootBundle.load('assets/MARIE7000IR9.onnx');
    final Directory cacheDir = await getTemporaryDirectory();
    final File file = File('${cacheDir.path}/MARIE7000IR9.onnx');
    await file.writeAsBytes(byteData.buffer.asUint8List());
    YoloModel.initializeYoloModel('${cacheDir.path}/MARIE7000IR9.onnx');
    cachePath = cacheDir.path;
    setState(() {
      isLoaded = true;
    });
  }


  static void runIosBackgroundTask(args) async {
    List<int> frame = processCameraImage(args[0]);
    Uint8List imageData = Uint8List.fromList(frame);
    var result = args[1].yoloOnIosFrame(
        imageData,
        imageData.length
    );
    var sendPort = args[2];
    sendPort.send(result);
    sendPort.send('FINISHED');
  }

  static void runAndroidBackgroundTask(args) async {
    var sendPort = args[0];
    var result = args[8].yoloOnAndroidFrame(
      args[1],
      args[2],
      args[3],
      args[4],
      args[5],
      args[6],
      args[7],
    );
    sendPort.send(result);
    sendPort.send('FINISHED');
  }

  static List<int> processCameraImage(CameraImage cameraImage) {
    final int width = cameraImage.width;
    final int height = cameraImage.height;
    final int bytesPerRow = cameraImage.planes[0].bytesPerRow;
    const int bytesPerPixel = 4; // BGRA8888 a 4 octets par pixel
    var img = imglib.Image(width, height);
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int index = y * bytesPerRow + x * bytesPerPixel;
        final int pixel = cameraImage.planes[0].bytes[index] |
        cameraImage.planes[0].bytes[index + 1] << 8 |
        cameraImage.planes[0].bytes[index + 2] << 16 |
        cameraImage.planes[0].bytes[index + 3] << 24;
        img.setPixelRgba(x, y,
            (pixel >> 16) & 0xFF,
            (pixel >> 8) & 0xFF,
            pixel & 0xFF,
            (pixel >> 24) & 0xFF);
      }
    }
    return imglib.encodeJpg(img);
  }

  Future<void> yoloOnFrame(CameraImage cameraImage) async {
    if(!isBusy){
      isBusy = true;
      if(Platform.isIOS){
        final receivePort = ReceivePort();
        await Isolate.spawn(runIosBackgroundTask, [
          cameraImage,
          widget.model,
          receivePort.sendPort,
        ]);
        await for (var message in receivePort) {
          try{
            List<dynamic> jsonData = jsonDecode(message);
            List<Map<String, dynamic>> finalJsonResult = jsonData.map((item) => Map<String, dynamic>.from(item)).toList();
            result = finalJsonResult;
          }catch(e){
            receivePort.close();
          }
        }
      }else{
        final receivePort = ReceivePort();
        await Isolate.spawn(runAndroidBackgroundTask, [receivePort.sendPort,
          cameraImage.planes[0].bytes,
          cameraImage.planes[1].bytes,
          cameraImage.planes[2].bytes,
          cameraImage.planes[1].bytesPerRow,
          cameraImage.planes[1].bytesPerPixel,
          cameraImage.width,
          cameraImage.height,
          widget.model
        ]);
        await for (var message in receivePort) {
          try{
            List<dynamic> jsonData = jsonDecode(message);
            List<Map<String, dynamic>> finalJsonResult = jsonData.map((item) => Map<String, dynamic>.from(item)).toList();
            result = finalJsonResult;
            print("result ${result}");
          }catch(e){
            receivePort.close();
          }
        }
      }
      setState(() {
        yoloResults = result;
        isBusy = false;
      });
    }
  }

  Future<void> startDetection() async {
    setState(() {
      isDetecting = true;
    });
    if (controller.value.isStreamingImages) {
      return;
    }
    await controller.startImageStream((image) async {
      if (isDetecting) {
        cameraImage = image;
        if(countFrame % 20 == 0){
          yoloOnFrame(image);
          countFrame = 0;
        }
        countFrame++;
      }
    });
  }

  Future<void> stopDetection() async {
    setState(() {
      isDetecting = false;
      historiser();
      yoloResults.clear();
      isBusy = false;
    });
  }

  // -----------------------------
  // Historisation
  // -----------------------------
  Future<void> historiser() async {
    List<String> results = [];
    final DateTime now = DateTime.now();
    final DateFormat formatter = DateFormat('yyyy-MM-dd H:mm');
    final String date = formatter.format(now);
    for(final yoloResult in yoloResults){
      int  class_idx = yoloResult["class_idx"]; // je stoke la valeur de ma classe, exmple 8
      String value_class = classes[class_idx] ;// je veux la valeur correspondant à ma class_idx, ici 5 euros
      results.add(value_class);
    }
    var total;
    String title_history_card = "${date} - ${total}";
    String image_url = "";
    Map<String, dynamic> head = {
      "title": title_history_card,
      "image_url": image_url
    };
    Map<String, dynamic> tail = calculateDetails(results);
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

  Map<String, dynamic> calculateDetails(List<String> moneyList) {
    double total = 0;
    double totalPieces = 0;
    int countPieces = 0;
    double totalBillets = 0;
    int countBillets = 0;
    Map<String, Map<String, dynamic>> itemDetails = {};

    // Définition des motifs pour identifier les pièces et les billets
    final piecePatterns = RegExp(r'2 euros|1 euro|centimes');
    final billetPatterns = RegExp(r'5 euros|10 euros|20 euros|50 euros|100 euros|200 euros|500 euros');
    final autrePatterns = RegExp(r'Cheques|Tickets de caisse|tickets de caisse');

    for (String money in moneyList) {
      if(autrePatterns.hasMatch(money)) {
        break;
      }

      // Extraire la valeur numérique
      double value = double.parse(RegExp(r'\d+').firstMatch(money)!.group(0)!);
      String euroValue = '$value€';

      // Gestion spécifique des centimes
      if (money.contains("centimes")) {
        value /= 100;
        euroValue = "${value.toStringAsFixed(2)}€";
      }

      // Ajout à la somme totale
      total += value;

      // Initialiser ou mettre à jour les détails de l'item
      itemDetails[money] ??= {
        'name': money,
        'price': euroValue,
        'somme': '0€',
        'quantity': 0
      };
      itemDetails[money]?['quantity'] += 1;
      double sum = double.parse(itemDetails[money]?['somme'].replaceAll('€', '')) + value;
      itemDetails[money]?['somme'] = "${sum.toStringAsFixed(2)}€";

      // Vérification si c'est une pièce
      if (piecePatterns.hasMatch(money)) {
        totalPieces += value;
        countPieces++;
      }

      // Vérification si c'est un billet
      if (billetPatterns.hasMatch(money)) {
        totalBillets += value;
        countBillets++;
      }
    }

    return {
      'total': '${total.toStringAsFixed(2)}€',
      'nbr_piece': countPieces.toString(),
      'total_piece': '${totalPieces.toStringAsFixed(2)}€',
      'nbr_billet': countBillets.toString(),
      'total_billet': '$totalBillets€',
      'items': itemDetails.values.toList()
    };
  }

  calculateFactoryX(Size screen){
    if(Platform.isIOS){
      return screen.width / cameraImage!.width;
    }else{
      return screen.width / (cameraImage?.height ?? 1);
    }
  }

  calculateFactoryY(Size screen){
    if(Platform.isIOS){
      return screen.height / cameraImage!.height;
    }else{
      return screen.height / (cameraImage?.width ?? 1);
    }
  }

  List<Widget> displayBoxesAroundRecognizedObjects(Size screen) {
    if (yoloResults.isEmpty) return [];
    factorX = calculateFactoryX(screen);
    factorY = calculateFactoryY(screen);

    return yoloResults.map((result) {
      return Positioned(
        left: result["bbox"][0] * factorX,
        top: result["bbox"][1] * factorY,
        width: result["bbox"][2] * factorX,
        height: result["bbox"][3] * factorY,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(10.0)),
            border: Border.all(color: Colors.pink, width: 2.0),
          ),
          child: Text(
            "${classes[result['class_idx']]} ${(result['conf']).toStringAsFixed(2)}%",
            style: TextStyle(
              background: Paint()..color = colorPick,
              color: Colors.white,
              fontSize: 18.0,
            ),
          ),
        ),
      );
    }).toList();
  }
}

