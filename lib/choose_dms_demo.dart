import 'package:dms_demo/run_model_by_camera_demo.dart';
import 'package:dms_demo/run_model_by_image_demo.dart';
import 'package:flutter/material.dart';

class ChooseDmsDemo extends StatelessWidget {
  const ChooseDmsDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextButton(
          onPressed: () => {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const RunModelByCameraDemo()),
            )
          },
          child: const Text(
            "Start a Trip",
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        ),
        TextButton(
          onPressed: () => {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const RunModelByImageDemo()),
            )
          },
          child: const Text(
            "Run Model with Image",
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        )
      ],
    );
  }
}
