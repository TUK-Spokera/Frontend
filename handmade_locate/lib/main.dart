import 'package:ar_flutter_plugin/datatypes/hittest_result_types.dart';
import 'package:ar_flutter_plugin/datatypes/node_types.dart';
import 'package:ar_flutter_plugin/models/ar_anchor.dart';
import 'package:ar_flutter_plugin/models/ar_hittest_result.dart';
import 'package:ar_flutter_plugin/models/ar_node.dart';
import 'package:flutter/material.dart';
import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:permission_handler/permission_handler.dart'; // ✅ 카메라 권한 요청 라이브러리 추가

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AR View',
      home: const ARViewPage(),
    );
  }
}

class ARViewPage extends StatefulWidget {
  const ARViewPage({super.key});

  @override
  _ARViewPageState createState() => _ARViewPageState();
}

class _ARViewPageState extends State<ARViewPage> {
  ARSessionManager? arSessionManager;
  ARObjectManager? arObjectManager;
  ARAnchorManager? arAnchorManager;
  final List<ARPlaneAnchor> anchors = [];

  @override
  void initState() {
    super.initState();
    _checkPermissions(); // ✅ 앱 실행 시 카메라 권한 요청
  }

  @override
  void dispose() {
    arSessionManager?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AR View')),
      body: ARView(
        onARViewCreated: (sessionManager, objectManager, anchorManager, locationManager) {
          onARViewCreated(sessionManager, objectManager, anchorManager);
        },
        planeDetectionConfig: PlaneDetectionConfig.horizontal,
      ),
    );
  }

  // ✅ 카메라 권한 요청 추가
  Future<void> _checkPermissions() async {
    var status = await Permission.camera.status;
    if (status.isDenied) {
      await Permission.camera.request();
    }
  }

  void onARViewCreated(
      ARSessionManager sessionManager,
      ARObjectManager objectManager,
      ARAnchorManager anchorManager) {
    arSessionManager = sessionManager;
    arObjectManager = objectManager;
    arAnchorManager = anchorManager;

    // ✅ AR 세션 초기화 (카메라 활성화됨)
    arSessionManager?.onInitialize(
      showFeaturePoints: false,
      showPlanes: true,
      customPlaneTexturePath: "assets/Present.usdz",
      showWorldOrigin: false,
      handleTaps: true,
    );

    arObjectManager?.onInitialize();
    arSessionManager?.onPlaneOrPointTap = onPlaneOrPointTapped;
  }

  Future<void> onPlaneOrPointTapped(List<ARHitTestResult> hitTestResults) async {
    if (hitTestResults.isEmpty) return;

    var singleHitTestResult = hitTestResults.firstWhere(
          (hitTestResult) => hitTestResult.type == ARHitTestResultType.plane,
      orElse: () => hitTestResults.first,
    );

    var newAnchor = ARPlaneAnchor(transformation: singleHitTestResult.worldTransform);
    bool? didAddAnchor = await arAnchorManager?.addAnchor(newAnchor);

    if (didAddAnchor == true) {
      anchors.add(newAnchor);
      print("📍 새로운 앵커 추가됨!");

      var newNode = ARNode(
        type: NodeType.localGLTF2,
        uri: "assets/Present.usdz",
        scale: Vector3(0.2, 0.2, 0.2),
        position: Vector3.zero(),
        rotation: Vector4(0.0, 1.0, 0.0, 0.0),
      );

      bool? didAddNodeToAnchor = await arObjectManager?.addNode(newNode, planeAnchor: newAnchor);

      if (didAddNodeToAnchor == true) {
        print("🎉 3D 모델 추가 성공!");
      } else {
        print("❌ 3D 모델 추가 실패");
      }
    } else {
      print("❌ 앵커 추가 실패");
    }
  }
}
