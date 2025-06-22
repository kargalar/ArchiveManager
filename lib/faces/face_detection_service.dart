import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../models/photo.dart';
import '../faces/face.dart' as app_face;

class FaceDetectionService {
  static final FaceDetectionService _instance = FaceDetectionService._internal();
  factory FaceDetectionService() => _instance;
  FaceDetectionService._internal();

  late FaceDetector _faceDetector;
  bool _isInitialized = false; // Initialize the face detector
  Future<void> initialize() async {
    // ML Kit Face Detection only works on mobile platforms
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        final options = FaceDetectorOptions(
          enableContours: false,
          enableLandmarks: false,
          enableClassification: false,
          enableTracking: true, // Enable tracking to get trackingIds
          minFaceSize: 0.1,
          performanceMode: FaceDetectorMode.accurate,
        );

        _faceDetector = FaceDetector(options: options);
        _isInitialized = true;
        debugPrint('FaceDetectionService initialized with ML Kit');
      } catch (e) {
        debugPrint('Failed to initialize FaceDetectionService: $e');
        _isInitialized = false;
        rethrow;
      }
    } else {
      // For desktop platforms, use mock implementation
      _isInitialized = true;
      debugPrint('FaceDetectionService initialized with mock implementation for desktop');
    }
  }

  // Dispose the face detector
  void dispose() {
    if (_isInitialized && !kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      _faceDetector.close();
    }
    _isInitialized = false;
    debugPrint('FaceDetectionService disposed');
  }

  // ML Kit ile gerçek yüz tespiti (mobile) veya mock implementation (desktop)
  Future<List<app_face.Face>> detectFacesInPhoto(Photo photo) async {
    if (!_isInitialized) {
      debugPrint('FaceDetectionService not initialized');
      return [];
    }

    try {
      // Check if file exists
      final File imageFile = File(photo.path);
      if (!await imageFile.exists()) {
        debugPrint('Image file does not exist: ${photo.path}');
        return [];
      }

      // For mobile platforms, use ML Kit
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        return _detectFacesWithMLKit(photo, imageFile);
      } else {
        // For desktop platforms, use mock implementation
        return _detectFacesWithMock(photo, imageFile);
      }
    } catch (e) {
      debugPrint('Error during face detection for ${photo.path}: $e');
      return [];
    }
  }

  // ML Kit implementation for mobile
  Future<List<app_face.Face>> _detectFacesWithMLKit(Photo photo, File imageFile) async {
    // Create InputImage from file
    final InputImage inputImage = InputImage.fromFilePath(photo.path);

    // Detect faces
    final List<Face> faces = await _faceDetector.processImage(inputImage);

    // Clear existing tracking IDs and add new ones
    photo.clearFaceTrackingIds();

    // Convert ML Kit faces to app faces
    List<app_face.Face> detectedFaces = [];

    for (Face face in faces) {
      // Add tracking ID to photo if available
      if (face.trackingId != null) {
        photo.addFaceTrackingId(face.trackingId!);
      }

      // Create app Face object
      final app_face.Face appFace = app_face.Face(
        id: face.trackingId?.toString() ?? 'unknown_${DateTime.now().millisecondsSinceEpoch}',
        boundingBox: face.boundingBox,
        smileProbability: face.smilingProbability,
        leftEyeOpenProbability: face.leftEyeOpenProbability,
        rightEyeOpenProbability: face.rightEyeOpenProbability,
        label: null, // Will be set by user if needed
      );

      detectedFaces.add(appFace);
    }

    debugPrint('ML Kit detected ${detectedFaces.length} faces in ${photo.path}');
    return detectedFaces;
  }

  // Mock implementation for desktop
  Future<List<app_face.Face>> _detectFacesWithMock(Photo photo, File imageFile) async {
    // Simulate processing time
    await Future.delayed(const Duration(milliseconds: 200));

    final random = Random();

    // Clear existing tracking IDs
    photo.clearFaceTrackingIds();

    // More realistic face detection - not every photo has faces
    final double hasFaceProbability = 0.7; // 70% chance of having faces
    if (random.nextDouble() > hasFaceProbability) {
      return []; // No faces detected
    }

    // If photo has faces, usually 1-3 faces
    final int faceCount = 1 + random.nextInt(3); // 1-3 faces

    List<app_face.Face> detectedFaces = [];

    for (int i = 0; i < faceCount; i++) {
      // Generate mock tracking ID
      final int trackingId = random.nextInt(10000);
      photo.addFaceTrackingId(trackingId);

      // Generate realistic bounding box (faces are usually in upper portion of image)
      final double x = random.nextDouble() * (photo.width * 0.6); // Left 60% of image
      final double y = random.nextDouble() * (photo.height * 0.6); // Upper 60% of image
      final double faceSize = 50 + random.nextDouble() * 100; // 50-150 pixels

      final app_face.Face face = app_face.Face(
        id: trackingId.toString(),
        boundingBox: Rect.fromLTWH(x, y, faceSize, faceSize),
        smileProbability: random.nextDouble(),
        leftEyeOpenProbability: 0.8 + random.nextDouble() * 0.2, // Usually open
        rightEyeOpenProbability: 0.8 + random.nextDouble() * 0.2, // Usually open
        label: null,
      );

      detectedFaces.add(face);
    }

    debugPrint('Mock detected ${detectedFaces.length} faces in ${photo.path}');
    return detectedFaces;
  }

  Future<void> processPhotoForFaceDetection(Photo photo) async {
    if (photo.faceDetectionDone) {
      return; // Already processed
    }

    if (!_isInitialized) {
      debugPrint('FaceDetectionService not initialized, cannot process photo: ${photo.path}');
      return;
    }

    try {
      final faces = await detectFacesInPhoto(photo);

      // Clear existing faces and add detected faces
      photo.faces.clear();
      for (var face in faces) {
        photo.addFace(face);
      }

      // Mark face detection as completed
      photo.faceDetectionDone = true;
      await photo.save();

      debugPrint('ML Kit face detection completed for ${photo.path}: ${faces.length} faces detected, tracking IDs: ${photo.faceTrackingIds}');
    } catch (e) {
      debugPrint('Error during ML Kit face detection for ${photo.path}: $e');
    }
  }
}
