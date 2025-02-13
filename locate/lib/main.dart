import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:arkit_plugin/arkit_plugin.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

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

  final Position testPosition = Position(
    latitude: roundToSixDecimals(37.293252548454724),
    longitude: roundToSixDecimals(126.87660308047214),
    altitude: roundToSixDecimals(24.708439024165273),
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
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print("❌ 위치 서비스가 비활성화되어 있습니다.");
      return;
    }

    permission = await Geolocator.checkPermission();
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
        timeLimit: Duration(seconds: 10));
    setState(() {
      userLocation = position;
      _initialLocation ??= position;
    });

    print("📍 내 위치 - 위도: ${position.latitude}, 경도: ${position.longitude}, 고도: ${position.altitude}");
  }

  void _startLocationUpdates() {
    positionStream = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1,
      ),
    ).listen((Position newPosition) {
      setState(() {
        userLocation = newPosition;
      });

      double distanceToTarget = _calculateDistance(
          userLocation!.latitude, userLocation!.longitude,
          testPosition.latitude, testPosition.longitude);

      print("📍 실시간 위치 업데이트 - 현재 거리: $distanceToTarget m");

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
  }

  void _addARModel(Position currentPosition, Position targetPosition) {
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

    final newModel = ARKitReferenceNode(
      name: "Present",
      url: 'assets/Present.usdz',
      scale: vm.Vector3.all(adjustedSize),
      position: vm.Vector3(0, 0, -distance / 10),
    );

    if (arModelNode != null) {
      arkitController.remove(arModelNode!.name!);
    }

    arModelNode = newModel;
    arkitController.add(newModel);
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
    super.dispose();
  }
}
