import 'dart:async';
import 'dart:core';
import 'dart:developer';
// ignore: unused_import
import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:camera/camera.dart';
// ignore: unnecessary_import
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:pytorch_lite/pytorch_lite.dart';
import 'dart:convert';
import 'camera_view_singleton.dart';
import '../main.dart';
class CameraView extends StatefulWidget {
  final Function(List<ResultObjectDetection> recognitions, Duration inferenceTime, double fps) resultsCallback;

  const CameraView(this.resultsCallback, {Key? key}) : super(key: key);

  @override
  _CameraViewState createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> with WidgetsBindingObserver {
  List<bool> objects = [false, false, false, false, false]; // [unused, Sleepy, Cigarette, Phone, Seatbelt]
  final player = AudioPlayer();
  late List<CameraDescription> cameras;
  CameraController? cameraController;
  bool predictingObjectDetection = false;
  ModelObjectDetection? _objectModel;
  int _camFrameRotation = 0;  String errorMessage = "";
  int cameraIndex = 0;
  bool isLoadingModel = true;
  String detectionStatus = "Initializing...";
  Map<String, double> confidenceScores = {};
  Map<String, DateTime> lastIncidentLogged = {};
  static const Duration incidentLogInterval = Duration(seconds: 5);  final _secureStorage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initStateAsync();
  }

  Future<void> initStateAsync() async {
    await loadModel();
    try {
      await initializeCamera();
    } on CameraException catch (e) {
      handleCameraException(e);
    }
    setState(() {
      if (_objectModel != null && errorMessage.isEmpty) {
        detectionStatus = "No objects detected";
      }
    });
  }

  void handleCameraException(CameraException e) {
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
      default:
        errorMessage = 'Camera error: $e';
    }
    detectionStatus = errorMessage;
    setState(() {});
  }

  Future<void> loadModel() async {
    setState(() {
      isLoadingModel = true;
      errorMessage = "";
      detectionStatus = "Loading model...";
    });

    const modelPath = "assets/dms.torchscript";
    const labelsPath = "assets/dms_labels.txt";

    try {
      await DefaultAssetBundle.of(context).load(modelPath);
      await DefaultAssetBundle.of(context).load(labelsPath);

      _objectModel = await PytorchLite.loadObjectDetectionModel(
        modelPath,
        5,
        640,
        640,
        labelPath: labelsPath,
        objectDetectionModelType: ObjectDetectionModelType.yolov8,
      );

      if (_objectModel?.labels == null || _objectModel!.labels.isEmpty) {
        throw Exception('Invalid or empty labels in $labelsPath');
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load model: $e';
        detectionStatus = "Model failed to load";
      });
    } finally {
      setState(() {
        isLoadingModel = false;
      });
    }
  }

  Future<String?> getJwtToken() async {
    try {
      final token = await _secureStorage.read(key: 'jwt_token');
      if (token == null) {
        log('No token found in secure storage');
        return null;
      }
      log('Retrieved token: $token');
      return token;
    } catch (e) {
      log('Error accessing secure storage: $e');
      return null;
    }
  }

  Future<void> logIncident(String type, double confidence) async {
    final token = await getJwtToken();
    if (token == null) {
      log('No JWT token found for $type');
      setState(() => detectionStatus = "Please log in to continue");
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
      return;
    }

    const apiUrl = 'https://dbms-o3mb.onrender.com/api/driver-auth/log-incident';
    final severity = type == 'Sleepy' ? 5 : 3;
    final details = 'Detected $type with confidence ${confidence.toStringAsFixed(2)} at ${DateTime.now().toIso8601String()}';

    final body = jsonEncode({
      'type': type,
      'severity': severity,
      'details': details,
    });

    log('Sending request to $apiUrl with body: $body');

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      ).timeout(const Duration(seconds: 10));

      log('API Response: ${response.statusCode}, ${response.body}');

      if (response.statusCode == 201) {
        log('Successfully logged $type');
        setState(() => detectionStatus = 'Logged: $type');
        lastIncidentLogged[type] = DateTime.now();
      } else {
        final errorData = jsonDecode(response.body);
        final errorMsg = errorData['error'] ?? 'Unknown error';
        log('Failed to log $type: Status ${response.statusCode}, $errorMsg');
        setState(() => detectionStatus = 'Error: $errorMsg');
      }
    } on SocketException {
      log('Network error - no internet connection');
      setState(() => detectionStatus = 'Error: No internet');
    } on TimeoutException {
      log('Request timed out');
      setState(() => detectionStatus = 'Error: Timeout');
    } catch (e) {
      log('Unexpected error: $e');
      setState(() => detectionStatus = 'Error: $e');
    }
  }

  Future<void> initializeCamera() async {
    try {
      cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('No cameras available');
      }

      final desc = cameras[cameraIndex];
      _camFrameRotation = Platform.isAndroid ? desc.sensorOrientation : 0;

      cameraController = CameraController(
        desc,
        ResolutionPreset.low,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888,
        enableAudio: false,
      );

      await cameraController?.initialize();
      await cameraController?.startImageStream(onLatestImageAvailable);

      final previewSize = cameraController?.value.previewSize;
      if (previewSize != null) {
        CameraViewSingleton.inputImageSize = previewSize;
        CameraViewSingleton.screenSize = MediaQuery.of(context).size;
        CameraViewSingleton.ratio = cameraController!.value.aspectRatio;
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Camera initialization failed: $e';
        detectionStatus = "Camera initialization failed";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (cameraController == null || !cameraController!.value.isInitialized) {
      return buildLoadingScreen();
    }

    return WillPopScope(
      onWillPop: () async {
        await cameraController?.stopImageStream();
        return true;
      },
      child: Stack(
        children: [
          buildCameraPreview(),
          buildIconsOverlay(),
          buildDetectionStatus(),
          buildSwitchCameraButton(),
        ],
      ),
    );
  }

  Widget buildLoadingScreen() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            isLoadingModel 
                ? const CircularProgressIndicator(color: Colors.white)
                : const Icon(Icons.error_outline, color: Colors.white, size: 48),
            const SizedBox(height: 16),
            Text(
              isLoadingModel ? 'Loading model...' : errorMessage,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget buildCameraPreview() {
    return cameraIndex == 0
        ? CameraPreview(cameraController!)
        : Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationY(math.pi),
            child: CameraPreview(cameraController!),
          );
  }

  Widget buildIconsOverlay() {
    return Positioned(
      top: MediaQuery.of(context).size.height / 4,
      left: 8,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.0),
          color: Colors.black.withAlpha(60),
        ),
        child: Column(
          children: [
            buildIconWithLabel('Sleepy', Icons.bedtime, objects[1]),
            const SizedBox(height: 6),
            buildIconWithLabel('Cigarette', Icons.smoking_rooms_sharp, objects[2]),
            const SizedBox(height: 6),
            buildIconWithLabel('Phone', Icons.phone_android, objects[3]),
            const SizedBox(height: 6),
            buildIconWithLabel('Seatbelt', Icons.safety_check, !objects[4]),
          ],
        ),
      ),


    );
  }
  Widget buildIconWithLabel(String label, IconData icon, bool isActive) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? Colors.red : Colors.transparent,
              width: 3,
            ),
          ),
          width: 40,
          height: 40,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }

  Widget buildDetectionStatus() {
    return Positioned(
      bottom: 100,
      left: 8,
      right: 8,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          _objectModel == null ? 'Model failed to load' : detectionStatus,
          style: const TextStyle(color: Colors.white, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget buildSwitchCameraButton() {
    return Positioned(
      bottom: 50,
      right: 10,
      child: FloatingActionButton(
        onPressed: switchCamera,
        tooltip: 'Switch Camera',
        mini: true,
        backgroundColor: Colors.black.withAlpha(90),
        child: const Icon(Icons.cameraswitch),
      ),
    );
  }

  Future<void> switchCamera() async {
    setState(() => cameraIndex = cameraIndex == 0 ? 1 : 0);
    await cameraController?.stopImageStream();
    await initializeCamera();
  }

  Future<void> runObjectDetection(CameraImage cameraImage) async {
    if (predictingObjectDetection || _objectModel == null) return;
    if (!mounted) return;

    setState(() => predictingObjectDetection = true);

    try {
      final stopwatch = Stopwatch()..start();
      final objDetect = await _objectModel!.getCameraImagePrediction(
        cameraImage,
        rotation: cameraIndex == 0 ? 90 : 270,
        minimumScore: 0.1,
        iOUThreshold: 0.1,
      );

      processDetections(objDetect);
      stopwatch.stop();
      widget.resultsCallback(objDetect, stopwatch.elapsed, 0.0);
    } catch (e) {
      log('Object detection error: $e');
    } finally {
      if (mounted) {
        setState(() => predictingObjectDetection = false);
      }
    }
  }

  void processDetections(List<ResultObjectDetection> objDetect) {
    objects = [false, false, false, false, false];
    confidenceScores.clear();
    String detectedLabels = "";

    for (var detectedObject in objDetect) {
      final className = detectedObject.className;
      if (className == null) continue;

      confidenceScores[className] = detectedObject.score;
      detectedLabels += '$className ';

      switch (className) {
        case 'Closed Eye':
          if (labelFreq('Closed Eye', objDetect) >= 2) {
            objects[1] = true; // Sleepy
          }
          break;
        case 'Cigarette':
          objects[2] = true;
          break;
        case 'Phone':
          objects[3] = true;
          break;
        case 'Seatbelt':
          objects[4] = true;
          break;
      }
    }

    handleIncidentLogging();

    setState(() {
      detectionStatus = objDetect.isEmpty 
          ? "No objects detected" 
          : "Detected: ${detectedLabels.trim()}";
    });

    if (objects[1]) {
      player.play(AssetSource('sound_effects/beep.mp3'));
    } else {
      player.stop();
    }
  }

  void handleIncidentLogging() {
    final now = DateTime.now();
    
    if (objects[1] && shouldLogIncident('Sleepy', now)) {
      logIncident('Sleepy', confidenceScores['Closed Eye'] ?? 0.1);
    }
    if (objects[2] && shouldLogIncident('Cigarette', now)) {
      logIncident('Cigarette', confidenceScores['Cigarette'] ?? 0.1);
    }
    if (objects[3] && shouldLogIncident('Phone', now)) {
      logIncident('Phone', confidenceScores['Phone'] ?? 0.1);
    }
    if (!objects[4] && shouldLogIncident('Seatbelt Absence', now)) {
      logIncident('Seatbelt Absence', 0.1);
    }
  }

  bool shouldLogIncident(String type, DateTime now) {
    return lastIncidentLogged[type] == null || 
           now.difference(lastIncidentLogged[type]!) > incidentLogInterval;
  }
  
  void onLatestImageAvailable(CameraImage cameraImage) {
    if (!mounted) return;
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

class Hannah {
}
  int labelFreq(String label, List<ResultObjectDetection> objects) {
    return objects.where((o) => o.className == label).length;
  }