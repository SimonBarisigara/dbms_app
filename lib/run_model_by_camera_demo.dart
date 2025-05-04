import 'package:dms_demo/ui/box_widget.dart';
import 'package:flutter/material.dart';
import 'package:pytorch_lite/pytorch_lite.dart';

import 'ui/camera_view.dart';

class RunModelByCameraDemo extends StatefulWidget {
  const RunModelByCameraDemo({super.key});

  @override
  State<RunModelByCameraDemo> createState() => _RunModelByCameraDemoState();
}

class _RunModelByCameraDemoState extends State<RunModelByCameraDemo> {
  List<ResultObjectDetection>? results;
  Duration? objectDetectionInferenceTime;
  double? fps;

  @override
  Widget build(BuildContext context) {
    Size screenSize = MediaQuery.of(context).size;
    double screenWidth = screenSize.width;
    double screenHeight = screenSize.height;
    return WillPopScope(
      onWillPop: () async => true,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('DMS Camera Demo'),
        ),
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            CameraView(resultsCallback),
            // Bounding boxes
            boundingBoxes2(results),
            Positioned(
              top: screenHeight / 3,
              right: 10,
              child: objectDetectionInferenceTime != null
                  ? Column(
                      children: [
                        InfoCard(
                          Icons.timer_outlined,
                          '${objectDetectionInferenceTime!.inMilliseconds} ms',
                        ),
                        const SizedBox(height: 5),
                        InfoCard(
                          Icons.thirty_fps_select_sharp,
                          '${fps?.toStringAsFixed(1)} FPS',
                        ),
                      ],
                    )
                  : Container(),
            ),
            //Bottom Sheet
            // Align(
            //   alignment: Alignment.bottomCenter,
            //   child: DraggableScrollableSheet(
            //     initialChildSize: 0.2,
            //     minChildSize: 0.1,
            //     maxChildSize: 0.5,
            //     builder: (_, ScrollController scrollController) => Container(
            //       width: double.maxFinite,
            //       decoration: BoxDecoration(
            //         color: Colors.white.withOpacity(0.9),
            //       ),
            //       child: SingleChildScrollView(
            //         controller: scrollController,
            //         child: Center(
            //           child: Column(
            //             mainAxisSize: MainAxisSize.min,
            //             children: [
            //               const Icon(Icons.keyboard_arrow_up,
            //                   size: 48, color: Colors.orange),
            //               Padding(
            //                 padding: const EdgeInsets.all(8.0),
            //                 child: Column(
            //                   children: [
            //                     if (results != null)
            //                       Column(
            //                         children: List.generate(
            //                           results!.length,
            //                           (index) => StatsRow(
            //                             'Object ${index + 1}',
            //                             results?[index].className,
            //                           ),
            //                         ),
            //                       ),
            //                     // if (results!.length > 0)
            //                     //   StatsRow('Object Detection Inference time:',
            //                     //       '${results?[0].className}')
            //                   ],
            //                 ),
            //               )
            //             ],
            //           ),
            //         ),
            //       ),
            //     ),
            //   ),
            // )
          ],
        ),
      ),
    );
  }

  /// Returns Stack of bounding boxes
  Widget boundingBoxes2(List<ResultObjectDetection>? results) {
    if (results == null) {
      return Container();
    }
    return Stack(
      children: results.map((e) => BoxWidget(result: e)).toList(),
    );
  }

  void resultsCallback(
      List<ResultObjectDetection> results, Duration inferenceTime, double fps) {
    if (!mounted) {
      return;
    }
    setState(() {
      this.results = results;
      objectDetectionInferenceTime = inferenceTime;
      this.fps = fps;
      for (var element in results) {
        print({
          "rect": {
            "left": element.rect.left,
            "top": element.rect.top,
            "width": element.rect.width,
            "height": element.rect.height,
            "right": element.rect.right,
            "bottom": element.rect.bottom,
            "Class name": element.className,
          },
        });
      }
    });
  }
}

class StatsRow extends StatelessWidget {
  final String title;
  final String? value;

  const StatsRow(this.title, this.value, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(value!)
        ],
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  final IconData iconData;
  final String text;

  const InfoCard(this.iconData, this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      padding: const EdgeInsets.only(bottom: 10, top: 10),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(90),
        borderRadius: const BorderRadius.all(
          Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            iconData,
            size: 30,
            color: Colors.white,
          ),
          const SizedBox(
            height: 5,
          ),
          Text(
            text,
            style: const TextStyle(fontSize: 15, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
