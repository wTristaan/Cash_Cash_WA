// ignore_for_file: avoid_print
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../main.dart';
import 'image.dart';

class OpenCamera extends StatefulWidget {
  final VoidCallback? onGalleryOpened;

  const OpenCamera({Key? key, this.onGalleryOpened}) : super(key: key);

  //const OpenCamera({super.key});

  @override
  State<OpenCamera> createState() => _OpenCameraState();
}

class _OpenCameraState extends State<OpenCamera> with WidgetsBindingObserver {
  late bool camsPermissionIsGranted = false;
  late bool isCams = false;
  late CameraController? _controller;
  late IconData _flashIcon = Icons.flash_off;
  bool _isFlashOn = false;
  GlobalKey<_OpenCameraState> openCameraKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.black,
      statusBarIconBrightness: Brightness.light,
    ));
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    var status = await Permission.camera.status;
    if(status.isGranted){
      if (state == AppLifecycleState.inactive) {
        _controller!.dispose();
      } else if (state == AppLifecycleState.resumed) {
        _initializeCamera();
      }
    }
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    CameraDescription? selectedCamera;
    for (final camera in cameras) {
      if (camera.lensDirection == CameraLensDirection.back) {
        selectedCamera = camera;
        break;
      }
    }

    if (selectedCamera == null) {
      throw 'Aucune caméra détectée';
    }else{
      _controller = CameraController(
        selectedCamera,
        ResolutionPreset.veryHigh,
        enableAudio: false,
      );

      await _controller!.initialize();
      await _controller!.setFlashMode(FlashMode.off);

      if (!mounted) {
        return;
      }

      setState(() {
        camsPermissionIsGranted = true;
        isCams = true;
      });
    }
  }

  Future<void> _requestCameraPermission() async {
    var status = await Permission.camera.status;
    if (status.isDenied) {
      status = await Permission.camera.request();
    }

    if (status.isGranted) {
      _initializeCamera();
    } else {
      setState(() {
        camsPermissionIsGranted = false;
        isCams = false;
      });
    }
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

  goToPreview(image) async {
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => ImageViewer(imagePath: image.path),
      ),
    );
  }

  void _toggleFlash() async {
    if (_controller != null) {
      setState(() {
        _isFlashOn = !_isFlashOn;
        _flashIcon = _isFlashOn ? Icons.flash_on : Icons.flash_off;
      });
      await _controller!.setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              height: statusBarHeight + 20,
              color: Colors.black,
            ),
            Expanded(
              child: Stack(
                children: [
                  if (camsPermissionIsGranted && isCams) ...[
                  ] else if (!camsPermissionIsGranted && !isCams) ...[
                  ] else ...[
                    const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Future<void> _initializeCamera() async {
  //   final cameras = await availableCameras();
  //   CameraDescription? selectedCamera;
  //   for (final camera in cameras) {
  //     if (camera.lensDirection == CameraLensDirection.back) {
  //       selectedCamera = camera;
  //       break;
  //     }
  //   }
  //
  //   if (selectedCamera == null) {
  //     throw 'Aucune caméra détectée';
  //   }else{
  //     _controller = CameraController(
  //       selectedCamera,
  //       ResolutionPreset.veryHigh,
  //       enableAudio: false,
  //     );
  //
  //     await _controller!.initialize();
  //     await _controller!.setFlashMode(FlashMode.off);
  //
  //     if (!mounted) {
  //       return;
  //     }
  //
  //     setState(() {
  //       camsPermissionIsGranted = true;
  //       isCams = true;
  //     });
  //   }
  //   }

  Widget _galleryIconWidget() {
    return Positioned(
      bottom: 40.0,
      right: 90.0,
      child: GestureDetector(
        onTap: () {
          _openGallery();
          if (widget.onGalleryOpened != null) widget.onGalleryOpened!();
        },
        child: Image.asset(
          'assets/gallery.png',
          width: 30.0,
          height: 30.0,
        ),
      ),
    );
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
}