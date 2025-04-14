import 'dart:async';
import 'dart:convert'; // 서버 데이터 처리
import 'dart:math';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// TeamSearchScreen: 카메라 목록을 내부에서 초기화한 후 FaceDetectionScreen으로 이동
class TeamSearchScreen extends StatefulWidget {
  const TeamSearchScreen({Key? key}) : super(key: key);

  @override
  _TeamSearchScreenState createState() => _TeamSearchScreenState();
}

class _TeamSearchScreenState extends State<TeamSearchScreen> {
  late Future<List<CameraDescription>> _camerasFuture;

  @override
  void initState() {
    super.initState();
    // availableCameras()를 호출하여 카메라 목록을 비동기로 가져옴
    _camerasFuture = availableCameras();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CameraDescription>>(
      future: _camerasFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // 카메라 정보를 불러오는 동안 로딩 인디케이터 표시
          return Scaffold(
            appBar: AppBar(title: const Text('팀원찾기')),
            body: const Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          // 에러 발생 시 에러 메시지 표시
          return Scaffold(
            appBar: AppBar(title: const Text('팀원찾기')),
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        } else {
          // 카메라 목록이 준비되면 FaceDetectionScreen으로 이동
          final cameras = snapshot.data!;
          return FaceDetectionScreen(cameras: cameras);
        }
      },
    );
  }
}

/// FaceDetectionScreen: 카메라 미리보기 및 얼굴 인식 기능 구현
class FaceDetectionScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  // 외부에서 전달받은 카메라 목록을 사용
  FaceDetectionScreen({required this.cameras});

  @override
  _FaceDetectionScreenState createState() => _FaceDetectionScreenState();
}

class _FaceDetectionScreenState extends State<FaceDetectionScreen> {
  // 카메라 컨트롤러와 초기화 Future
  late CameraController _cameraController;
  late Future<void> _initializeControllerFuture;

  // ML Kit 얼굴 탐지기
  late FaceDetector _faceDetector;

  // 얼굴 탐지 중복 방지를 위한 플래그
  bool _isDetecting = false;
  // 감지된 얼굴 목록
  List<Face> _detectedFaces = [];
  // 서버에서 받아온 팀 데이터
  Map<String, dynamic> teamData = {};
  // 현재 위치 정보
  Position? currentPosition;

  @override
  void initState() {
    super.initState();
    // 위치 및 팀 데이터 초기화
    _initializeData();
    // 카메라 초기화 및 이미지 스트림 시작
    _initializeCamera();
    // 얼굴 탐지기 초기화
    _initializeFaceDetector();
    // 위치 권한 요청
    _checkAndRequestLocationPermission();
  }

  /// 위치 권한 요청 함수
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

  /// 현재 위치와 팀 데이터를 초기화
  Future<void> _initializeData() async {
    await _fetchCurrentPosition();
    if (currentPosition != null) {
      await _fetchTeamData();
      setState(() {});
    }
  }

  /// 카메라 초기화 및 이미지 스트림 시작
  Future<void> _initializeCamera() async {
    // 첫 번째 카메라 선택
    final camera = widget.cameras[0];
    _cameraController = CameraController(
      camera,
      ResolutionPreset.veryHigh,
      enableAudio: false,
    );
    _initializeControllerFuture = _cameraController.initialize();
    await _initializeControllerFuture;

    // 이미지 스트림을 통해 얼굴 탐지 실행
    int frameCounter = 0; // 클래스 멤버 변수로 추가

    _cameraController.startImageStream((CameraImage image) async {
      frameCounter++;
      // 3프레임마다 한 번만 처리 (원하는 프레임 주기로 조절 가능)
      if (frameCounter % 3 != 0) return;

      if (_isDetecting) return;
      _isDetecting = true;
      final faces = await _detectFaces(image);
      setState(() {
        _detectedFaces = faces;
      });
      _isDetecting = false;
    });
  }

  /// 얼굴 탐지 함수
  Future<List<Face>> _detectFaces(CameraImage image) async {
    try {
      // 이미지의 모든 플레인(planes)을 합쳐 바이트 배열 생성
      final Uint8List bytes = image.planes.fold<Uint8List>(
        Uint8List(0),
            (previousValue, plane) =>
            Uint8List.fromList([...previousValue, ...plane.bytes]),
      );
      // ML Kit에 전달할 InputImage 생성
      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: _getImageRotation(widget.cameras[0].sensorOrientation),
          format: InputImageFormat.bgra8888,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
      // 얼굴 탐지 후 결과 반환
      return await _faceDetector.processImage(inputImage);
    } catch (e) {
      print("Error detecting faces: $e");
      return [];
    }
  }

  /// 센서 회전값을 InputImageRotation으로 변환
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

  /// 얼굴 탐지기를 옵션과 함께 초기화
  void _initializeFaceDetector() {
    final options = FaceDetectorOptions(
      enableContours: true,
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.fast,
      minFaceSize: 0.1,
    );
    _faceDetector = FaceDetector(options: options);
  }

  /// 현재 위치 정보 가져오기
  Future<void> _fetchCurrentPosition() async {
    try {
      currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation);
      print(
          "📍 현재 위치: 위도 ${currentPosition!.latitude}, 경도 ${currentPosition!.longitude}");
    } catch (e) {
      print("❌ Error fetching current position: $e");
    }
  }

  /// 서버에서 팀 데이터 가져오기
  Future<void> _fetchTeamData() async {
    try {
      final response =
      await http.get(Uri.parse('https://example.com/api/getTeamData'));
      if (response.statusCode == 200) {
        final serverData = json.decode(response.body);
        setState(() {
          if (serverData['redTeam'] != null && serverData['blueTeam'] != null) {
            teamData = {
              "redTeam": List<Map<String, dynamic>>.from(serverData['redTeam']),
              "blueTeam":
              List<Map<String, dynamic>>.from(serverData['blueTeam']),
            };
            print("✅ 서버에서 받아온 팀 데이터: ${json.encode(teamData)}");
          } else {
            print("❌ 서버 응답에 팀 데이터가 없습니다.");
          }
        });
      } else {
        print("❌ 서버 요청 실패 - 상태 코드: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ 팀 데이터를 가져오는 중 오류 발생: $e");
    }
  }

  /// 얼굴과 팀 데이터를 매핑 (위치 기반)
  List<Map<String, dynamic>> mapFacesToTeams(List<Face> faces) {
    if (currentPosition == null || teamData.isEmpty) {
      print("🚨 현재 위치 또는 팀 데이터가 비어 있음!");
      return [];
    }
    List<Map<String, dynamic>> mappedFaces = [];
    double tolerance = 0.00015; // 허용 오차 (약 20m)
    Set<String> assignedPlayers = {};
    for (var face in faces) {
      String assignedTeam = "unknown";
      String playerId = "unknown";
      double minDistance = double.infinity;
      String? closestPlayerId;

      // redTeam과 blueTeam에서 가장 가까운 멤버 찾기
      for (var team in ['redTeam', 'blueTeam']) {
        for (var member in teamData[team]) {
          double distance = calculateDistance(
            currentPosition!.latitude,
            currentPosition!.longitude,
            currentPosition!.altitude,
            member['latitude'],
            member['longitude'],
            member['altitude'],
          );
          if (distance <= tolerance && distance < minDistance) {
            assignedTeam = team;
            closestPlayerId = member['id'];
            minDistance = distance;
          }
        }
      }
      if (closestPlayerId != null) {
        playerId = closestPlayerId;
        assignedPlayers.add(playerId);
      }
      mappedFaces.add({
        "face": face,
        "team": assignedTeam,
        "id": playerId,
        "distance": minDistance,
      });
    }
    return mappedFaces;
  }

  /// 두 위치 간 3차원 거리 계산 (위도, 경도, 고도)
  double calculateDistance(
      double lat1, double lon1, double alt1,
      double lat2, double lon2, double alt2) {
    const double R = 6371000; // 지구 반지름 (미터)
    double dLat = (lat2 - lat1) * pi / 180;
    double dLon = (lon2 - lon1) * pi / 180;
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    double horizontalDistance = R * c;
    double verticalDistance = alt2 - alt1;
    // 피타고라스 정리로 3D 거리 계산
    return sqrt(pow(horizontalDistance, 2) + pow(verticalDistance, 2));
  }

  @override
  void dispose() {
    // 위젯 해제 시 카메라 컨트롤러와 얼굴 탐지기 정리
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
      // 카메라 초기화 완료 전까지 로딩 인디케이터 표시
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            // 미리보기 크기와 화면 크기 계산
            final imageSize = Size(
              _cameraController.value.previewSize!.height,
              _cameraController.value.previewSize!.width,
            );
            final screenSize = MediaQuery.of(context).size;
            // 감지된 얼굴과 팀 데이터를 매핑
            final facesWithTeams = mapFacesToTeams(_detectedFaces);
            return Stack(
              children: [
                // 카메라 미리보기
                CameraPreview(_cameraController),
                // 얼굴 탐지 결과를 오버레이하여 표시
                CustomPaint(
                  painter: FacePainter(facesWithTeams, imageSize, screenSize),
                ),
              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}

/// FacePainter: 카메라 미리보기 위에 얼굴 정보 및 ID 표시
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
      // 기본 거리값 (없으면 10m로 설정)
      double distance = data.containsKey("distance") ? data["distance"] : 10.0;

      // 플레이어 ID가 없는 경우 건너뛰기
      if (playerId == "unknown") continue;

      // 거리 기반 글자 크기 계산 (예시: 가까울수록 크게)
      double minFontSize = 5;
      double maxFontSize = 12;
      double fontSize = maxFontSize - ((distance / 50) * (maxFontSize - minFontSize));
      fontSize = fontSize.clamp(minFontSize, maxFontSize);

      // 팀에 따라 텍스트 색상 설정 (blueTeam은 파랑, 그 외는 빨강)
      Color textColor = (team == "blueTeam") ? Colors.blue : Colors.red;

      // 얼굴 크기에 따라 동적으로 글자 크기를 조절하는 헬퍼 함수
      double calculateFontSize(Face face, double screenHeight) {
        double faceHeight = face.boundingBox.height;
        double baseFontSize = 5;
        double maxFontSize = 20;
        double fontSize = baseFontSize + (faceHeight / screenHeight) * maxFontSize;
        return fontSize.clamp(baseFontSize, maxFontSize);
      }

      final textPainter = TextPainter(
        text: TextSpan(
          text: "$playerId",
          style: TextStyle(
            color: textColor,
            fontSize: calculateFontSize(face, screenSize.height),
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      // 스케일 조정: 미리보기 이미지 크기와 실제 화면 크기 비율 계산
      double scaleX = screenSize.width / imageSize.width;
      double scaleY = screenSize.height / imageSize.height;
      double left = face.boundingBox.left * scaleX;
      double top = face.boundingBox.top * scaleY;

      // 얼굴 위에 플레이어 ID를 표시 (상단 40 픽셀 오프셋)
      textPainter.paint(canvas, Offset(left, top - 40));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
