import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'dart:async';

// 1) 서버에서 내려주는 JSON 형태에 맞춰 모델 클래스 정의
class TeamLocation {
  final String teamName;
  final double latitude;
  final double longitude;

  TeamLocation({
    required this.teamName,
    required this.latitude,
    required this.longitude,
  });

  factory TeamLocation.fromJson(Map<String, dynamic> json) {
    return TeamLocation(
      teamName: json['teamName'],
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }
}

// 2) 지도를 띄우고 마커를 관리하는 화면
class TeamMapScreen extends StatefulWidget {
  @override
  _TeamMapScreenState createState() => _TeamMapScreenState();
}

class _TeamMapScreenState extends State<TeamMapScreen> {
  static const _apiUrl = 'https://example.com/api/teamLocations';

  LatLng? _initialPosition;
  late GoogleMapController _mapController;
  final Set<Marker> _markers = {};

  StreamSubscription<Position>? _positionSub;

  @override
  void initState() {
    super.initState();
    _determinePosition();
    _fetchTeamLocations();

    _positionSub = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((pos) {
      final updated = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _initialPosition = updated;
        _markers.removeWhere((m) => m.markerId.value == 'me');
        _markers.add(
          Marker(
            markerId: MarkerId('me'),
            position: updated,
            infoWindow: InfoWindow(title: '나'),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueAzure,
            ),
          ),
        );
      });
      _mapController.animateCamera(
        CameraUpdate.newLatLng(updated),
      );
    });
  }

  /// 1) 내 위치 얻기
  Future<void> _determinePosition() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) return;
    }
    if (perm == LocationPermission.deniedForever) {
      // 권한 영구 거부
      return;
    }

    Position pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      _initialPosition = LatLng(pos.latitude, pos.longitude);
      // 내 위치에도 마커 추가 (파란색)
      _markers.add(
        Marker(
          markerId: MarkerId('me'),
          position: _initialPosition!,
          infoWindow: InfoWindow(title: '나'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        ),
      );
    });
  }

  /// 2) 서버에서 팀 위치 받아와서 마커로 추가
  Future<void> _fetchTeamLocations() async {
    try {
      final resp = await http.get(Uri.parse(_apiUrl));
      if (resp.statusCode == 200) {
        final List<dynamic> data = json.decode(resp.body);
        final locations = data
            .map((json) => TeamLocation.fromJson(json))
            .toList();
        _addMarkers(locations);
      } else {
        debugPrint('팀 위치 불러오기 실패: ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('네트워크 오류: $e');
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  void _addMarkers(List<TeamLocation> locs) {
    final newMarkers = locs.map((loc) {
      final hue = loc.teamName.toLowerCase() == 'redteam'
          ? BitmapDescriptor.hueRed
          : BitmapDescriptor.hueBlue;

      return Marker(
        markerId: MarkerId('${loc.teamName}-${loc.latitude}-${loc.longitude}'),
        position: LatLng(loc.latitude, loc.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        infoWindow: InfoWindow(title: loc.teamName),
      );
    }).toSet();

    setState(() {
      // 기존 마커(내 위치) 유지하면서 팀 마커 추가
      _markers.addAll(newMarkers);
    });
  }

  @override
  Widget build(BuildContext context) {
    // 내 위치 정보가 아직 없으면 로딩 표시
    if (_initialPosition == null) {
      return Scaffold(
        appBar: AppBar(title: Text('팀 위치')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('팀 위치')),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: _initialPosition!,
          zoom: 15,
        ),
        markers: _markers,
        onMapCreated: (ctrl) => _mapController = ctrl,
        myLocationEnabled: true,          // 내 위치 버튼
        myLocationButtonEnabled: true,    // 내 위치 버튼 보이기
      ),
    );
  }
}