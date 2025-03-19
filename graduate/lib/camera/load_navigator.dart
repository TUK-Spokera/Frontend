import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:arkit_plugin/arkit_plugin.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vector_math/vector_math_64.dart' as vm;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

// 간단한 LatLng 클래스 (실제 사용 시 google_maps_flutter의 LatLng 사용 가능)
class LatLng {
  final double latitude;
  final double longitude;
  LatLng(this.latitude, this.longitude);
}

Future<List<LatLng>> getRouteCoordinates(String origin, String destination) async {
  // origin과 destination은 "위도,경도" 문자열로 전달 (예: "37.293257,126.876605")
  await dotenv.load(fileName: '.env');
  final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY']; // 여기에 본인의 API 키를 넣으세요.
  final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json?origin=$origin&destination=$destination&key=$apiKey');

  final response = await http.get(url);
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    // 첫번째 경로(route)의 overview_polyline에서 인코딩된 polyline 문자열을 가져옵니다.
    final polyline = data['routes'][0]['overview_polyline']['points'];
    // polyline 문자열을 디코딩하여 좌표 목록을 반환합니다.
    return decodePolyline(polyline);
  } else {
    throw Exception("Failed to load directions");
  }
}

/// 인코딩된 폴리라인 문자열을 디코딩하여 LatLng 목록으로 변환하는 함수
List<LatLng> decodePolyline(String encoded) {
  List<LatLng> poly = [];
  int index = 0;
  int len = encoded.length;
  int lat = 0;
  int lng = 0;

  while (index < len) {
    int b;
    int shift = 0;
    int result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
    lat += dlat;

    shift = 0;
    result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
    lng += dlng;

    double finalLat = lat / 1e5;
    double finalLng = lng / 1e5;
    poly.add(LatLng(finalLat, finalLng));
  }
  return poly;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AR Route',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: ARRouteScreen(),
    );
  }
}

class ARRouteScreen extends StatefulWidget {
  @override
  _ARRouteScreenState createState() => _ARRouteScreenState();
}

class _ARRouteScreenState extends State<ARRouteScreen> {
  ARKitController? arkitController;
  Position? currentPosition;

  // 테스트용: 구글 Directions API로부터 디코딩된 경로 좌표 (예시)
  final List<LatLng> routeCoordinates = [
    LatLng(37.293257, 126.876605),
    LatLng(37.293500, 126.876800),
    LatLng(37.293800, 126.877000),
    LatLng(37.294000, 126.877200),
  ];

  // AR에서의 기준점 (내 위치를 기준으로 AR 월드 좌표로 변환)
  LatLng? referenceCoordinate;

  @override
  void initState() {
    super.initState();
    _fetchCurrentPosition().then((_) {
      if (currentPosition != null) {
        // 내 위치를 기준점으로 설정
        referenceCoordinate = LatLng(
            currentPosition!.latitude, currentPosition!.longitude);
        setState(() {}); // 위치 초기화 완료 후 화면 업데이트
      }
    });
  }

  // 현재 위치 가져오기 (안전한 null 체크 포함)
  Future<void> _fetchCurrentPosition() async {
    try {
      currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation);
      print("📍 현재 위치: ${currentPosition!.latitude}, ${currentPosition!
          .longitude}");
    } catch (e) {
      print("❌ 위치 가져오기 실패: $e");
    }
  }

  // ARKitView 생성 시 호출되는 콜백
  void onARKitViewCreated(ARKitController controller) {
    arkitController = controller;
    // 여기서 planeDetection 설정을 제거합니다.
    if (referenceCoordinate != null) {
      _addRouteLine();
    }
  }

  // LatLng 좌표를 ARKit 월드 좌표로 변환 (간단한 평면 근사법)
  vm.Vector3? _convertLatLngToVector3(LatLng coordinate) {
    if (referenceCoordinate == null) return null;
    double latDiff = coordinate.latitude - referenceCoordinate!.latitude;
    double lngDiff = coordinate.longitude - referenceCoordinate!.longitude;
    // 1도 위도 약 111320m, 경도는 기준 위도의 cos 값을 곱함.
    double latMeters = latDiff * 111320;
    double lngMeters = lngDiff * 111320 *
        cos(referenceCoordinate!.latitude * pi / 180);
    // ARKit에서는 x, z 축을 사용 (y는 높이)
    return vm.Vector3(lngMeters, 0, -latMeters);
  }

  // 경로 좌표들을 잇는 선(여러 선분)을 AR 씬에 추가
  void _addRouteLine() {
    if (arkitController == null || referenceCoordinate == null) return;
    for (int i = 0; i < routeCoordinates.length - 1; i++) {
      vm.Vector3? start = _convertLatLngToVector3(routeCoordinates[i]);
      vm.Vector3? end = _convertLatLngToVector3(routeCoordinates[i + 1]);
      if (start == null || end == null) continue;
      ARKitNode lineNode = _createLineNode(start, end);
      arkitController!.add(lineNode);
    }
  }

  // 두 점 사이의 선분을 생성하는 함수
  ARKitNode _createLineNode(vm.Vector3 start, vm.Vector3 end) {
    // 선의 중간 지점 계산
    vm.Vector3 midPoint = (start + end) * 0.5;
    // 두 점 사이의 거리 계산
    double distance = (end - start).length;
    // 얇은 박스를 이용해 선을 표현 (너비 = 선의 길이, 높이와 깊이는 매우 작게)
    ARKitBox box = ARKitBox(
      width: distance,
      height: 0.005,
      length: 0.005,
      materials: [
        ARKitMaterial(diffuse: ARKitMaterialProperty.color(Colors.blue))
      ],
    );
    // 선의 방향에 맞게 회전 (y축 기준 yaw)
    double yaw = atan2(end.x - start.x, end.z - start.z);
    return ARKitNode(
      geometry: box,
      position: midPoint,
      eulerAngles: vm.Vector3(0, yaw, 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('길 찾기')),
      body: ARKitSceneView(
        onARKitViewCreated: onARKitViewCreated,
        configuration: ARKitConfiguration.worldTracking,
      ),
    );
  }
}
