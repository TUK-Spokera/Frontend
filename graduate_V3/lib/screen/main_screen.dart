import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:graduate/screen/matching_start.dart';
import 'package:graduate/screen/chat_list.dart';
import 'package:graduate/screen/mypage.dart';
import 'package:graduate/camera/team_search.dart';
import 'package:graduate/camera/gift_search.dart';
import 'package:graduate/utils/global.dart';
import 'package:graduate/screen/rank_screen.dart';
import 'package:graduate/screen/victory_and_defeat.dart';


class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 2;

  final List<Widget> _screens = [
    ChatListScreen(username: getGlobalUsername()),
    MyPageScreen(),
    HomeScreenContent(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '홈 화면',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: (_currentIndex < _screens.length)
          ? _screens[_currentIndex]
          : Container(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => TeamSearchScreen()),
            );
          } else if (index == 4) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => GiftSearchScreen()),
            );
          } else {
            setState(() {
              _currentIndex = index;
            });
          }
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: '채팅방',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: '마이페이지',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '홈',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt),
            label: '팀원찾기',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            label: '팀원찾기',
          ),
        ],
      ),
    );
  }
}

class HomeScreenContent extends StatefulWidget {
  @override
  _HomeScreenContentState createState() => _HomeScreenContentState();
}

class _HomeScreenContentState extends State<HomeScreenContent> {
  GoogleMapController? _mapController;
  LatLng? _currentLatLng;
  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
    );

    setState(() {
      _currentLatLng = LatLng(position.latitude, position.longitude);
    });
  }

  Future<List<Match>> fetchTodayMatches() async {
    final response = await http.get(Uri.parse('$API_BASE_URL/matches/today'));

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((json) => Match.fromJson(json)).toList();
    } else {
      throw Exception('경기 정보를 불러오지 못했습니다');
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(height: 16),

          Center(
            child: Container(
              width: size.width * 0.9,
              height: 460,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _currentLatLng == null
                    ? Center(child: CircularProgressIndicator())
                    : GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(
                    target: _currentLatLng!,
                    zoom: 15,
                  ),
                  markers: {
                    Marker(
                      markerId: MarkerId('currentLocation'),
                      position: _currentLatLng!,
                      infoWindow: InfoWindow(title: '현재 내 위치'),
                    ),
                  },
                ),
              ),
            ),
          ),

          SizedBox(height: 16),

          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: size.width * 0.4,
                  height: 45,
                  margin: EdgeInsets.only(right: 8),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => RankingPage()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text('순위'),
                  ),
                ),
                Container(
                  width: size.width * 0.4,
                  height: 45,
                  margin: EdgeInsets.only(left: 8),
                  child: ElevatedButton(
                    onPressed: () async {
                      /*final matches = await fetchTodayMatches(); // 예시
                      final match = matches.first; // 또는 선택된 경기*/

                      showGeneralDialog(
                        context: context,
                        barrierDismissible: true,
                        barrierLabel: "승패입력",
                        barrierColor: Colors.black54,
                        transitionDuration: Duration(milliseconds: 300),
                        pageBuilder: (context, anim1, anim2) {
                          return ResultInputDialog(match: Match(
                            id: 123,
                          ));
                        },
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text('승패 입력'),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 16),

          Center(
            child: Container(
              width: size.width * 0.8 + 16,
              height: 50,
              margin: const EdgeInsets.only(bottom: 32),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => Matchingstart()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text(
                  '매칭시작',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}