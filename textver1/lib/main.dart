import 'dart:async';
import 'dart:convert'; // 서버 데이터 처리
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math';

// 얼굴 크기 비례해서 크기 조절

void main() async {
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
      home: FaceDetectionScreen(
        cameras: cameras,
        selectedSport: "배드민턴", //  기본값 설정 (초기 진입 시)
        maxPlayers: 4,       //  기본값 설정 (5:5 경기)
      ),
    );
  }
}

class FaceDetectionScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final String selectedSport;  // 🎯 매개변수 추가
  final int maxPlayers;        // 🎯 매개변수 추가

  FaceDetectionScreen({
    required this.cameras,
    required this.selectedSport,
    required this.maxPlayers,
  });

  @override
  _FaceDetectionScreenState createState() => _FaceDetectionScreenState();
}

class _FaceDetectionScreenState extends State<FaceDetectionScreen> {
  // 📌 위치 권한 요청 함수
  Future<void> _checkAndRequestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('🚨 위치 권한이 거부되었습니다.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print('🚨 위치 권한이 영구적으로 거부되었습니다. 설정에서 수동으로 활성화해야 합니다.');
      return;
    }

    print('✅ 위치 권한이 허용되었습니다.');
  }

  late CameraController _cameraController;
  late Future<void> _initializeControllerFuture;
  late FaceDetector _faceDetector;
  bool _isDetecting = false;
  List<Face> _detectedFaces = [];
  Map<String, dynamic> teamData = {};
  Position? currentPosition;

  @override
  void initState() {
    super.initState();
    _initializeData();  // 🚀 이 함수에서만 초기화 실행!
    _initializeCamera();
    _initializeFaceDetector();
    _checkAndRequestLocationPermission();
  }


  Future<void> _initializeData() async {
    await _fetchCurrentPosition();

    if (currentPosition != null) {  // 📌 currentPosition이 존재할 때만 실행
      print("✅ 위치 가져오기 완료! 현재 위치: ${currentPosition!.latitude}, ${currentPosition!.longitude}");
      await _fetchTeamData();
      print("✅ 팀 데이터 가져오기 완료! 현재 팀 데이터: ${json.encode(teamData)}");
      setState(() {});
    } else {
      print("❌ 위치를 가져오지 못했으므로 팀 데이터를 설정하지 않음.");
    }
  }

  // 📌 카메라 초기화
  Future<void> _initializeCamera() async {
    final camera = widget.cameras[0];
    _cameraController = CameraController(
      camera,
      ResolutionPreset.veryHigh, // 🚀 성능 & 화질 균형 유지
      enableAudio: false,
    );

    _initializeControllerFuture = _cameraController.initialize();
    await _initializeControllerFuture;

    // 카메라 이미지 스트림에서 얼굴 탐지 실행
    _cameraController.startImageStream((CameraImage image) async {
      if (_isDetecting) return;
      _isDetecting = true;

      final faces = await _detectFaces(image);
      setState(() {
        _detectedFaces = faces; /// 얼굴 데이터 업데이트
      });

      _isDetecting = false;
    });
  }

  // 📌 얼굴 탐지
  Future<List<Face>> _detectFaces(CameraImage image) async {
    try {
      final Uint8List bytes = image.planes.fold<Uint8List>(
        Uint8List(0),
            (previousValue, plane) => Uint8List.fromList([...previousValue, ...plane.bytes]),
      );

      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: _getImageRotation(widget.cameras[0].sensorOrientation),
          format: InputImageFormat.bgra8888,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );

      return await _faceDetector.processImage(inputImage);
    } catch (e) {
      print("Error detecting faces: $e");
      return [];
    }
  }

  // 📌 센서 회전값 변환
  InputImageRotation _getImageRotation(int sensorOrientation) {
    switch (sensorOrientation) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  // 📌 얼굴 탐지 객체 초기화
  void _initializeFaceDetector() {
    final options = FaceDetectorOptions(
      enableContours: true,
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.fast,
      minFaceSize: 0.1,
    );
    _faceDetector = FaceDetector(options: options);
  }

  // 📌 서버에서 팀 데이터 가져오기 (위도/경도 포함)
  /*Future<void> _fetchTeamData() async {
    try {
      final response = await http.get(Uri.parse('https://example.com/teams'));
      if (response.statusCode == 200) {
        setState(() {
          teamData = json.decode(response.body);
        });
      }
    } catch (e) {
      print("Error fetching team data: $e");
    }
  }

  // 📌 현재 위치 가져오기
  Future<void> _fetchCurrentPosition() async {
    try {
      currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,  // 📌 위치 정확도 향상
          timeLimit: Duration(seconds: 10)
      );
      print("📍 현재 위치 (정확도 개선): ${currentPosition!.latitude}, ${currentPosition!.longitude}");
    } catch (e) {
      print("Error fetching current position: $e");
    }
  }*/

  Future<void> _fetchCurrentPosition() async {
    try {
      currentPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.bestForNavigation);

      // ✅ 위치 정보 출력 (고도 및 정확도 포함)
      print("📍 현재 위치: 위도 ${currentPosition!.latitude}, 경도 ${currentPosition!.longitude}");
      print("📍 현재 고도: ${currentPosition!.altitude}m");
      print("📍 위치 정확도: ±${currentPosition!.accuracy}m");

    } catch (e) {
      print("❌ Error fetching current position: $e");
    }
  }

  Future<void> _fetchTeamData() async {
    try {
      setState(() {
        print("✅ 업데이트된 teamData: ${json.encode(teamData)}");
        if (teamData.isEmpty) {
          teamData = {
            "redTeam": [],
            "blueTeam": []
          };
        }

        // 📌 현재 위치를 "우리 팀"에 추가
        if (currentPosition != null) {
          // redTeam, blueTeam에 맞춰서 바뀜
          teamData['redTeam'].add({
            'latitude': currentPosition!.latitude,
            'longitude': currentPosition!.longitude,
            'altitude': currentPosition!.altitude,
            'id': '남궁용진'
          });

          /*teamData['blueTeam'].add({
            'latitude': 37.33949282572428,
            'longitude': 126.73452815642581,
            'altitude': 10.905750751495361,
            'id': '테스트유저'
          });*/

          // print("✅ 업데이트된 teamData: ${json.encode(teamData)}");
          print("📍 현재 위치: 위도 ${currentPosition!.latitude}, 경도 ${currentPosition!.longitude}");
          print("🔍 테스트유저 위도 타입: ${teamData['blueTeam'][0]['latitude'].runtimeType}");
          print("🔍 테스트유저 경도 타입: ${teamData['blueTeam'][0]['longitude'].runtimeType}");

        } else {
          print("⚠️ 현재 위치를 찾을 수 없습니다.");
        }
      });

      // 🔍 데이터 업데이트 후 확인
    } catch (e) {
      print("❌ Error fetching team data: $e");
    }
  }

  // 📌 인원수에 맞춰 얼굴을 팀과 매핑
  List<Map<String, dynamic>> mapFacesToTeams(List<Face> faces) {
    if (currentPosition == null || teamData.isEmpty) {
      print("🚨 현재 위치 또는 팀 데이터가 비어 있음! (currentPosition: $currentPosition, teamData: $teamData)");
      return [];
    }

    List<Map<String, dynamic >> mappedFaces = [];
    double tolerance = 0.00015; // 📌 허용 오차 (약 20m)
    Set<String> assignedPlayers = {}; // ✅ 이미 매칭된 플레이어 저장

    for (var face in faces) {
      String assignedTeam = "unknown";
      String playerId = "unknown";
      double minDistance = double.infinity;
      String? closestPlayerId;

      // 🎯 얼굴마다 가장 가까운 사용자를 찾되, 중복 배정 방지
      for (var team in ['redTeam', 'blueTeam']) {
        for (var member in teamData[team]) {
          print("🧐 팀 데이터 확인 중... ID: ${member['id']}, 위도: ${member['latitude']}, 경도: ${member['longitude']}");

          double distance = calculateDistance(
              currentPosition!.latitude, currentPosition!.longitude, currentPosition!.altitude,
              member['latitude'], member['longitude'], member['altitude']
          );

          print("📍 현재 위치: 위도 ${currentPosition!.latitude}, 경도 ${currentPosition!.longitude}, 고도 ${currentPosition!.altitude}");
          print("🎯 비교 대상: 위도 ${member['latitude']}, 경도 ${member['longitude']}, 고도 ${member['altitude']}");
          print("📏 계산된 거리: ${distance.toStringAsFixed(2)}m");

          if (distance <= tolerance && distance < minDistance) {
            assignedTeam = team;
            closestPlayerId = member['id'];
            minDistance = distance;
          }
        }
      }

      // 🎯 가장 가까운 사용자 할당
      if (closestPlayerId != null) {
        playerId = closestPlayerId;
        assignedPlayers.add(playerId); // ✅ 중복 방지
      }

      mappedFaces.add({
        "face": face,
        "team": assignedTeam,
        "id": playerId,
        "distance": minDistance
      });

      print("🎯 얼굴 감지됨 - ID: $playerId, 팀: $assignedTeam, 거리: ${minDistance.toStringAsFixed(2)}m");
    }

    return mappedFaces;
  }

  double calculateDistance(double lat1, double lon1, double alt1, double lat2, double lon2, double alt2) {
    const double R = 6371000; // 지구 반지름 (미터 단위)
    double dLat = (lat2 - lat1) * pi / 180;
    double dLon = (lon2 - lon1) * pi / 180;

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
            sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    double horizontalDistance = R * c; // 평면 거리 (미터 단위)
    double verticalDistance = alt2 - alt1; // 층수 차이 (미터 단위)


    return sqrt(pow(horizontalDistance, 2) + pow(verticalDistance, 2)); // 피타고라스 정리
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
        title: Text('Face Detection - ${widget.selectedSport}'),
      ),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            final imageSize = Size(_cameraController.value.previewSize!.height, _cameraController.value.previewSize!.width);
            final screenSize = MediaQuery.of(context).size;

            final facesWithTeams = mapFacesToTeams(_detectedFaces);

            return Stack(
              children: [
                CameraPreview(_cameraController),
                CustomPaint(painter: FacePainter(facesWithTeams, imageSize, screenSize)),
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

class FacePainter extends CustomPainter {
  final List<Map<String, dynamic>> facesWithTeams;
  final Size imageSize;
  final Size screenSize;

  FacePainter(this.facesWithTeams, this.imageSize, this.screenSize);

  @override
  void paint(Canvas canvas, Size size) {
    for (var data in facesWithTeams) {
      Face face = data["face"];
      String playerId = data["id"];
      String team = data["team"];
      double distance = data.containsKey("distance") ? data["distance"] : 10.0; // 📌 거리 정보 (미터 단위)

      if (playerId == "unknown") {
        continue;
      }

      // 📌 거리 기반 크기 조정 (20m 이하일 때 글자 크기 24, 50m 이상일 때 글자 크기 10)
      double minFontSize = 5;
      double maxFontSize = 12;
      double fontSize = maxFontSize - ((distance / 50) * (maxFontSize - minFontSize));
      fontSize = fontSize.clamp(minFontSize, maxFontSize);  // 최소/최대 제한

      // 📌 팀에 따라 텍스트 색상 설정
      Color textColor = (team == "blueTeam") ? Colors.blue : Colors.red;

      double calculateFontSize(Face face, double screenHeight) {
        double faceHeight = face.boundingBox.height;
        double baseFontSize = 5;  // 최소 글자 크기
        double maxFontSize = 20;  // 최대 글자 크기

        // 얼굴 크기에 따라 글자 크기 조정 (기본적으로 얼굴이 클수록 글씨도 큼)
        double fontSize = baseFontSize + (faceHeight / screenHeight) * maxFontSize;
        return fontSize.clamp(baseFontSize, maxFontSize);
      }

      final textPainter = TextPainter(
        text: TextSpan(
          text: "$playerId",
          style: TextStyle(color: textColor, fontSize: calculateFontSize(face, screenSize.height), fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();

      double scaleX = screenSize.width / imageSize.width;
      double scaleY = screenSize.height / imageSize.height;

      double left = face.boundingBox.left * scaleX;
      double top = face.boundingBox.top * scaleY;

      print("🔥 [ID: $playerId] ($team) 거리: ${distance.toStringAsFixed(2)}m, 글자 크기: $fontSize");

      textPainter.paint(canvas, Offset(left, top - 40)); // 얼굴 위에 ID 표시
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

