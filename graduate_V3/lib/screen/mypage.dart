import 'package:flutter/material.dart';
import 'package:graduate/utils/global.dart'; // 글로벌 함수 포함
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:graduate/screen/match-history.dart';

class MyPageScreen extends StatefulWidget {
  @override
  _MyPageScreenState createState() => _MyPageScreenState();

}

class _MyPageScreenState extends State<MyPageScreen> {
  String username = '';
  String profileImage = '';

  @override
  void initState() {
    super.initState();
    loadUserData();
    checkStoredTokens();
  }

  Future<String?> getUserIdFromAccessToken() async {
    final token = await getAccessToken();
    if (token == null) return null;

    final parts = token.split('.');
    if (parts.length != 3) return null;

    final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    final Map<String, dynamic> payloadMap = jsonDecode(payload);

    return payloadMap['sub'].toString(); // userId로 설정된 claim
  }

  Future<void> loadUserData() async {
    try {
      final accessToken = await getAccessToken();
      if (accessToken == null) {
        print("❌ AccessToken 없음");
        return;
      }

      final response = await http.get(
        Uri.parse('$API_BASE_URL/user/me'),
        headers: {
          "Authorization": "Bearer $accessToken",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        print("👤 사용자 정보: $data");

        final rawName = data['nickname'] ?? 'Unknown';
        final rawImage = data['profileImage'] ?? '';

        setGlobalUsername(rawName);
        setGlobalProfileImage(rawImage);

        setState(() {
          username = rawName;
          profileImage = rawImage;
        });
      } else {
        print("❌ 사용자 정보 불러오기 실패: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ 사용자 정보 로딩 오류: $e");
    }
  }

  Future<void> checkStoredTokens() async {
    try {
      final accessToken = await getAccessToken();
      final refreshToken = await getRefreshToken();

      print('📦 저장된 AccessToken: $accessToken');
      print('📦 저장된 RefreshToken: $refreshToken');

      if (accessToken != null) {
        final parts = accessToken.split('.');
        if (parts.length == 3) {
          final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
          print('🧾 AccessToken Payload: $payload');
        }
      }
    } catch (e) {
      print('❌ JWT 확인 중 에러: $e');
    }
  }

  Future<void> logout() async {
    await deleteTokens(); // SecureStorage의 토큰 삭제
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();  // SharedPreferences도 정리

    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('마이페이지')),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          _buildAccountSection(),
          SizedBox(height: 20),
          _buildSettingsSection(),
        ],
      ),
    );
  }

  Widget _buildAccountSection() {
    ImageProvider imageProvider;

    if (profileImage.isEmpty) {
      imageProvider = AssetImage('assets/profile_placeholder.png');
    } else if (profileImage.startsWith('http')) {
      imageProvider = NetworkImage(profileImage);
    } else {
      imageProvider = AssetImage(profileImage);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundImage: imageProvider,
            ),
            SizedBox(height: 10),
            Text(
              username.isNotEmpty ? username : '로그인 정보 없음',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: logout,
              child: Text('로그아웃'),
            ),
            SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () async {
                final userId = await getUserIdFromAccessToken();
                if (userId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MatchHistoryPage(userId: userId),
                    ),
                  );
                } else {
                  // 오류 처리
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("유저 정보를 가져올 수 없습니다.")),
                  );
                }
              },
              icon: Icon(Icons.sports_score),
              label: Text('대전 기록'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('앱 설정', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SwitchListTile(
          title: Text('매칭 요청 알림'),
          value: true,
          onChanged: (bool value) {},
        ),
        SwitchListTile(
          title: Text('채팅 알림'),
          value: true,
          onChanged: (bool value) {},
        ),
      ],
    );
  }
}
