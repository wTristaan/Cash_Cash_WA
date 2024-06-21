import 'dart:async';
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

import '../main.dart';

import '../entities/yolo.dart';
import '../window/image.dart';


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
            child: Image.asset('assets/gallery.png'),
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
      final _YoloVideoState gal = _YoloVideoState();
      gal._openGallery();
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
  String? textToShow;
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
      return Scaffold(
        body: Stack(
            children: [
              _retourButtonWidget(),
              const Center(
                child: Text("Le model n'a pas été chargé, en attente..."),
              ),
            ]
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
            top: 60,
            right: 138,
            width: MediaQuery.of(context).size.width,
            child: Container(
              height: 45,
              width: 45,
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
                  size: 35,
                ),
              ),
            ),
          ),
          // Positioned(
          // top: 0,
          // left: 0,
          // right: 0,
          // bottom: 0,
          Positioned.fill(
            child: Stack(
            children: [
              _retourButtonWidget(),
              if (camsPermissionIsGranted && isCams) ...[
                _cameraIconWidget(),    // L'icône de l'appareil photo
                _flashIconWidget(),     // L'icône du flash
              ]
              else if (!camsPermissionIsGranted && !isCams) ...[
                _cameraIconWidget(),    // L'icône de l'appareil photo
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

  void _toggleFlash() async {
      setState(() {
        _isFlashOn = !_isFlashOn;
        _flashIcon = _isFlashOn ? Icons.flash_on : Icons.flash_off;
      });
      await controller.setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
  }

  Widget _flashIconWidget() {
    return Positioned(
      top: 32,
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

  Future<void> _takePhoto() async {
    try {
      if (!controller.value.isInitialized) {
        Fluttertoast.showToast(
            msg: "Camera not initialized",
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.TOP,
            timeInSecForIosWeb: 4,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            fontSize: 16.0
        );
        return;
      }
    } catch (e) {
      print('Error taking picture: $e');
      Fluttertoast.showToast(
          msg: "Error taking picture: $e",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.TOP,
          timeInSecForIosWeb: 4,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0
      );
    }
    final image = await controller.takePicture();
    goToPreview(image);
  }

  Widget _cameraIconWidget() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: GestureDetector(
        onTap: () async {
          if (!camsPermissionIsGranted && !isCams) {
            openAppSettings();
          } else {
            setState(() {
              _isFlashOn = false;
              _flashIcon = Icons.flash_off;
            });
            await controller.setFlashMode(FlashMode.off);
            await _takePhoto();
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
        if(countFrame % 10 == 0){
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
      yoloResults.clear();
      isBusy = false;
    });
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