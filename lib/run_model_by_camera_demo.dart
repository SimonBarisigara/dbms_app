import 'package:dms_demo/ui/box_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pytorch_lite/pytorch_lite.dart';
import 'ui/camera_view.dart';
import 'analytics_page.dart';

class RunModelByCameraDemo extends StatefulWidget {
  const RunModelByCameraDemo({super.key});

  @override
  State<RunModelByCameraDemo> createState() => _RunModelByCameraDemoState();
}

class _RunModelByCameraDemoState extends State<RunModelByCameraDemo> {
  List<ResultObjectDetection>? results;
  Duration? objectDetectionInferenceTime;
  double? fps;
  Map<String, int>? classFreq;

  @override
  Widget build(BuildContext context) {
    Size screenSize = MediaQuery.of(context).size;
    double screenWidth = screenSize.width;
    double screenHeight = screenSize.height;
    return WillPopScope(
      onWillPop: () async => true,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'DMS',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.blue.shade900,
          elevation: 2,
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.blue.shade900, Colors.blue.shade600],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              CameraView((results, inferenceTime, fps, classFreq) {
                resultsCallback(results, inferenceTime, fps, classFreq);
              }),
              boundingBoxes2(results),
              Positioned(
                top: screenHeight / 3,
                right: 16,
                child: objectDetectionInferenceTime != null
                    ? Column(
                        children: [
                          InfoCard(
                            Icons.timer_outlined,
                            '${objectDetectionInferenceTime!.inMilliseconds} ms',
                          ),
                          const SizedBox(height: 8),
                          InfoCard(
                            Icons.thirty_fps_select_sharp,
                            '${fps?.toStringAsFixed(1)} FPS',
                          ),
                        ],
                      )
                    : Container(),
              ),
              Positioned(
                bottom: 60,
                left: 16,
                child: FloatingActionButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AnalyticsPage(
                          results: results ?? [],
                          classFreq: classFreq ?? {},
                        ),
                      ),
                    );
                  },
                  tooltip: 'View Analytics',
                  backgroundColor: Colors.white,
                  elevation: 4,
                  child: Icon(
                    Icons.analytics,
                    color: Colors.blue.shade900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

  }  Widget boundingBoxes2(List<ResultObjectDetection>? results) {
    if (results == null) {
      return Container();
    }
    return Stack(
      children: results.map((e) => BoxWidget(result: e)).toList(),
    );
  }

  void resultsCallback(
      List<ResultObjectDetection> results, Duration inferenceTime, double fps, Map<String, int> classFreq) {
    if (!mounted) {
      return;
    }
    setState(() {
      this.results = results;
      this.objectDetectionInferenceTime = inferenceTime;
      this.fps = fps;
      this.classFreq = classFreq;
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
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.blue.shade900,
            ),
          ),
          Text(
            value ?? 'Unknown',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade800,
            ),
          ),
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
      width: 100,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            iconData,
            size: 24,
            color: Colors.blue.shade900,
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.blue.shade900,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}