# dms_demo

Driver Monitoring System Flutter App
Overview

This is a Flutter app designed to monitor a driver's behavior using an advanced YOLOv8 model for real-time object detection. The app can detect different objects in the driver's surroundings, such as:

Open Eyes
Closed Eyes
Cigarettes
Phones
Seatbelts
The primary goal of this app is to improve driver safety by alerting them or a monitoring system when potentially dangerous behaviors or objects are detected. This README will guide you through setting up and using this driver monitoring system.

Prerequisites

Before using this app, make sure you have the following prerequisites:

Flutter and Dart installed on your computer. You can follow the official Flutter installation guide: Flutter Installation.
A compatible mobile device or an Android/iOS emulator.
Usage

Open the app on your device or emulator.
The app will use your device's camera to begin real-time object detection.
The YOLOv8 model will identify objects within the driver's field of view.
Detected objects will be categorized as "Open Eye," "Closed Eye," "Cigarette," "Phone," or "Seatbelt."
If an unsafe behavior or object is detected, the app may issue warnings or alerts to the driver.
You can customize the way alerts work and set your own safety thresholds by adjusting the app's code.
To stop the monitoring, simply close the app or navigate away from the detection screen.