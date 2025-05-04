import 'dart:io';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pytorch_lite/pytorch_lite.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'camera_view_singleton.dart';

/// [CameraView] sends each frame for inference
class CameraView extends StatefulWidget {
  /// Callback to pass results after inference to [HomeView]
  /// Constructor

  final Function(List<ResultObjectDetection> recognitions,
      Duration inferenceTime, double fps) resultsCallback;

  const CameraView(this.resultsCallback, {Key? key}) : super(key: key);

  @override
  _CameraViewState createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> with WidgetsBindingObserver {
  List<bool> objects = [false, false, false, false, false];
  int frameCount = 0;
  double fps = 0.0;
  DateTime? lastTime;
  final player = AudioPlayer();
  late Stopwatch eyesStopwatch;
  bool detectedClosed = false;

  /// List of available cameras
  late List<CameraDescription> cameras;

  /// Controller
  CameraController? cameraController;

  /// true when inference is ongoing
  bool predicting = false;

  /// true when inference is ongoing
  bool predictingObjectDetection = false;

  ModelObjectDetection? _objectModel;

  bool classification = false;
  int _camFrameRotation = 0;
  String errorMessage = "";

  int cameraIndex = 0;
  Map<String?, int>? classFreq;

  @override
  void initState() {
    super.initState();
    initStateAsync();
    eyesStopwatch = Stopwatch();
  }

  //load your model
  Future loadModel() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? pathObjectDetectionModel = prefs.getString('modelPath');
    String? labelsPath = prefs.getString('labelsPath');
    print(labelsPath);
    try {
      _objectModel = await PytorchLite.loadObjectDetectionModel(
        "assets/dms.torchscript",
        5,
        640,
        640,
        labelPath: "assets/dms_labels.txt",
        objectDetectionModelType: ObjectDetectionModelType.yolov8,
      );
      if (_objectModel?.labels != null) {
        for (var label in _objectModel!.labels) {
          classFreq?.addEntries([MapEntry(label, 0)]);
        }
      }
      classFreq = {for (var label in _objectModel!.labels) label: 0};
      print('_objectModel.labels = $classFreq');
    } catch (e) {
      if (e is PlatformException) {
        print("only supported for android, Error is $e");
      } else {
        print("Error is $e");
      }
    }
  }

  void initStateAsync() async {
    WidgetsBinding.instance.addObserver(this);
    await loadModel();

    // Camera initialization
    try {
      initializeCamera();
    } on CameraException catch (e) {
      switch (e.code) {
        case 'CameraAccessDenied':
          errorMessage = ('You have denied camera access.');
          break;
        case 'CameraAccessDeniedWithoutPrompt':
          // iOS only
          errorMessage = ('Please go to Settings app to enable camera access.');
          break;
        case 'CameraAccessRestricted':
          // iOS only
          errorMessage = ('Camera access is restricted.');
          break;
        case 'AudioAccessDenied':
          errorMessage = ('You have denied audio access.');
          break;
        case 'AudioAccessDeniedWithoutPrompt':
          // iOS only
          errorMessage = ('Please go to Settings app to enable audio access.');
          break;
        case 'AudioAccessRestricted':
          // iOS only
          errorMessage = ('Audio access is restricted.');
          break;
        default:
          errorMessage = (e.toString());
          break;
      }
      setState(() {});
    }
    // Initially predicting = false
    setState(() {
      predicting = false;
    });
  }

  /// Initializes the camera by setting [cameraController]
  void initializeCamera() async {
    cameras = await availableCameras();

    var desc = cameras[cameraIndex];
    _camFrameRotation = Platform.isAndroid ? desc.sensorOrientation : 0;
    print('Camera is being initialized... $_camFrameRotation');
    // cameras[0] for rear-camera
    cameraController = CameraController(
      desc,
      ResolutionPreset.low,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.yuv420
          : ImageFormatGroup.bgra8888,
      enableAudio: false,
    );

    cameraController?.initialize().then((_) async {
      // Stream of image passed to [onLatestImageAvailable] callback
      await cameraController?.startImageStream(onLatestImageAvailable);

      /// previewSize is size of each image frame captured by controller
      ///
      /// 352x288 on iOS, 240p (320x240) on Android with ResolutionPreset.low
      Size? previewSize = cameraController?.value.previewSize;

      /// previewSize is size of raw input image to the model
      CameraViewSingleton.inputImageSize = previewSize!;

      // the display width of image on screen is
      // same as screenWidth while maintaining the aspectRatio
      Size screenSize = MediaQuery.of(context).size;
      CameraViewSingleton.screenSize = screenSize;
      CameraViewSingleton.ratio = cameraController!.value.aspectRatio;
    });
  }

  @override
  Widget build(BuildContext context) {
    Size screenSize = MediaQuery.of(context).size;
    double screenHeight = screenSize.height;
    print('HERE: $objects');

    // Return empty container while the camera is not initialized
    if (cameraController == null || !cameraController!.value.isInitialized) {
      return Container();
    }

    return Stack(
      children: [
        cameraIndex == 0
            ? CameraPreview(cameraController!)
            : Transform(
                alignment: Alignment.center,
                transform: Matrix4.rotationY(math.pi),
                child: CameraPreview(cameraController!),
              ),
        Positioned(
          bottom: 50,
          right: 10,
          child: FloatingActionButton(
            onPressed: () {
              setState(() {
                cameraIndex == 0 ? cameraIndex = 1 : cameraIndex = 0;
              });
              initializeCamera();
              if (kDebugMode) {
                print('Camera Index = $cameraIndex');
              }
            },
            tooltip: 'Switch Camera',
            mini: true,
            backgroundColor: Colors.black.withAlpha(90),
            child: const Icon(Icons.cameraswitch),
          ),
        ),
        Positioned(
          top: screenHeight / 4,
          left: 10,
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20.0),
              color: Colors.black.withAlpha(60),
            ),
            child: Column(
              children: [
                // Awake
                Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: objects[1] ? Colors.red : Colors.transparent,
                          width: 5,
                        ),
                      ),
                      width: 60,
                      height: 60,
                      child: const Icon(
                        Icons.bedtime,
                        color: Colors.white,
                      ),
                    ),
                    const Text(
                      'Sleepy',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 10,
                ),

                // Cigarette
                Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: objects[2] ? Colors.red : Colors.transparent,
                          width: 5,
                        ),
                      ),
                      width: 60,
                      height: 60,
                      child: const Icon(
                        Icons.smoking_rooms_sharp,
                        color: Colors.white,
                      ),
                    ),
                    const Text(
                      'Cigarette',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 10,
                ),

                // Phone
                Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: objects[3] ? Colors.red : Colors.transparent,
                          width: 5,
                        ),
                      ),
                      width: 60,
                      height: 60,
                      child: const Icon(
                        Icons.phone_android,
                        color: Colors.white,
                      ),
                    ),
                    const Text(
                      'Phone',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 10,
                ),

                // Seatbelt
                Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: !objects[4] ? Colors.red : Colors.transparent,
                          width: 5,
                        ),
                      ),
                      width: 60,
                      height: 60,
                      child: const Icon(
                        Icons.safety_check,
                        color: Colors.white,
                      ),
                    ),
                    const Text(
                      'Seatbelt',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 10,
                ),
              ],
            ),
          ),
        )
      ],
    );
  }

  int labelFreq(String label, List<ResultObjectDetection> objects) {
    int freq = 0;
    for (var object in objects) {
      if (object.className == label) freq++;
    }
    return freq;
  }

  Future<void> runObjectDetection(CameraImage cameraImage) async {
    if (lastTime != null) {
      final currentTime = DateTime.now();
      final frameTime = currentTime.difference(lastTime!).inMilliseconds;
      fps = 1000.0 / frameTime;
    }
    lastTime = DateTime.now();
    frameCount++;
    setState(() {});

    if (predictingObjectDetection) {
      return;
    }
    if (!mounted) {
      return;
    }

    setState(() {
      predictingObjectDetection = true;
    });
    if (_objectModel != null) {
      // Start the stopwatch
      Stopwatch stopwatch = Stopwatch()..start();

      List<ResultObjectDetection> objDetect =
          await _objectModel!.getCameraImagePrediction(
        cameraImage,
        // cameraIndex == 0 ? 90 : 270,
        minimumScore: 0.3,
        iOUThreshold: 0.3,
      );

      List<ResultObjectDetection> objDetectTemp = objDetect;
      objects[1] = false;
      objects[2] = false;
      objects[3] = false;
      objects[4] = false;
      for (var detectedObject in objDetectTemp) {

        if (detectedObject.className == 'Closed Eye' &&
            labelFreq('Closed Eye', objDetectTemp) == 2 &&
            detectedClosed == false) {
          classFreq?[detectedObject.className] =
              classFreq![detectedObject.className]! + 1;
          detectedClosed = true;
          print('Detected 2 closed eyes!');
          eyesStopwatch = Stopwatch()..start();
        } else if (detectedObject.className == 'Open Eye') {
          detectedClosed = false;
        }

        if (detectedObject.className == 'Cigarette') {
            objects[2] = true;
        }

        if (detectedObject.className == 'Phone') {
            objects[3] = true;
        }

        if (detectedObject.className == 'Seatbelt') {
            objects[4] = true;
        }

        print(
            '${detectedObject.className} = ${classFreq?[detectedObject.className]}');
      }
      print(
          '++++++++++++++++ ${eyesStopwatch.elapsed.inSeconds} +++++++++++++');
      print('detectedClosed = $detectedClosed');

      if (eyesStopwatch.elapsed.inMilliseconds >= 100) {
        if (detectedClosed == false) {
          eyesStopwatch.reset();
          await player.stop();
        } else {
          objects[1] = true;
          await player.play(AssetSource('sound_effects/beep.mp3'));
        }
      }

      // Stop the stopwatch
      stopwatch.stop();
      // print("data outputted $objDetect");
      widget.resultsCallback(objDetect, stopwatch.elapsed, fps);
    }
    if (!mounted) {
      return;
    }

    setState(() {
      predictingObjectDetection = false;
    });
  }

  /// Callback to receive each frame [CameraImage] perform inference on it
  onLatestImageAvailable(CameraImage cameraImage) async {
    // Make sure we are still mounted, the background thread can return a response after we navigate away from this
    // screen but before bg thread is killed
    if (!mounted) {
      return;
    }

    // log("will start prediction");
    // log("Converted camera image");

    // runClassification(cameraImage);
    runObjectDetection(cameraImage);

    // log("done prediction camera image");
    // Make sure we are still mounted, the background thread can return a response after we navigate away from this
    // screen but before bg thread is killed
    if (!mounted) {
      return;
    }
  }

  // @override
  // void didChangeAppLifecycleState(AppLifecycleState state) async {
  //   if (!mounted) {
  //     return;
  //   }
  //   switch (state) {
  //     case AppLifecycleState.paused:
  //       cameraController?.stopImageStream();
  //       break;
  //     case AppLifecycleState.resumed:
  //       if (cameraController != null) {
  //         if (!cameraController!.value.isStreamingImages) {
  //           await cameraController?.startImageStream(onLatestImageAvailable);
  //         }
  //       }
  //       break;
  //     default:
  //   }
  // }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    cameraController?.dispose();
    player.dispose();
    super.dispose();
  }
}
