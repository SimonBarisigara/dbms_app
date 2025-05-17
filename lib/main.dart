import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'choose_dms_demo.dart';
import 'classes/dms_model_info.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.indigo,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        textButtonTheme: TextButtonThemeData(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.all<Color>(Colors.indigo),
            foregroundColor: WidgetStateProperty.all<Color>(Colors.white),
            shape: WidgetStateProperty.all<RoundedRectangleBorder>(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            padding: WidgetStateProperty.all<EdgeInsets>(
              const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.all<Color>(Colors.indigo),
            foregroundColor: WidgetStateProperty.all<Color>(Colors.white),
            elevation: WidgetStateProperty.all<double>(4),
            shape: WidgetStateProperty.all<RoundedRectangleBorder>(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            padding: WidgetStateProperty.all<EdgeInsets>(
              const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            textStyle: WidgetStateProperty.all<TextStyle>(
              const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.indigo, width: 2),
          ),
        ),
      ),
      home: const ModelConfig(),
    );
  }
}

class ModelConfig extends StatefulWidget {
  const ModelConfig({Key? key}) : super(key: key);

  @override
  State<ModelConfig> createState() => _ModelConfigState();
}

class _ModelConfigState extends State<ModelConfig> with SingleTickerProviderStateMixin {
  bool modelDownloading = false;
  bool termsAccepted = false;
  bool askForUpdate = true;
  bool showWelcome = true;
  late Future<DmsModelInfo> dmsModelInfoFuture;
  late DmsModelInfo dmsModelInfo;
  late Future<bool> isModelAvailable;
  late Future<bool> isUpdateAvailable;
  String downloadProgressString = '0%';
  double downloadProgressDouble = 0.0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );
    _animationController.forward();
    
    acceptTerms();
    dmsModelInfoFuture = _initModelState();
    requestPermissions();
    
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          showWelcome = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void acceptTerms() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool? termsAcceptedVal = prefs.getBool('termsAccepted');
    if (termsAcceptedVal != null && termsAcceptedVal) {
      setState(() {
        termsAccepted = true;
      });
    }
  }

  void updateAcceptedTerms() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('termsAccepted', true);
  }

  void requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.storage,
    ].request();
    if (statuses[Permission.camera] != PermissionStatus.granted ||
        statuses[Permission.storage] != PermissionStatus.granted) {
      requestPermissions();
    }
  }

  Future<DmsModelInfo> _initModelState() async {
    try {
      const repoUrl =
          "https://raw.githubusercontent.com/habbas11/test_json/main/DMS_Version.json";

      final dio = Dio();
      Response response = await dio.get(
        repoUrl,
        options: Options(
          headers: {
            'Accept': 'application/vnd.github.v4+raw',
            'Accept-Encoding': 'identity',
          },
        ),
      );
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.data);
        dmsModelInfo = DmsModelInfo.fromJson(jsonData);
        return dmsModelInfo;
      } else {
        throw Exception('Failed to load data.');
      }
    } catch (e) {
      throw Exception(e);
    }
  }

  Future<bool> _isModelAvailable() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool? modelDownloaded = prefs.getBool('modelDownloaded');
    if (modelDownloaded != null && modelDownloaded) return true;
    return false;
  }

  Future<bool> _isUpdateAvailable() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final modelVersion = prefs.getInt('modelVersion');
      final lastVersion = dmsModelInfo.version;
      if (modelVersion != lastVersion) return true;
      return false;
    } catch (e) {
      throw Exception(e);
    }
  }

  void initFutures() {
    isModelAvailable = _isModelAvailable();
    isUpdateAvailable = _isUpdateAvailable();
  }

  Future<void> updateModel() async {
    final modelUrl = dmsModelInfo.modelLink;
    final modelFileName = dmsModelInfo.modelName;
    final labelsUrl = dmsModelInfo.labelsLink;
    const labelsFileName = 'dms_labels.txt';

    setState(() {
      modelDownloading = true;
    });

    Directory? downloadsDirectory = await getDownloadsDirectory();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final dio = Dio();
    await dio.download(modelUrl, '${downloadsDirectory!.path}/$modelFileName',
        onReceiveProgress: (received, total) async {
      if (total != -1) {
        setState(() {
          downloadProgressString =
              "${((received / total) * 100).toStringAsFixed(0)}%";
          downloadProgressDouble = received / total;
        });
        if (received == total) {
          await prefs.setBool('modelDownloaded', true);
          await prefs.setInt('modelVersion', dmsModelInfo.version);
          await prefs.setString('modelName', dmsModelInfo.modelName);
          await prefs.setString(
              'modelPath', '${downloadsDirectory.path}/$modelFileName');
        }
      }
    });

    await dio.download(
      labelsUrl,
      '${downloadsDirectory.path}/$labelsFileName',
      options: Options(
        headers: {
          'Accept': 'application/vnd.github.v4+raw',
          'Accept-Encoding': 'identity',
        },
      ),
    );
    await prefs.setString(
        'labelsPath', '${downloadsDirectory.path}/$labelsFileName');
  }

  Widget _buildWelcomeScreen() {
    return Scaffold(
      backgroundColor: Colors.indigo,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FadeTransition(
              opacity: _fadeAnimation,
              child: const Icon(
                Icons.security,
                size: 100,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            FadeTransition(
              opacity: _fadeAnimation,
              child: const Text(
                'Welcome to DMS',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 10),
            FadeTransition(
              opacity: _fadeAnimation,
              child: const Text(
                'Driver Monitoring System',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermsDialog() {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: const Text(
        'Terms and Conditions',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.privacy_tip, size: 50, color: Colors.indigo),
            const SizedBox(height: 16),
            Text.rich(
              TextSpan(
                text: 'By continuing, you agree to our ',
                style: const TextStyle(color: Colors.black87, fontSize: 16),
                children: <TextSpan>[
                  TextSpan(
                    text: 'Terms of Service and Privacy Policy',
                    style: const TextStyle(
                      color: Colors.indigo,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.bold,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () async {
                        final Uri url = Uri.parse(
                            'https://github.com/SimonBarisigara/dbms_app/blob/main/lib/terms.md');
                        if (!await launchUrl(url)) {
                          throw Exception('Could not launch $url');
                        }
                      },
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: Colors.grey[200],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  SystemNavigator.pop();
                },
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.black87),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: () => setState(() {
                  termsAccepted = true;
                  updateAcceptedTerms();
                }),
                child: const Text('Agree'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDownloadDialog(String title, String message) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            modelDownloading
                ? Column(
                    children: [
                      CircularPercentIndicator(
                        radius: 60.0,
                        lineWidth: 10.0,
                        percent: downloadProgressDouble,
                        center: Text(
                          downloadProgressString,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        progressColor: Colors.indigo,
                        circularStrokeCap: CircularStrokeCap.round,
                        backgroundColor: Colors.indigo.withOpacity(0.1),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Downloading model...',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  )
                : Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
            const SizedBox(height: 24),
            if (!modelDownloading)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (askForUpdate)
                    TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.grey[200],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => setState(() {
                        askForUpdate = false;
                      }),
                      child: const Text(
                        'Skip',
                        style: TextStyle(color: Colors.black87),
                      ),
                    ),
                  ElevatedButton(
                    onPressed: () async {
                      await updateModel();
                      setState(() {
                        askForUpdate = false;
                      });
                    },
                    child: Text(modelDownloading ? 'Downloading...' : 'Download'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (showWelcome) {
      return _buildWelcomeScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('DMS'),
      ),
      body: Center(
        child: termsAccepted
            ? FutureBuilder(
                future: Future.wait([dmsModelInfoFuture]),
                builder: (context, AsyncSnapshot<List<DmsModelInfo>> snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Colors.indigo,
                      ),
                    );
                  }
                  initFutures();
                  return FutureBuilder(
                    future: Future.wait([isModelAvailable, isUpdateAvailable]),
                    builder: (context, AsyncSnapshot<List<bool>> snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Colors.indigo,
                          ),
                        );
                      }
                      final isModelAvailable = snapshot.data?[0] ?? false;
                      final isUpdateAvailable = snapshot.data?[1] ?? false;
                      
                      if (!isModelAvailable) {
                        return _buildDownloadDialog(
                          'Model Required',
                          'To use this application, you need to download the required model files.',
                        );
                      } else if (isUpdateAvailable && askForUpdate) {
                        return _buildDownloadDialog(
                          'Update Available',
                          'A new version of the model is available. Would you like to download it now?',
                        );
                      }
                      return const ChooseDmsDemo();
                    },
                  );
                },
              )
            : _buildTermsDialog(),
      ),
    );
  }
}