// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../main.dart';
import 'image.dart';

class OpenCamera extends StatefulWidget {
  const OpenCamera({super.key});
  @override
  State<OpenCamera> createState() => _OpenCameraState();
}

class _OpenCameraState extends State<OpenCamera> with WidgetsBindingObserver {
  late CameraController? _controller;
  late bool initialized = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WidgetsBinding.instance.addObserver(this);
    _requestCameraPermission();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if(initialized){
      if (state == AppLifecycleState.inactive) {
        _controller!.dispose();
      } else if (state == AppLifecycleState.resumed) {
        _initializeCamera();
      }
    }
  }


  @override
  void dispose() {
    _controller!.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
      throw 'No camera detected';
    }
    _controller = CameraController(
      selectedCamera,
      ResolutionPreset.ultraHigh,
      enableAudio: false,
    );

    await _controller!.initialize();

    if (!mounted) {
      return;
    }

    setState(() {
      initialized = true;
    });
  }

  Future<void> _openGallery() async {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage.request();
    }
    if (status.isGranted) {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        print('Image selected: ${pickedFile.path}');
        goToPreview(pickedFile);
      } else {
        print('No image selected.');
      }
    } else {
      print('Permission denied');
    }
  }

  goToPreview(image) {
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => ImageViewer(imagePath: image.path),
      ),
    );
  }

  Future<void> _requestCameraPermission() async {
    var status = await Permission.camera.status;
    if (status.isDenied) {
      status = await Permission.camera.request();
    }

    if (status.isGranted) {
      _initializeCamera();
    } else {
      print('Permission Denied');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: initialized
            ? Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: size.width,
              height: size.height,
              child: OverflowBox(
                alignment: Alignment.center,
                maxHeight: size.height,
                maxWidth: size.height * _controller!.value.aspectRatio,
                child: CameraPreview(_controller!),
              ),
            ),
            Positioned(
              bottom: 20.0,
              child: GestureDetector(
                onTap: () async {
                  try {
                    final image = await _controller!.takePicture();
                    goToPreview(image);
                  } catch (e) {
                    print('Error taking picture: $e');
                  }
                },
                child: SizedBox(
                  width: 80.0,
                  height: 80.0,
                  child: Center(
                    child: Image.asset(
                      'assets/photo.png',
                      width: 80.0,
                      height: 80.0,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 40.0,
              right: 90.0,
              child: GestureDetector(
                onTap: _openGallery,
                child: Center(
                  child: Image.asset(
                    'assets/gallery.png',
                    width: 30.0,
                    height: 30.0,
                  ),
                ),
              ),
            ),
          ],
        )
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}




