import 'edit_form_page.dart';
import 'gallery_import.dart';
import 'loading_page.dart';
import 'settings.dart';
import 'theme_manager.dart';

import 'package:image_cropper/image_cropper.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemChrome, SystemUiMode, rootBundle;
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'upload_service.dart';
import 'dart:convert';


void main(){

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'OCRganize',
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: themeNotifier.value,
          debugShowCheckedModeBanner: false,
          home: const CameraPage(title: "Take a Picture"),
        );
      },
    );
  }
}

class CameraPage extends StatefulWidget {
  const CameraPage({super.key, required this.title});

  final String title;
  @override
  CameraPageState createState() => CameraPageState();
}

class CameraPageState extends State<CameraPage> with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  late final List<CameraDescription> _cameras;
  File? _latestGalleryImage;
  bool _isHandwritten = true; // oben in CameraPageState hinzufügen


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initCamera();
    _loadLatestGalleryImage();
    _loadTheme(); // Theme beim Start der Seite laden
  }

  // Lädt das Theme aus SharedPreferences und setzt es in den themeNotifier
  Future<void> _loadTheme() async {
    final theme = await ThemeManager.loadTheme();
    themeNotifier.value = ThemeManager.getThemeMode(theme); // Setze den ThemeMode im Notifier
  }


  Future<void> initCamera() async {
    _cameras = await availableCameras();
    // Initialize the camera with the first camera in the list
    await onNewCameraSelected(_cameras.first);
  }

  Future<void> _loadLatestGalleryImage() async {
    final directory = await getExternalStorageDirectory();
    if (directory != null) {
      final imageFiles = directory
          .listSync()
          .whereType<File>()
          .where((file) =>
      file.path.toLowerCase().endsWith('.jpg') ||
          file.path.toLowerCase().endsWith('.png'))
          .toList();
      if (imageFiles.isNotEmpty) {
        imageFiles.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
        setState(() {
          _latestGalleryImage = imageFiles.first;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      // Free up memory when camera not active
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      // Reinitialize the camera with same properties
      onNewCameraSelected(cameraController.description);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<XFile?> capturePhoto() async {
    final CameraController? cameraController = _controller;
    if (cameraController!.value.isTakingPicture) {
      // A capture is already pending, do nothing.
      return null;
    }
    try {
      await cameraController.setFlashMode(FlashMode.off);
      XFile file = await cameraController.takePicture();
      return file;
    } on CameraException catch (e) {
      debugPrint('Error occured while taking picture: $e');
      return null;
    }
  }

  void _onTakePhotoPressed() async {
    final xFile = await capturePhoto();
    if (xFile != null) {
      if (xFile.path.isNotEmpty) {
        await _onPictureTaken(xFile); // direkt nach dem Foto den Crop starten
      }
    }
  }

  Future<void> _onPictureTaken(XFile image) async {
    final croppedImage = await _startCrop(image.path);

    if (croppedImage == null) {
      print("Zuschneiden abgebrochen");
      return;
    }

    // Zeige Ladescreen
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoadingPage()),
    );

    final imageFile = File(croppedImage);
    final serverResponse = await UploadService.uploadImage(
      imageFile,
      isHandwritten: _isHandwritten,
    );

    Map<String, dynamic>? parsedData;

    if (serverResponse != null) {
      print("Antwort vom Server: $serverResponse");

      try {
        final decoded = jsonDecode(serverResponse);
        final fields = decoded['fields'];
        parsedData = {
          'Titel': fields['title'] ?? '',
          'Datum': (fields['date'] ?? '').split(';'),
          'Startzeit': (fields['start_time'] ?? '').split(';'),
          'Endzeit': (fields['end_time'] ?? '').split(';'),
          'Beschreibung': fields['description'] ?? '',
          'Location': fields['location'] ?? '',
          'Enddatum': (fields['end_date'] ?? '').split(';'),
        };
      } catch (e) {
        print("Fehler beim Parsen: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Fehler beim Verarbeiten der Serverantwort.")),
        );
        parsedData = await loadDummyData(); // Fallback
      }
    } else {
      print("Upload fehlgeschlagen – Dummydaten werden genutzt");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Fehler beim Upload. Dummydaten werden genutzt.")),
      );
      parsedData = await loadDummyData();
    }

    if (!context.mounted) return;

    // Ladebildschirm durch EditForm ersetzen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => EditFormPage(
          data: parsedData!,
          imagePath: croppedImage,
        ),
      ),
    );
  }

  Future<String?> _startCrop(String imagePath) async {

    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);

    final cropped = await ImageCropper().cropImage(
      sourcePath: imagePath,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Zuschneiden',
          toolbarColor: _getContainerColor(context),  // Dynamische Toolbar-Farbe,
          toolbarWidgetColor: _getContrastColor(context),
          backgroundColor: _getContainerColor(context),
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
          hideBottomControls: false,
          showCropGrid: true,
          cropFrameStrokeWidth: 2,
          activeControlsWidgetColor: Colors.indigo,
          statusBarColor: _getContainerColor(context),
        ),
      ],
    );

    // UI wieder zurücksetzen (StatusBar & NavBar anzeigen)
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    print("SUCCESS CROP!");
    return cropped?.path;
  }

  // Funktion zum Laden der Dummy-Daten aus einer Datei
  Future<Map<String, dynamic>> loadDummyData() async {

    print("BEGIN LOAD DATA!");
    final raw = await rootBundle.loadString('assets/dummy_data.txt');
    final lines = raw.split('\n');
    Map<String, dynamic> data = {};
    for (var line in lines) {
      final parts = line.split(':');
      if (parts.length >= 2) {
        final key = parts[0].trim().replaceAll('"', '');
        final value = parts.sublist(1).join(':').trim();
        if ((key == 'Datum' || key == 'Startzeit' || key == 'Enddatum' || key == 'Endzeit') && value.isNotEmpty) {
          data[key] = value.split(';').map((e) => e.trim()).toList();
        } else {
          data[key] = value;
        }
      }
    }

    print("SUCCESS!");
    return data;
  }

  Future<void> _pickImageFromGallery() async {  // Add this function
    final pickedFile =
    await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      await _onPictureTaken(XFile(pickedFile.path));
      setState(() {
        _latestGalleryImage = File(pickedFile.path);
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    if (_isCameraInitialized) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CameraPreview(_controller!),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 32.0),
                        child: ElevatedButton(
                          onPressed: _onTakePhotoPressed,
                          style: ElevatedButton.styleFrom(
                            fixedSize: const Size(70, 70),
                            shape: const CircleBorder(),
                            backgroundColor: Colors.white,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.black,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 80,
                color: _getContainerColor(context), // Dynamische Farbe
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Gallery button
                    GestureDetector(
                      onTap: _pickImageFromGallery,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          border: Border.all(color: _getContrastColor(context), width: 2),
                          borderRadius: BorderRadius.circular(8),
                          image: _latestGalleryImage != null
                              ? DecorationImage(
                            image: FileImage(_latestGalleryImage!),
                            fit: BoxFit.cover,
                          )
                              : null,
                        ),
                        child: _latestGalleryImage == null
                            ? Icon(Icons.image,
                            color: _getContrastColor(context), size: 28)
                            : null,
                      ),
                    ),
                    // Toggle-Switch
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isHandwritten ? 'Handschrift' : 'Druckschrift',
                          style: TextStyle(
                            color: _getContrastColor(context),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Switch(
                          value: _isHandwritten,
                          activeColor: Colors.indigo,
                          onChanged: (value) {
                            setState(() {
                              _isHandwritten = value;
                            });
                          },
                        ),
                      ],
                    ),
                    //Setting Button
                    IconButton(
                      icon: Icon(Icons.settings, color: _getContrastColor(context), size: 28),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => SettingsPage(themeNotifier: themeNotifier)),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
  }

  // Funktion zum Bestimmen der Streifenfarbe basierend auf dem aktuellen Theme
  Color _getContainerColor(BuildContext context) {
    final themeMode = Theme.of(context).brightness;

    if (themeMode == Brightness.dark) {
      return Colors.black87; // Dunkles Theme
    } else {
      return Colors.white70; // Helles Theme
    }
  }

  // Funktion zum Bestimmen der Kontrastfarbe auf dem aktuellen Theme
  Color _getContrastColor(BuildContext context) {
    final themeMode = Theme.of(context).brightness;

    if (themeMode == Brightness.dark) {
      return Colors.white70; // Dunkles Theme
    } else {
      return Colors.black87; // Helles Theme
    }
  }

  Future<void> onNewCameraSelected(CameraDescription description) async {
    final previousCameraController = _controller;

    // Instantiating the camera controller
    final CameraController cameraController = CameraController(
      description,
      ResolutionPreset.high,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    // Initialize controller
    try {
      await cameraController.initialize();
    } on CameraException catch (e) {
      debugPrint('Error initializing camera: $e');
    }
    // Dispose the previous controller
    await previousCameraController?.dispose();

    // Replace with the new controller
    if (mounted) {
      setState(() {
        _controller = cameraController;
      });
    }

    // Update UI if controller updated
    cameraController.addListener(() {
      if (mounted) setState(() {});
    });

    // Update the Boolean
    if (mounted) {
      setState(() {
        _isCameraInitialized = _controller!.value.isInitialized;
      });
    }
  }
}

class CropAspectRatioPresetCustom implements CropAspectRatioPresetData {
  @override
  (int, int)? get data => (2, 3);

  @override
  String get name => '2x3 (customized)';
}


