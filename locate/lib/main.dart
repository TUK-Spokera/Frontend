import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:arkit_plugin/arkit_plugin.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

// Kalman 필터 클래스
class KalmanFilter {
  double _q = 0.0001; // 프로세스 노이즈 공분산
  double _r = 0.02;   // 측정 노이즈 공분산
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
    latitude: roundToSixDecimals(37.293252548454724),
    longitude: roundToSixDecimals(126.87660308047214),
    altitude: roundToSixDecimals(25.454755380539268),
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
      timeLimit: Duration(seconds: 3),
    );

    setState(() {
      userLocation = position;
      _initialLocation ??= position;
      // Kalman 필터 초기화 (초기 측정값으로)
      kalmanLat = KalmanFilter(position.latitude);
      kalmanLon = KalmanFilter(position.longitude);
      kalmanAlt = KalmanFilter(position.altitude);
    });

    print("📍 초기 위치 - 위도: ${position.latitude}, 경도: ${position.longitude}, 고도: ${position.altitude}");
  }

  void _startLocationUpdates() {
    positionStream = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high, // 높은 정확도로 설정
        distanceFilter: 0, // 0으로 설정하면 모든 미세한 이동도 감지
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

      print("📍 보정된 위치 - 현재 거리: $distanceToTarget m");

      if (distanceToTarget > 10.0) {
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
      ),
    );
  }

  void _onARKitViewCreated(ARKitController controller) {
    arkitController = controller;
    print("🎥 ARView 생성됨, AR 세션 초기화 시작");
    // 추가 ARKit 설정이 필요한 경우 이곳에서 처리합니다.
  }

  void _addARModel(Position currentPosition, Position targetPosition) {
    if (_initialLocation == null) return;

    double deltaLat = targetPosition.latitude - currentPosition.latitude;
    double deltaLon = targetPosition.longitude - currentPosition.longitude;

    double metersPerDegreeLat = 111320;
    double metersPerDegreeLon = 111320 * cos(currentPosition.latitude * pi / 180);
    double offsetX = deltaLon * metersPerDegreeLon;
    double offsetZ = -deltaLat * metersPerDegreeLat;

    double baseSize = 1.5;
    double sizeFactor = (15 - _calculateDistance(
      currentPosition.latitude,
      currentPosition.longitude,
      targetPosition.latitude,
      targetPosition.longitude,
    )) / 15;
    double adjustedSize = baseSize * sizeFactor;
    adjustedSize = adjustedSize.clamp(0.7, 2.5);

    final newModel = ARKitNode(
      geometry: ARKitPlane(
        width: adjustedSize,
        height: adjustedSize,
        materials: [
          ARKitMaterial(
            diffuse: ARKitMaterialProperty.image('assets/gift.png'),
          ),
        ],
      ),
      position: vm.Vector3(offsetX, 0, offsetZ),
    );

    if (arModelNode != null) {
      arkitController.remove(arModelNode!.name!);
    }

    arModelNode = newModel;
    arkitController.add(newModel);

    print("🎁 AR 모델 추가됨! 크기: $adjustedSize | 위치: (x: $offsetX, z: $offsetZ)");
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
