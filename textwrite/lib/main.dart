import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

void main() async {
  // 카메라 초기화를 비동기로 실행
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();

  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  MyApp({required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Face Detection',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: FaceDetectionScreen(cameras: cameras),
    );
  }
}

class FaceDetectionScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  FaceDetectionScreen({required this.cameras});

  @override
  _FaceDetectionScreenState createState() => _FaceDetectionScreenState();
}

class _FaceDetectionScreenState extends State<FaceDetectionScreen> {
  late CameraController _cameraController;
  late Future<void> _initializeControllerFuture;
  late FaceDetector _faceDetector;
  bool _isDetecting = false;
  List<Face> _detectedFaces = [];

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _initializeFaceDetector();
  }

  Future<void> _initializeCamera() async {
    final camera = widget.cameras[0];
    print("Sensor Orientation: ${camera.sensorOrientation}"); // 센서 회전 확인 로그

    _cameraController = CameraController(
      widget.cameras[0],
      ResolutionPreset.medium, // 해상도를 High로 설정
      enableAudio: false,
    );
    _initializeControllerFuture = _cameraController.initialize();
    await _initializeControllerFuture;

    _cameraController.startImageStream((CameraImage image) async {
      if (_isDetecting) return;
      _isDetecting = true;

      final faces = await _detectFaces(image);
      setState(() {
        _detectedFaces = faces;
      });

      _isDetecting = false;
    });
  }

  // 얼굴 탐지
  Future<List<Face>> _detectFaces(CameraImage image) async {
    try {
      // RGB 데이터를 Uint8List로 변환
      final WriteBuffer allBytes = WriteBuffer();
      allBytes.putUint8List(image.planes[0].bytes);
      final bytes = allBytes.done().buffer.asUint8List();

      // RGB 데이터를 InputImage로 변환
      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        inputImageData: InputImageData(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          imageRotation: _getImageRotation(widget.cameras[0].sensorOrientation),
          inputImageFormat: InputImageFormat.bgra8888, // RGB 데이터 형식으로 지정
          planeData: [
            InputImagePlaneMetadata(
              bytesPerRow: image.planes[0].bytesPerRow,
              height: image.height,
              width: image.width,
            ),
          ],
        ),
      );

      // 얼굴 탐지
      final faces = await _faceDetector.processImage(inputImage);

      print("Faces detected: ${faces.length}");
      if (faces.isEmpty) {
        print("No faces detected. Please check lighting or image settings.");
      }
      return faces;
    } catch (e) {
      print("Error detecting faces: $e");
      return [];
    }
  }

  // 회전값 변환 메서드
  InputImageRotation _getImageRotation(int sensorOrientation) {
    switch (sensorOrientation) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      case 0:
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  void _initializeFaceDetector() {
    final options = FaceDetectorOptions(
      enableContours: true, // 얼굴 윤곽 활성화
      enableLandmarks: true, // 얼굴 랜드마크 활성화
      performanceMode: FaceDetectorMode.accurate, // 정확도 우선
    );
    _faceDetector = FaceDetector(options: options);
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Face Detection'),
      ),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            // 카메라 해상도와 화면 크기 계산
            final imageSize = Size(
              _cameraController.value.previewSize!.height, // 가로, 세로 바뀔 수 있음
              _cameraController.value.previewSize!.width,
            );
            final screenSize = MediaQuery.of(context).size;

            // print("Camera Image Size: $imageSize");
            // print("Screen Size: $screenSize");

            return Stack(
              children: [
                CameraPreview(_cameraController),
                CustomPaint(
                  painter: FacePainter(
                    _detectedFaces, // 얼굴 데이터
                    imageSize,      // 카메라 해상도
                    screenSize,     // 화면 해상도
                  ),
                  child: Container(),
                ),
              ],
            );
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}

// 얼굴 위에 텍스트를 그리는 페인터
class FacePainter extends CustomPainter {
  final List<Face> faces;
  final Size imageSize;
  final Size screenSize;

  FacePainter(this.faces, this.imageSize, this.screenSize);

  @override
  void paint(Canvas canvas, Size size) {
    // 화면과 이미지 비율 계산
    final double scaleX = screenSize.width / imageSize.width;
    final double scaleY = screenSize.height / imageSize.height;

    // 화면 비율과 이미지 비율의 차이를 보정 (Aspect Ratio 기준)
    final double scale = scaleX < scaleY ? scaleX : scaleY;
    final double dx = (screenSize.width - imageSize.width * scale) / 2;
    final double dy = (screenSize.height - imageSize.height * scale) / 2;

    for (Face face in faces) {
      // 얼굴 위치를 화면 좌표계로 변환
      final rect = Rect.fromLTRB(
        face.boundingBox.left * scale + dx,
        face.boundingBox.top * scale + dy,
        face.boundingBox.right * scale + dx,
        face.boundingBox.bottom * scale + dy,
      );

      // 텍스트 추가
      final textPainter = TextPainter(
        text: TextSpan(
          text: "우리 팀",
          style: TextStyle(
            color: Colors.blue,
            fontSize: 40, // 텍스트 크기
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      // 텍스트를 얼굴 위에 중앙 정렬
      final textOffset = Offset(
        rect.left + (rect.width / 2) - (textPainter.width / 2), // 얼굴 가로 중심
        rect.top - textPainter.height - 200,                    // 얼굴 상단 위에 텍스트 표시
        ///  - 200처럼 고정값을 사용하면 좋지 않아서 될 수 있으면 수식으로 변경하기
      );

      // 디버깅 출력
      print("Face boundingBox: ${face.boundingBox}");
      print("Text Offset: $textOffset");

      // 텍스트를 캔버스에 그리기
      textPainter.paint(canvas, textOffset);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}







