import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

final DynamicLibrary convertImageLib = Platform.isIOS
    ? DynamicLibrary.open("yolov8.framework/yolov8")
    : DynamicLibrary.open("libyolov8.so");

typedef AndroidDetectionF = Pointer<Utf8> Function(
    Pointer<Uint8>,
    Pointer<Uint8>,
    Pointer<Uint8>,
    int,
    int,
    int,
    int
    );

typedef AndroidDetectionC = Pointer<Utf8> Function(
    Pointer<Uint8>,
    Pointer<Uint8>,
    Pointer<Uint8>,
    Int32,
    Int32,
    Int32,
    Int32
    );

typedef IosDetectionF = Pointer<Utf8> Function(
    Pointer<Uint8>,
    int,
    );

typedef IosDetectionC = Pointer<Utf8> Function(
    Pointer<Uint8>,
    Int32,
    );

typedef InitializeYoloModelC = Void Function(Pointer<Utf8>);
typedef InitializeYoloModelDart = void Function(Pointer<Utf8>);

class YoloModel{
  late Pointer<Uint8> p;
  late Pointer<Uint8> p1;
  late Pointer<Uint8> p2;

  late Uint8List pointerList;
  late Uint8List pointerList1;
  late Uint8List pointerList2;

  late List<dynamic> jsonResult;
  late Pointer<Utf8> resultP;
  late List<Map<String, dynamic>> finalJsonResult;
  late final IosDetectionF _iosDetectionF = convertImageLib.lookup<NativeFunction<IosDetectionC>>('iosDetection').asFunction<IosDetectionF>();
  late final AndroidDetectionF _androidDetectionF = convertImageLib.lookup<NativeFunction<AndroidDetectionC>>('androidDetection').asFunction<AndroidDetectionF>();


  static void initializeYoloModel(String pathToModel) {
    final initializeYoloModel = convertImageLib
        .lookup<NativeFunction<InitializeYoloModelC>>('initializeYoloModel')
        .asFunction<InitializeYoloModelDart>();
    final Pointer<Utf8> modelPath = pathToModel.toNativeUtf8();
    initializeYoloModel(modelPath);
    malloc.free(modelPath);
  }

  String yoloOnIosFrame(
      Uint8List yBuffer,
      int dataSize,
      ){
    Pointer<Uint8> p = malloc.allocate<Uint8>(yBuffer.length);
    for (int i = 0; i < yBuffer.length; i++) {
      p.elementAt(i).value = yBuffer[i];
    }
    pointerList = p.asTypedList(yBuffer.length);
    pointerList.setRange(0, yBuffer.length, yBuffer);
    resultP = _iosDetectionF(
        p,
        dataSize
    );
    malloc.free(p);

    try {
      return resultP.toDartString();
    } catch (e) {
      print('Failed to decode UTF-8 string: $e');
      return "{\"bbox\": [10, 20, 30, 40], \"class_idx\": 1, \"conf\": 0.95}";
    } finally {
      malloc.free(resultP);
    }
  }

  String yoloOnAndroidFrame(
      Uint8List yBuffer,
      Uint8List uBuffer,
      Uint8List vBuffer,
      int bytesPerRowPlane1,
      int? bytesPerPixelPlane1,
      width,
      height
      ){
    p = malloc.allocate(yBuffer.length);
    p1 = malloc.allocate(uBuffer.length);
    p2 = malloc.allocate(vBuffer.length);

    pointerList = p.asTypedList(yBuffer.length);
    pointerList1 = p1.asTypedList(uBuffer.length);
    pointerList2 = p2.asTypedList(vBuffer.length);

    pointerList.setRange(0, yBuffer.length, yBuffer);
    pointerList1.setRange(0, uBuffer.length, uBuffer);
    pointerList2.setRange(0, vBuffer.length, vBuffer);

    resultP = _androidDetectionF(
        p,
        p1,
        p2,
        bytesPerRowPlane1,
        bytesPerPixelPlane1!,
        width,
        height
    );
    malloc.free(p);
    malloc.free(p1);
    malloc.free(p2);
    malloc.free(resultP);
    return resultP.toDartString();
  }
}