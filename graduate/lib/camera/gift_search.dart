import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:arkit_plugin/arkit_plugin.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:vector_math/vector_math_64.dart' as vm;

// Kalman 필터 클래스
class KalmanFilter {
  double _q = 0.0001; // 프로세스 노이즈 공분산
  double _r = 0.05;   // 측정 노이즈 공분산
  double _x;          // 추정값
  double _p = 1.0;    // 오차 공분산
  double _k = 0.0;    // 칼만 이득

  KalmanFilter(this._x);

  double filter(double measurement) {
    _p = _p + _q;
    _k = _p / (_p + _r);
    _x = _x + _k * (measurement - _x);
    _p = (1 - _k) * _p;
    return _x;
  }
}

double roundToSixDecimals(double value) {
  return double.parse(value.toStringAsFixed(6));
}

Future<Position> fetchTargetPosition() async {
  // 실제 API 엔드포인트로 변경하세요.
  final url = Uri.parse("http://appledolphin.xyz:8080/api/facility?faciNm=곰솔누리숲배드민턴장");
  final response = await http.get(url);
  if (response.statusCode == 200) {
    final jsonData = jsonDecode(response.body);
    return Position(
      latitude: jsonData['latitude'] as double,
      longitude: jsonData['longitude'] as double,
      altitude: (jsonData['altitude'] as int).toDouble(),
      accuracy: 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
      timestamp: DateTime.now(),
    );
  } else {
    throw Exception("Failed to load target position");
  }
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ARKit 위치 기반 3D 모델',
      home: const GiftSearchScreen(),
    );
  }
}

class GiftSearchScreen extends StatefulWidget {
  const GiftSearchScreen({Key? key}) : super(key: key);

  @override
  _GiftSearchScreenState createState() => _GiftSearchScreenState();
}

class _GiftSearchScreenState extends State<GiftSearchScreen> {
  late ARKitController arkitController;
  Position? userLocation;
  Position? _initialLocation;
  ARKitNode? arModelNode;
  StreamSubscription<Position>? positionStream;

  // 칼만 필터 객체 (위도, 경도, 고도)
  late KalmanFilter kalmanLat;
  late KalmanFilter kalmanLon;
  late KalmanFilter kalmanAlt;

  // 타겟 위치를 서버에서 받아올 것이므로 nullable로 선언
  Position? testPosition;

  @override
  void initState() {
    super.initState();
    // 초기 칼만 필터 기본값은 0.0으로 설정
    kalmanLat = KalmanFilter(0.0);
    kalmanLon = KalmanFilter(0.0);
    kalmanAlt = KalmanFilter(0.0);
    _getUserLocation().then((_) {
      if (userLocation != null) {
        _startLocationUpdates();
      }
    });
    // 서버에서 타겟 위치 가져오기
    fetchTargetPosition().then((position) {
      setState(() {
        testPosition = position;
      });
      print("📍 서버로부터 받은 타겟 위치 - 위도: ${position.latitude}, 경도: ${position.longitude}");
    }).catchError((error) {
      print("🚨 타겟 위치를 받아오는데 실패: $error");
    });
  }

  Future<void> _getUserLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print("❌ 위치 서비스가 비활성화되어 있습니다.");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      print("⚠️ 위치 권한이 거부됨. 요청 중...");
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print("❌ 사용자가 위치 권한을 거부하였습니다.");
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      print("🚨 위치 권한이 영구적으로 거부됨.");
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 1),
      );

      setState(() {
        userLocation = position;
        _initialLocation ??= position;
        kalmanLat = KalmanFilter(position.latitude);
        kalmanLon = KalmanFilter(position.longitude);
        kalmanAlt = KalmanFilter(position.altitude);
      });

      print("📍 초기 위치 - 위도: ${position.latitude}, 경도: ${position.longitude}, 고도: ${position.altitude}");
    } catch (e) {
      print("🚨 위치 정보를 가져오는 중 에러 발생: $e");
    }
  }

  void _startLocationUpdates() {
    positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1,
      ),
    ).listen((Position newPosition) {
      double filteredLat = kalmanLat.filter(newPosition.latitude);
      double filteredLon = kalmanLon.filter(newPosition.longitude);
      double filteredAlt = kalmanAlt.filter(newPosition.altitude);

      setState(() {
        userLocation = Position(
          latitude: filteredLat,
          longitude: filteredLon,
          altitude: filteredAlt,
          accuracy: newPosition.accuracy,
          heading: newPosition.heading,
          speed: newPosition.speed,
          speedAccuracy: newPosition.speedAccuracy,
          altitudeAccuracy: newPosition.altitudeAccuracy,
          headingAccuracy: newPosition.headingAccuracy,
          timestamp: newPosition.timestamp,
        );
      });

      // testPosition이 서버에서 받아와져야만 아래 로직 실행
      if (testPosition == null) return;

      double distanceToTarget = _calculateDistance(
        userLocation!.latitude,
        userLocation!.longitude,
        testPosition!.latitude,
        testPosition!.longitude,
      );

      print("📍 보정된 위치 - 현재 거리: $distanceToTarget m");

      if (distanceToTarget > 1000.0) {
        if (arModelNode != null) {
          print("🗑 AR 모델 제거: 거리 초과");
          arkitController.remove(arModelNode!.name!);
          arModelNode = null;
        }
      } else {
        _addARModel(userLocation!, testPosition!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ARKit 위치 기반 3D 모델')),
      body: ARKitSceneView(
        onARKitViewCreated: _onARKitViewCreated,
        enableTapRecognizer: true,
      ),
    );
  }

  void _onARKitViewCreated(ARKitController controller) {
    arkitController = controller;
    print("🎥 ARView 생성됨, AR 세션 초기화 시작");

    arkitController.onNodeTap = (List<String> nodeNames) {
      print("🖱️ 터치된 노드 이름: $nodeNames");
      if (nodeNames.contains("gift")) {
        print("🎯 'gift' 노드 터치 감지!");
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const TargetPage()),
        );
      } else {
        print("⚠️ 'gift' 노드가 터치되지 않음.");
      }
    };
  }

  void _addARModel(Position currentPosition, Position targetPosition) {
    if (_initialLocation == null) return;

    double deltaLat = targetPosition.latitude - _initialLocation!.latitude;
    double deltaLon = targetPosition.longitude - _initialLocation!.longitude;
    /// 고도를 int형으로 변경
    int deltaAlt = targetPosition.altitude.toInt() - _initialLocation!.altitude.toInt();

    double metersPerDegreeLat = 111320;
    double metersPerDegreeLon = 111320 * cos(_initialLocation!.latitude * pi / 180);
    double offsetX = deltaLon * metersPerDegreeLon;
    double offsetZ = -deltaLat * metersPerDegreeLat;

    double distance = _calculateDistance(
      currentPosition.latitude,
      currentPosition.longitude,
      targetPosition.latitude,
      targetPosition.longitude,
    );

    double baseSize = 1.0;
    double sizeFactor = (10 - distance) / 10;
    double adjustedSize = baseSize * sizeFactor;
    adjustedSize = adjustedSize.clamp(0.5, 2.0);

    final newModel = ARKitNode(
      name: "gift",
      geometry: ARKitPlane(
        width: adjustedSize,
        height: adjustedSize,
        materials: [
          ARKitMaterial(
            diffuse: ARKitMaterialProperty.image('assets/gift.png'),
          ),
        ],
      ),
      /// Vector3는 double형을 필요로 하기에 Int로 바꾼 고도를 다시 Double로 변경
      position: vm.Vector3(offsetX, deltaAlt.toDouble(), offsetZ),
    );

    if (arModelNode != null) {
      arkitController.remove(arModelNode!.name!);
    }

    arModelNode = newModel;
    arkitController.add(newModel);

    print("🎁 AR 모델 추가됨! 크기: $adjustedSize | 위치: (x: $offsetX, y: $deltaAlt, z: $offsetZ)");
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371000;
    double dLat = (lat2 - lat1) * pi / 180.0;
    double dLon = (lon2 - lon1) * pi / 180.0;
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180.0) * cos(lat2 * pi / 180.0) *
            sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  @override
  void dispose() {
    positionStream?.cancel();
    arkitController.dispose();
    super.dispose();
  }
}

class TargetPage extends StatelessWidget {
  const TargetPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("타겟 페이지")),
      body: const Center(
        child: Text("여기는 타겟 페이지입니다."),
      ),
    );
  }
}