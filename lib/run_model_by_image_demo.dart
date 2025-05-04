import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:pytorch_lite/pytorch_lite.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RunModelByImageDemo extends StatefulWidget {
  const RunModelByImageDemo({Key? key}) : super(key: key);

  @override
  _RunModelByImageDemoState createState() => _RunModelByImageDemoState();
}

class _RunModelByImageDemoState extends State<RunModelByImageDemo> {
  late ModelObjectDetection _objectModelYoloV8;

  String? textToShow;
  List? _prediction;
  File? _image;
  final ImagePicker _picker = ImagePicker();
  bool objectDetection = false;
  List<ResultObjectDetection?> detectedObjects = [];
  late int height;
  late int width;

  @override
  void initState() {
    super.initState();
    loadModel();
  }

  Future loadModel() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? pathObjectDetectionModel = prefs.getString('modelPath');
    String? labelsPath = prefs.getString('labelsPath');
    print(labelsPath);

    try {
      _objectModelYoloV8 = await PytorchLite.loadObjectDetectionModel(
        pathObjectDetectionModel!,
        5,
        640,
        640,
        labelPath: labelsPath,
        objectDetectionModelType: ObjectDetectionModelType.yolov8,
      );
    } catch (e) {
      if (e is PlatformException) {
        if (kDebugMode) {
          print("only supported for android, Error is $e");
        }
      } else {
        if (kDebugMode) {
          print("Error is $e");
        }
      }
    }
  }

  Future runObjectDetectionYoloV8() async {
    // Pick an image
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      final decodedImage = await decodeImageFromList(await image.readAsBytes());
      height = decodedImage.height; // Image height
      width = decodedImage.width; // Image width
    }

    Stopwatch stopwatch = Stopwatch()..start();

    detectedObjects = await _objectModelYoloV8.getImagePrediction(
      await File(image!.path).readAsBytes(),
      minimumScore: 0.1,
      iOUThreshold: 0.3,
    );
    textToShow = inferenceTimeAsString(stopwatch);

    if (kDebugMode) {
      print('object executed in ${stopwatch.elapsed.inMilliseconds} ms');
    }
    for (var element in detectedObjects) {
      if (kDebugMode) {
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
      }
    }

    setState(() {
      _image = File(image.path);
    });
  }

  String inferenceTimeAsString(Stopwatch stopwatch) =>
      "Inference Took ${stopwatch.elapsed.inMilliseconds} ms";

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => true,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('DMS Image Demo'),
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: detectedObjects.isNotEmpty
                  ? _image == null
                  ? const Text('No image selected.')
                  : _objectModelYoloV8.renderBoxesOnImage(
                _image!,
                detectedObjects,
              )
                  : _image == null
                  ? const Text('No image selected.')
                  : Image.file(_image!),
            ),
            Center(
              child: Visibility(
                visible: textToShow != null,
                child: Text(
                  "$textToShow",
                  maxLines: 3,
                ),
              ),
            ),
            TextButton(
              onPressed: runObjectDetectionYoloV8,
              child: const Text(
                "Choose Image From Gallery",
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
            Center(
              child: Visibility(
                visible: _prediction != null,
                child: Text(_prediction != null ? "${_prediction![0]}" : ""),
              ),
            )
          ],
        ),
      ),
    );
  }
}
