import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// 추가된 패키지
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

// 기존에 사용하던 스크린들
import 'package:graduate/screen/matching_start.dart';
import 'package:graduate/screen/chat_list.dart';
import 'package:graduate/screen/mypage.dart';
import 'package:graduate/camera/team_search.dart'; // 팀원찾기
import 'package:graduate/camera/gift_search.dart';  // 보상찾기

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(MaterialApp(
    home: MyApp(),
    debugShowCheckedModeBanner: false,
  ));
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => HomeScreen(),
        '/chat_list': (context) => ChatList(),
        '/mypage': (context) => MyPage(),
        '/team_search': (context) => TeamSearchScreen(), // const 제거
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// 하단바 순서: [채팅방, 마이페이지, 홈, 팀원찾기, 보상찾기]
class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 2;
  final List<Widget> _screens = [
    ChatList(),
    MyPage(),
    HomeScreenContent(), // 구글 맵 표시될 메인 화면
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
      body: (_currentIndex < _screens.length) ? _screens[_currentIndex] : Container(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 3) {
            // 팀원찾기 탭
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => TeamSearchScreen()),
            );
          } else if (index == 4) {
            // 보상찾기 탭
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
            icon: Icon(Icons.camera_alt_outlined),
            label: '보상찾기',
          ),
        ],
      ),
    );
  }
}

///
/// 지도 + 검색바 + 매칭 시작 버튼 배치
///
class HomeScreenContent extends StatefulWidget {
  @override
  _HomeScreenContentState createState() => _HomeScreenContentState();
}

class _HomeScreenContentState extends State<HomeScreenContent> {
  GoogleMapController? _mapController;
  LatLng? _currentLatLng;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  /// 위치 권한 체크 & 현재 위치 얻기
  Future<void> _initLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print("위치 서비스가 꺼져있습니다.");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print("위치 권한이 거부되었습니다.");
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      print("위치 권한이 영구적으로 거부되었습니다.");
      return;
    }

    // 현재 위치 가져오기
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
    );
    setState(() {
      _currentLatLng = LatLng(position.latitude, position.longitude);
    });
  }

  /// 구글 맵이 생성된 직후 콜백
  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    // 화면 크기 가져오기 (지도의 너비/높이 조절용)
    final size = MediaQuery.of(context).size;

    return Column(
      children: [
        // 검색바
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'search',
                    prefixIcon: Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey[200],
                    contentPadding: EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 지도 (검색바와 매칭 시작 버튼 사이에 배치, 높이를 늘림)
        Container(
          margin: const EdgeInsets.symmetric(vertical: 16),
          width: size.width * 0.9,  // 매칭 버튼보다 조금 더 넓게
          height: 460,             // 이전보다 지도 영역을 늘림
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

        // 매칭 시작 버튼 (하단바와 조금 떨어뜨림)
        Container(
          width: size.width * 0.8, // 지도보다 살짝 좁게
          height: 50,
          margin: const EdgeInsets.only(bottom: 32), // 하단바와의 간격 추가
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
      ],
    );
  }
}
