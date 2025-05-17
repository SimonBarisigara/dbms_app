import 'dart:developer';
import 'dart:io';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pytorch_lite/pytorch_lite.dart';
import 'camera_view_singleton.dart';

class CameraView extends StatefulWidget {
  final Function(List<ResultObjectDetection> recognitions, Duration inferenceTime, double fps) resultsCallback;

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
    const String pathObjectDetectionModel = "assets/dms.torchscript";
    const String labelsPath = "assets/dms_labels.txt";

    print('Attempting to load model: $pathObjectDetectionModel, labels: $labelsPath');

    try {
      // Verify model file existence
      await rootBundle.load(pathObjectDetectionModel);
      print('Model file $pathObjectDetectionModel verified');

      // Verify labels file existence
      await rootBundle.load(labelsPath);
      print('Labels file $labelsPath verified');
    } catch (e) {
      print('Error: Model or labels file not found: $e');
      setState(() {
        errorMessage = 'Model or labels file not found. Check pubspec.yaml and ensure files exist in assets/';
      });
      return;
    }

    try {
      // Load the object detection model
      _objectModel = await PytorchLite.loadObjectDetectionModel(
        pathObjectDetectionModel,
        5,
        640,
        640,
        labelPath: labelsPath,
        objectDetectionModelType: ObjectDetectionModelType.yolov8,
      );
      if (_objectModel?.labels != null && _objectModel!.labels.isNotEmpty) {
        classFreq = {for (var label in _objectModel!.labels) label: 0};
        print('Model loaded successfully. Labels: $classFreq');
      } else {
        print('Error: No valid labels found in $labelsPath');
        classFreq = {};
        setState(() {
          errorMessage = 'Invalid or empty labels in $labelsPath';
        });
      }
    } catch (e) {
      print('Error loading model: $e');
      setState(() {
        errorMessage = 'Failed to load model: $e';
      });
    }
  }

  void initStateAsync() async {
    WidgetsBinding.instance.addObserver(this);
    await loadModel();
    try {
      initializeCamera();
    } on CameraException catch (e) {
      switch (e.code) {
        case 'CameraAccessDenied':
          errorMessage = 'You have denied camera access. Please enable in settings.';
          break;
        case 'CameraAccessDeniedWithoutPrompt':
          errorMessage = 'Please go to Settings app to enable camera access.';
          break;
        case 'CameraAccessRestricted':
          errorMessage = 'Camera access is restricted.';
          break;
        case 'AudioAccessDenied':
          errorMessage = 'You have denied audio access.';
          break;
        case 'AudioAccessDeniedWithoutPrompt':
          errorMessage = 'Please go to Settings app to enable audio access.';
          break;
        case 'AudioAccessRestricted':
          errorMessage = 'Audio access is restricted.';
          break;
        default:
          errorMessage = 'Camera error: $e';
          break;
      }
      setState(() {});
    }
    setState(() {
      predicting = false;
    });
  }

  void initializeCamera() async {
    try {
      cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          errorMessage = 'No cameras available';
        });
        return;
      }
      var desc = cameras[cameraIndex];
      _camFrameRotation = Platform.isAndroid ? desc.sensorOrientation : 0;
      print('Camera is being initialized... $_camFrameRotation');
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
        print('Camera initialized. Preview size: $previewSize');
      } else {
        print('Warning: Preview size is null');
      }
      if (mounted) setState(() {});
    } catch (e) {
      print('Camera initialization error: $e');
      setState(() {
        errorMessage = 'Camera initialization failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Size screenSize = MediaQuery.of(context).size;
    double screenHeight = screenSize.height;
    print('Objects state: $objects');

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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                errorMessage.isEmpty ? 'Initializing camera...' : errorMessage,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              if (errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Ensure assets are declared in pubspec.yaml and files exist in assets/',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
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
              if (kDebugMode) {
                print('Camera Index = $cameraIndex');
              }
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
        if (_objectModel == null || objects.every((e) => !e))
          Positioned(
            bottom: 120,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _objectModel == null ? 'Model failed to load' : 'No behaviors detected',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
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
      Stopwatch stopwatch = Stopwatch()..start();

      List<ResultObjectDetection> objDetect = await _objectModel!.getCameraImagePrediction(
        cameraImage,
        rotation: cameraIndex == 0 ? 90 : 270,
        minimumScore: 0.1,
        iOUThreshold: 0.2,
      );

      print('Frame $frameCount: Detected ${objDetect.length} objects');
      for (var detectedObject in objDetect) {
        print('Class: ${detectedObject.className}, Score: ${detectedObject.score}, '
            'Box: [${detectedObject.rect.left}, ${detectedObject.rect.top}, '
            '${detectedObject.rect.width}, ${detectedObject.rect.height}]');
      }

      List<ResultObjectDetection> objDetectTemp = objDetect;
      objects[1] = false;
      objects[2] = false;
      objects[3] = false;
      objects[4] = false;
      for (var detectedObject in objDetectTemp) {
        if (detectedObject.className == 'Closed Eye' && labelFreq('Closed Eye', objDetectTemp) == 2 && detectedClosed == false) {
          classFreq?[detectedObject.className] = (classFreq![detectedObject.className] ?? 0) + 1;
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

        print('${detectedObject.className} = ${classFreq?[detectedObject.className]}');
      }
      print('eyesStopwatch: ${eyesStopwatch.elapsed.inSeconds}s, detectedClosed: $detectedClosed');

      if (eyesStopwatch.elapsed.inMilliseconds >= 100) {
        if (detectedClosed == false) {
          eyesStopwatch.reset();
          await player.stop();
        } else {
          objects[1] = true;
          await player.play(AssetSource('sound_effects/beep.mp3'));
        }
      }

      stopwatch.stop();
      widget.resultsCallback(objDetect, stopwatch.elapsed, fps);
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
    log('Received camera frame: ${cameraImage.width}x${cameraImage.height}, format: ${cameraImage.format.group}');
    runObjectDetection(cameraImage);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    cameraController?.dispose();
    player.dispose();
    super.dispose();
  }
}