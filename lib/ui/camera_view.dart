// ignore_for_file: unnecessary_import

import 'dart:io';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pytorch_lite/pytorch_lite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'camera_view_singleton.dart';

class CameraView extends StatefulWidget {
  final Function(List<ResultObjectDetection> recognitions, Duration inferenceTime, double fps, Map<String, int> classFreq) resultsCallback;

  const CameraView(this.resultsCallback, {Key? key}) : super(key: key);

  @override
  _CameraViewState createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> with WidgetsBindingObserver {
  List<bool> objects = [false, false, false, false, false]; // [unused, Sleepy, Cigarette, Phone, Seatbelt]
  int frameCount = 0;
  double fps = 0.0;
  DateTime? lastTime;
  final player = AudioPlayer();
  late Stopwatch eyesStopwatch;
  bool detectedClosed = false;

  late List<CameraDescription> cameras;
  CameraController? cameraController;
  bool predicting = false;
  bool predictingObjectDetection = false;
  ModelObjectDetection? _objectModel;
  int _camFrameRotation = 0;
  String errorMessage = "";
  int cameraIndex = 0;
  Map<String?, int>? classFreq;

  @override
  void initState() {
    super.initState();
    eyesStopwatch = Stopwatch();
    initStateAsync();
  }

  Future loadModel() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? pathObjectDetectionModel = prefs.getString('modelPath');
    String? labelsPath = prefs.getString('labelsPath') ?? "assets/dms_labels.txt";
    print('Loading model from: assets/dms.torchscript, labels: $labelsPath');
    try {
      _objectModel = await PytorchLite.loadObjectDetectionModel(
        "assets/dms.torchscript",
        5,
        640,
        640,
        labelPath: labelsPath,
        objectDetectionModelType: ObjectDetectionModelType.yolov8,
      );
      classFreq = {for (var label in _objectModel!.labels) label: 0};
      print('Model loaded successfully. Labels: ${classFreq!.keys.toList()}');
    } catch (e) {
      print("Error loading model: $e");
      setState(() {
        errorMessage = "Failed to load model: $e";
      });
    }
  }

  void initStateAsync() async {
    WidgetsBinding.instance.addObserver(this);
    await loadModel();
    try {
      initializeCamera();
    } on CameraException catch (e) {
      setState(() {
        errorMessage = _handleCameraException(e);
      });
    }
    setState(() {
      predicting = false;
    });
  }

  String _handleCameraException(CameraException e) {
    switch (e.code) {
      case 'CameraAccessDenied':
        return 'You have denied camera access.';
      case 'CameraAccessDeniedWithoutPrompt':
        return 'Please go to Settings app to enable camera access.';
      case 'CameraAccessRestricted':
        return 'Camera access is restricted.';
      case 'AudioAccessDenied':
        return 'You have denied audio access.';
      case 'AudioAccessDeniedWithoutPrompt':
        return 'Please go to Settings app to enable audio access.';
      case 'AudioAccessRestricted':
        return 'Audio access is restricted.';
      default:
        return e.toString();
    }
  }

  void initializeCamera() async {
    try {
      cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          errorMessage = "No cameras available";
        });
        return;
      }
      var desc = cameras[cameraIndex];
      _camFrameRotation = Platform.isAndroid ? desc.sensorOrientation : 0;
      print('Initializing camera: ${desc.name}, rotation: $_camFrameRotation');
      cameraController = CameraController(
        desc,
        ResolutionPreset.low,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888,
        enableAudio: false,
      );

      await cameraController?.initialize();
      await cameraController?.startImageStream(onLatestImageAvailable);

      Size? previewSize = cameraController?.value.previewSize;
      if (previewSize != null) {
        CameraViewSingleton.inputImageSize = previewSize;
        Size screenSize = MediaQuery.of(context).size;
        CameraViewSingleton.screenSize = screenSize;
        CameraViewSingleton.ratio = cameraController!.value.aspectRatio;
        print('Camera initialized. Preview size: $previewSize, screen size: $screenSize');
      } else {
        print('Warning: Preview size is null');
      }
      if (mounted) setState(() {});
    } catch (e) {
      print('Error initializing camera: $e');
      setState(() {
        errorMessage = "Camera initialization failed: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Size screenSize = MediaQuery.of(context).size;
    double screenHeight = screenSize.height;

    if (cameraController == null || !cameraController!.value.isInitialized) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade900, Colors.blue.shade600],
          ),
        ),
        child: Center(
          child: Text(
            errorMessage.isEmpty ? 'Initializing camera...' : errorMessage,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
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
          bottom: 60,
          right: 16,
          child: FloatingActionButton(
            onPressed: () {
              setState(() {
                cameraIndex = cameraIndex == 0 ? 1 : 0;
              });
              initializeCamera();
              print('Camera Index = $cameraIndex');
            },
            tooltip: 'Switch Camera',
            mini: true,
            backgroundColor: Colors.white,
            elevation: 4,
            child: Icon(
              Icons.cameraswitch,
              color: Colors.blue.shade900,
            ),
          ),
        ),
        Positioned(
          top: screenHeight / 4,
          left: 16,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildBehaviorIndicator(
                  icon: Icons.bedtime,
                  label: 'Sleepy',
                  isActive: objects[1],
                ),
                const SizedBox(height: 12),
                _buildBehaviorIndicator(
                  icon: Icons.smoking_rooms_sharp,
                  label: 'Cigarette',
                  isActive: objects[2],
                ),
                const SizedBox(height: 12),
                _buildBehaviorIndicator(
                  icon: Icons.phone_android,
                  label: 'Phone',
                  isActive: objects[3],
                ),
                const SizedBox(height: 12),
                _buildBehaviorIndicator(
                  icon: Icons.safety_check,
                  label: 'Seatbelt',
                  isActive: objects[4],
                  reverseColor: true,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBehaviorIndicator({
    required IconData icon,
    required String label,
    required bool isActive,
    bool reverseColor = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (reverseColor ? !isActive : isActive) ? Colors.red : Colors.transparent,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 24,
            color: Colors.blue.shade900,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.blue.shade900,
            ),
          ),
        ],
      ),
    );
  }

  int labelFreq(String label, List<ResultObjectDetection> objects) {
    return objects.where((object) => object.className == label).length;
  }

  Future<void> runObjectDetection(CameraImage cameraImage) async {
    if (lastTime != null) {
      final currentTime = DateTime.now();
      final frameTime = currentTime.difference(lastTime!).inMilliseconds;
      fps = 1000.0 / frameTime;
    }
    lastTime = DateTime.now();
    frameCount++;

    if (predictingObjectDetection || !mounted) return;

    setState(() {
      predictingObjectDetection = true;
    });

    if (_objectModel != null) {
      Stopwatch stopwatch = Stopwatch()..start();

      List<ResultObjectDetection> objDetect = await _objectModel!.getCameraImagePrediction(
        cameraImage,
        minimumScore: 0.2, // Lowered to capture more detections
        iOUThreshold: 0.2, // Lowered to reduce filtering
      );

      print('Frame $frameCount: Detected ${objDetect.length} objects');
      List<bool> newObjects = [false, false, false, false, false];
      for (var detectedObject in objDetect) {
        print('Class: ${detectedObject.className}, Score: ${detectedObject.score}, '
            'Box: [${detectedObject.rect.left}, ${detectedObject.rect.top}, '
            '${detectedObject.rect.width}, ${detectedObject.rect.height}]');

        if (detectedObject.className == 'Closed Eye' && labelFreq('Closed Eye', objDetect) >= 2) {
          if (!detectedClosed) {
            detectedClosed = true;
            eyesStopwatch = Stopwatch()..start();
            print('Detected 2 closed eyes, starting stopwatch');
          }
        } else if (detectedObject.className == 'Open Eye') {
          detectedClosed = false;
          eyesStopwatch.reset();
          await player.stop();
          print('Detected open eye, resetting sleepy detection');
        }

        if (detectedObject.className == 'Cigarette') {
          newObjects[2] = true;
        }
        if (detectedObject.className == 'Phone') {
          newObjects[3] = true;
        }
        if (detectedObject.className == 'Seatbelt') {
          newObjects[4] = true;
        }

        final className = detectedObject.className;
        if (className != null) {
          classFreq?[className] = (classFreq![className] ?? 0) + 1;
        }
      }

      if (detectedClosed && eyesStopwatch.elapsed.inMilliseconds >= 1000) { // Extended to 1s for reliability
        newObjects[1] = true;
        await player.play(AssetSource('sound_effects/beep.mp3'));
        print('Sleepy detected, playing alert');
      } else if (!detectedClosed) {
        eyesStopwatch.reset();
        await player.stop();
      }

      setState(() {
        objects = newObjects;
        print('Updated objects: $objects');
      });

      stopwatch.stop();
      widget.resultsCallback(objDetect, stopwatch.elapsed, fps, Map<String, int>.from(classFreq ?? {}));
    } else {
      print('Error: _objectModel is null');
    }

    if (mounted) {
      setState(() {
        predictingObjectDetection = false;
      });
    }
  }
  onLatestImageAvailable(CameraImage cameraImage) async {
    if (!mounted) return;
    print('Received camera frame: ${cameraImage.width}x${cameraImage.height}, '
        'format: ${cameraImage.format.group}');
    await runObjectDetection(cameraImage);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (!mounted) return;
    switch (state) {
      case AppLifecycleState.paused:
        await cameraController?.stopImageStream();
        print('Camera stream paused');
        break;
      case AppLifecycleState.resumed:
        if (cameraController != null && !cameraController!.value.isStreamingImages) {
          await cameraController?.startImageStream(onLatestImageAvailable);
          print('Camera stream resumed');
        }
        break;
      default:
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    cameraController?.dispose();
    player.dispose();
    print('CameraView disposed');
    super.dispose();
  }
}