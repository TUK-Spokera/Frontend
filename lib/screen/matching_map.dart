import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:graduate/main.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';


class MatchingMap extends StatefulWidget {
  
  final int matchId;
  
  MatchingMap({required this.matchId});
  @override
  _MatchingMapState createState() => _MatchingMapState();
}

class _MatchingMapState extends State<MatchingMap> {
  late GoogleMapController mapController;
  final String googleApiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? 'DEFAULT_API_KEY';
  LatLng currentLocation = LatLng(37.3402, 126.7336); // 기본 위치 학교
  Set<Marker> _markers = {};
  String? _selectedFacilityName;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();

  }

  Future<void> _getCurrentLocation() async {
    final hasPermission = await _checkLocationPermission();
    if (!hasPermission) return;

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      currentLocation = LatLng(position.latitude, position.longitude);
    });

    if (mapController != null) {
      mapController.animateCamera(
        CameraUpdate.newLatLng(currentLocation),
      );
    }

    _fetchRecommendedFacilities();
  }

  Future<bool> _checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('위치 서비스를 활성화 해주세요.')),
      );
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('위치 권한을 허용해주세요.')),
        );
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('위치 권한을 설정에서 활성화해주세요.')),
      );
      return false;
    }

    return true;
  }

  Future<void> _fetchRecommendedFacilities() async {
   final url = Uri.parse('http://appledolphin.xyz:8080/api/facility/recommend/${widget.matchId}');

   try{
     final response =await http.get(url, headers: {"Content-Type": "application/json"});

     if(response.statusCode == 200){
       final decodedBody = utf8.decode(response.bodyBytes);
       print('서버 응답 데이터 (디코딩 완료): $decodedBody');
       final List<dynamic> data = jsonDecode(decodedBody);

       if(data.isNotEmpty){
         _addMarkers(data);
       } else {
         print("경기장 추천 데이터 없음.");
       }
     } else {
       print("서버 응답 오류: ${response.statusCode}");
     }
   } catch (e) {
     print("네트워크 오류: $e");
   }
  }

  void _addMarkers(List<dynamic> facilities) {
    Set<Marker> newMarkers = {};

    for (var facility in facilities){
      final lat = facility["faciLat"];
      final lng = facility["faciLot"];
      final name = facility["faciNm"];
      final address = facility["faciRoadAddr"];

      if (lat != null && lng != null && name != null){
        newMarkers.add(
          Marker(
            markerId: MarkerId(name),
            position: LatLng(lat, lng),
            infoWindow: InfoWindow(
              title: name,
              snippet: address,
            ),
            icon: BitmapDescriptor.defaultMarker,
            onTap: (){
              setState((){
                _selectedFacilityName = name;
              });
            },
          ),
        );
      }
    }
    setState(() {
      _markers = newMarkers;
    });

  }

  Widget _buildSelectionPanel() {
    if (_selectedFacilityName == null) return SizedBox.shrink();

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 8),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    '🏟️ $_selectedFacilityName',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          _showMatchCompleteDialog(); //매칭 완료 팝업
                        },
                        child: Text("선택"),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedFacilityName = null; //선택 취소
                          });
                        },
                        child: Text("취소"),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  //매칭 완료 팝업
  void _showMatchCompleteDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("매칭 완료!"),
          content: Text("경기장이 성공적으로 선택되었습니다."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);

                Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MyApp(),
                    ),
                );


              },
              child: Text("확인"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('매칭 지도'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: currentLocation, zoom: 15),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            markers: _markers,
            onMapCreated: (controller) {
              mapController = controller;
            },
          ),
          _buildSelectionPanel(),
        ],
      ),
    );
  }
}
