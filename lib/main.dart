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
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
        ),
      ),
      home: const WelcomeScreen(),
    );
  }
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
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

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
}

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _driverIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _secureStorage = const FlutterSecureStorage();
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _driverIdController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        const String apiUrl = 'https://dbms-o3mb.onrender.com/api/driver-auth/login';
        final response = await http.post(
          Uri.parse(apiUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'driverId': _driverIdController.text.trim(),
            'password': _passwordController.text,
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final token = data['token'];
          final driver = data['driver'];

          await _secureStorage.write(key: 'jwt_token', value: token);
          await _secureStorage.write(key: 'driver_id', value: driver['driverId']);
          await _secureStorage.write(key: 'driver_name', value: driver['name']);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Login successful!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );

          await Future.delayed(const Duration(seconds: 1));
          if (mounted) {
            if (driver['passwordChanged'] == false) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => ChangePasswordDialog(
                  driverId: driver['driverId'],
                  currentPassword: _passwordController.text,
                ),
              );
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const ModelConfig(skipWelcome: true)),
              );
            }
          }
        } else {
          final errorData = jsonDecode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorData['error'] ?? 'Login failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Network error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    const Icon(
                      Icons.security,
                      size: 80,
                      color: Colors.indigo,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Driver Monitoring System',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sign in to continue',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _driverIdController,
                      decoration: InputDecoration(
                        labelText: 'Driver ID',
                        prefixIcon: const Icon(Icons.person, color: Colors.indigo),
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your driver ID';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock, color: Colors.indigo),
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    _isLoading
                        ? const CircularProgressIndicator(color: Colors.indigo)
                        : ElevatedButton(
                            onPressed: _handleLogin,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Sign In'),
                          ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ChangePasswordDialog extends StatefulWidget {
  final String driverId;
  final String currentPassword;

  const ChangePasswordDialog({
    Key? key,
    required this.driverId,
    required this.currentPassword,
  }) : super(key: key);

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleChangePassword() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        const String apiUrl = 'https://dbms-o3mb.onrender.com/api/driver-auth/set-password';
        final response = await http.post(
          Uri.parse(apiUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'driverId': widget.driverId,
            'currentPassword': _currentPasswordController.text,
            'newPassword': _newPasswordController.text,
          }),
        );

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password changed successfully!'),
              backgroundColor: Colors.green,
            ),
          );

          await Future.delayed(const Duration(seconds: 1));
          if (mounted) {
            Navigator.of(context).pop();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const ModelConfig(skipWelcome: true)),
            );
          }
        } else {
          final errorData = jsonDecode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorData['error'] ?? 'Failed to change password'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Network error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_reset, size: 50, color: Colors.indigo),
                const SizedBox(height: 16),
                const Text(
                  'Change Your Password',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please set a new password for your account.',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _currentPasswordController,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    prefixIcon: const Icon(Icons.lock, color: Colors.indigo),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your current password';
                    }
                    if (value != widget.currentPassword) {
                      return 'Incorrect current password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _newPasswordController,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    prefixIcon: const Icon(Icons.lock_outline, color: Colors.indigo),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a new password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    if (value == widget.currentPassword || value == widget.driverId) {
                      return 'New password must be different';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    prefixIcon: const Icon(Icons.lock_outline, color: Colors.indigo),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your new password';
                    }
                    if (value != _newPasswordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                _isLoading
                    ? const CircularProgressIndicator(color: Colors.indigo)
                    : Row(
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
                              onPressed: () {
                                Navigator.of(context).pop();
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
                              onPressed: _handleChangePassword,
                              child: const Text('Change Password'),
                            ),
                          ),
                        ],
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
class ModelConfig extends StatefulWidget {
  final bool skipWelcome;

  const ModelConfig({Key? key, this.skipWelcome = false}) : super(key: key);

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
  final _secureStorage = const FlutterSecureStorage();

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

    showWelcome = !widget.skipWelcome;
    _checkAuth();
    acceptTerms();
    dmsModelInfoFuture = _initModelState();
    requestPermissions();

    if (showWelcome) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            showWelcome = false;
          });
        }
      });
    }
  }

  Future<void> _checkAuth() async {
    final token = await _secureStorage.read(key: 'jwt_token');
    if (token == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  Future<void> _handleLogout() async {
    final token = await _secureStorage.read(key: 'jwt_token');
    if (token != null) {
      try {
        const String apiUrl = 'https://dbms-o3mb.onrender.com/api/driver-auth/logout';
        await http.post(
          Uri.parse(apiUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
      } catch (e) {
        print('Logout API error: $e');
      }
      await _secureStorage.delete(key: 'jwt_token');
      await _secureStorage.delete(key: 'driver_id');
      await _secureStorage.delete(key: 'driver_name');
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Logged out successfully!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
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

  Widget _buildTermsDialog() {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('DMS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _handleLogout,
          ),
        ],
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
