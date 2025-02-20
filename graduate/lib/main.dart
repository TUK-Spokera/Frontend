import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:graduate/screen/matching_start.dart';
import 'package:graduate/screen/chat_list.dart';
import 'package:graduate/screen/mypage.dart';
import 'package:graduate/camera/team_search.dart';   // 팀원찾기 (테스트용)
import 'package:graduate/camera/gift_search.dart';  // 보상찾기 (ARKit)

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
        '/team_search': (context) => TeamSearchScreen(),
        // 보상찾기는 Navigator.push로 이동할 예정이므로 굳이 라우트로 등록 안 해도 됨
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
  // 기본 탭: 홈(인덱스 2)
  int _currentIndex = 2;

  // 보상찾기(인덱스 4)는 push로 따로 처리할 것이므로, _screens에는 4개만 넣음
  final List<Widget> _screens = [
    ChatList(),          // 인덱스 0: 채팅방
    MyPage(),            // 인덱스 1: 마이페이지
    HomeScreenContent(), // 인덱스 2: 홈
    TeamSearchScreen(),  // 인덱스 3: 팀원찾기
    // 인덱스 4는 Navigator.push로 처리 (GiftSearchScreen)
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 상단바
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '홈 화면',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      // 인덱스가 4일 경우 _screens에 화면이 없으므로, 4 미만일 때만 body에 표시
      body: (_currentIndex < _screens.length) ? _screens[_currentIndex] : Container(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          // 보상찾기(인덱스 4) 탭을 누르면 새 페이지로 push
          if (index == 4) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const GiftSearchScreen()),
            );
            // 인덱스는 바꾸지 않아야, 돌아왔을 때 기존 탭이 유지됨
          } else {
            // 나머지 탭은 그냥 setState로 교체
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
            icon: Icon(Icons.card_giftcard),
            label: '보상찾기',
          ),
        ],
      ),
    );
  }
}

class HomeScreenContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: NetworkImage(
                      'https://via.placeholder.com/150', // 아바타 이미지
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'kera',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('3승 1패'),
                  const Text('승률 75%'),
                  const SizedBox(height: 16),
                  const Divider(),
                  for (int i = 1; i <= 5; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '스포츠 $i',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const Text(
                            '전적: 0승 0패',
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => Matchingstart(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              '매칭시작',
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
