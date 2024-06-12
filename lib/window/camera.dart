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
  const OpenCamera({super.key});
  @override
  State<OpenCamera> createState() => _OpenCameraState();
}

class _OpenCameraState extends State<OpenCamera> with WidgetsBindingObserver {
  late bool camsPermissionIsGranted = false;
  late bool isCams = false;
  late CameraController? _controller;
  late IconData _flashIcon = Icons.flash_off;
  bool _isFlashOn = false;

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
}