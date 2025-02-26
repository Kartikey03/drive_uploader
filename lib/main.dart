// Add these dependencies to your pubspec.yaml:
// google_sign_in: ^6.1.0
// googleapis: ^10.1.0
// http: ^1.0.0
// extension_google_sign_in_as_googleapis_auth: ^2.0.9
// image_picker: ^1.0.0

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Google Drive Upload Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const GoogleDriveUploadScreen(),
    );
  }
}

class DriveService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'https://www.googleapis.com/auth/drive.file',
      'https://www.googleapis.com/auth/drive.appdata',
    ],
  );

  // Sign in to Google
  Future<bool> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      return account != null;
    } catch (error) {
      print('Error signing in: $error');
      return false;
    }
  }

  // Upload a file to Google Drive
  Future<String?> uploadFileToGoogleDrive(XFile file) async {
    try {
      // Check if user is signed in
      if (_googleSignIn.currentUser == null) {
        final signedIn = await signIn();
        if (!signedIn) {
          throw Exception('User not signed in');
        }
      }

      // Create a Google Auth Client
      final httpClient = await _googleSignIn.authenticatedClient();
      if (httpClient == null) {
        throw Exception('Failed to authenticate');
      }

      // Initialize the Drive API
      final driveApi = drive.DriveApi(httpClient);

      // Get file metadata
      final fileBytes = await File(file.path).readAsBytes();
      final fileExtension = file.path.split('.').last;
      final mimeType = 'image/$fileExtension';
      final fileName = file.name ?? 'image_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

      // Create a Drive file
      final driveFile = drive.File()
        ..name = fileName
        ..mimeType = mimeType;

      // Upload the file
      final media = drive.Media(
          Stream.value(fileBytes),
          fileBytes.length,
          contentType: mimeType
      );

      final result = await driveApi.files.create(
        driveFile,
        uploadMedia: media,
        $fields: 'id,name,webViewLink',
      );

      print('Uploaded file to Google Drive. ID: ${result.id}');
      print('File name: ${result.name}');
      print('Web View Link: ${result.webViewLink}');

      return result.webViewLink;
    } catch (e) {
      print('Error uploading file: $e');
      return null;
    }
  }

  // Sign out from Google
  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }
}

class GoogleDriveUploadScreen extends StatefulWidget {
  const GoogleDriveUploadScreen({Key? key}) : super(key: key);

  @override
  _GoogleDriveUploadScreenState createState() => _GoogleDriveUploadScreenState();
}

class _GoogleDriveUploadScreenState extends State<GoogleDriveUploadScreen> {
  final DriveService _driveService = DriveService();
  XFile? _imageFile;
  String? _uploadStatus;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _imageFile = pickedFile;
        });

        // Upload the image once picked
        _handleImageUpload(pickedFile);
      }
    } catch (e) {
      setState(() {
        _uploadStatus = 'Error picking image: $e';
      });
    }
  }

  void _handleImageUpload(XFile file) async {
    setState(() {
      _isUploading = true;
      _uploadStatus = 'Uploading...';
    });

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Uploading to Google Drive...'),
            ],
          ),
        );
      },
    );

    try {
      // Sign in and upload
      await _driveService.signIn();
      final link = await _driveService.uploadFileToGoogleDrive(file);

      // Close loading dialog
      Navigator.of(context).pop();

      setState(() {
        _isUploading = false;
        _uploadStatus = link != null
            ? 'Upload successful!\nLink: $link'
            : 'Upload failed.';
      });

      // Show result dialog
      showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: Text(link != null ? 'Success' : 'Failed'),
            content: Text(link != null
                ? 'File uploaded to Google Drive\nLink: $link'
                : 'Failed to upload file to Google Drive'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();

      setState(() {
        _isUploading = false;
        _uploadStatus = 'Error: $e';
      });

      // Show error dialog
      showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to upload: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Drive Upload'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Display the selected image
            if (_imageFile != null)
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                ),
                child: Image.file(
                  File(_imageFile!.path),
                  fit: BoxFit.cover,
                ),
              ),

            const SizedBox(height: 20),

            // Upload status
            if (_uploadStatus != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(_uploadStatus!),
              ),

            const SizedBox(height: 20),

            // Image picker buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _isUploading
                      ? null
                      : () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                ),
                const SizedBox(width: 20),
                ElevatedButton.icon(
                  onPressed: _isUploading
                      ? null
                      : () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Sign out button
            ElevatedButton(
              onPressed: () async {
                await _driveService.signOut();
                setState(() {
                  _uploadStatus = 'Signed out successfully';
                });
              },
              child: const Text('Sign Out'),
            ),
          ],
        ),
      ),
    );
  }
}