import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:arkit_plugin/arkit_plugin.dart';
import 'package:geolocator/geolocator.dart';
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

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ARKit 위치 기반 3D 모델',
      home: ARKitViewScreen(),
    );
  }
}

double roundToSixDecimals(double value) {
  return double.parse(value.toStringAsFixed(6));
}

class ARKitViewScreen extends StatefulWidget {
  @override
  _ARKitViewScreenState createState() => _ARKitViewScreenState();
}

class _ARKitViewScreenState extends State<ARKitViewScreen> {
  late ARKitController arkitController;
  Position? userLocation;
  Position? _initialLocation;
  ARKitNode? arModelNode;
  StreamSubscription<Position>? positionStream;

  // 칼만 필터 객체 (위도, 경도, 고도)
  late KalmanFilter kalmanLat;
  late KalmanFilter kalmanLon;
  late KalmanFilter kalmanAlt;

  // 타겟 위치 (예시: 체육관 좌표)
  final Position testPosition = Position(
    latitude: roundToSixDecimals(37.339308464986075),
    longitude: roundToSixDecimals(126.73480117161131),
    altitude: roundToSixDecimals(9.787257108651247),
    accuracy: 0,
    heading: 0,
    speed: 0,
    speedAccuracy: 0,
    altitudeAccuracy: 0,
    headingAccuracy: 0,
    timestamp: DateTime.now(),
  );

  @override
  void initState() {
    super.initState();
    _getUserLocation();
    _startLocationUpdates();
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

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
      timeLimit: Duration(seconds: 1),
    );

    setState(() {
      userLocation = position;
      _initialLocation ??= position;
      kalmanLat = KalmanFilter(position.latitude);
      kalmanLon = KalmanFilter(position.longitude);
      kalmanAlt = KalmanFilter(position.altitude);
    });

    print("📍 초기 위치 - 위도: ${position.latitude}, 경도: ${position.longitude}, 고도: ${position.altitude}");
  }

  void _startLocationUpdates() {
    positionStream = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1, // 1m 이상 이동 시 업데이트
      ),
    ).listen((Position newPosition) {
      // 새로운 위치 데이터를 Kalman 필터로 보정
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

      double distanceToTarget = _calculateDistance(
        userLocation!.latitude,
        userLocation!.longitude,
        testPosition.latitude,
        testPosition.longitude,
      );

      //print("📍 보정된 위치 - 현재 거리: $distanceToTarget m");

      if (distanceToTarget > 10000.0) { /// 수정
        if (arModelNode != null) {
          print("🗑 AR 모델 제거: 거리 초과");
          arkitController.remove(arModelNode!.name!);
          arModelNode = null;
        }
      } else {
        _addARModel(userLocation!, testPosition);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ARKit 위치 기반 3D 모델')),
      body: ARKitSceneView(
        onARKitViewCreated: _onARKitViewCreated,
        enableTapRecognizer: true, // 터치 이벤트 활성화
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
          MaterialPageRoute(builder: (context) => TargetPage()),
        );
      } else {
        print("⚠️ 'gift' 노드가 터치되지 않음.");
      }
    };
  }

  void _addARModel(Position currentPosition, Position targetPosition) {
    if (_initialLocation == null) return;

    // 초기 위치를 기준으로 상대 오프셋 계산 (미터 단위)
    double deltaLat = targetPosition.latitude - _initialLocation!.latitude;
    double deltaLon = targetPosition.longitude - _initialLocation!.longitude;
    double deltaAlt = targetPosition.altitude - _initialLocation!.altitude; // 고도 차이

    double metersPerDegreeLat = 111320;
    double metersPerDegreeLon = 111320 * cos(_initialLocation!.latitude * pi / 180);
    double offsetX = deltaLon * metersPerDegreeLon;
    double offsetZ = -deltaLat * metersPerDegreeLat;

    // 🎯 현재 위치와 타겟 위치 사이 거리 계산
    double distance = _calculateDistance(
      currentPosition.latitude,
      currentPosition.longitude,
      targetPosition.latitude,
      targetPosition.longitude,
    );

    // 🎯 거리 기반 크기 조정 로직 (최소 0.5 ~ 최대 2.0 크기로 조정)
    double baseSize = 1.0; // 기본 크기
    double sizeFactor = (10 - distance) / 10; // 거리에 따라 크기 조정
    double adjustedSize = baseSize * sizeFactor;
    adjustedSize = adjustedSize.clamp(0.5, 2.0); // 크기 범위 제한

    final newModel = ARKitNode(
      name: "gift",
      geometry: ARKitPlane(
        width: adjustedSize, // 계산된 크기 적용
        height: adjustedSize,
        materials: [
          ARKitMaterial(
            diffuse: ARKitMaterialProperty.image('assets/gift.png'),
          ),
        ],
      ),
      // x: offsetX, y: 고도 차이(deltaAlt), z: offsetZ
      //position: vm.Vector3(offsetX, deltaAlt, offsetZ),
      position: vm.Vector3(0, 0, -1.0),
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
