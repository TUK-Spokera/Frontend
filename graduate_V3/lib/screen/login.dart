import 'package:flutter/material.dart';
import 'package:flutter_web_auth/flutter_web_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:graduate/utils/global.dart'; // secure storage, 글로벌 함수 포함
import 'package:flutter/foundation.dart';

class LoginScreen extends StatelessWidget {
  static const KAKAO_CLIENT_ID = 'cc36a041ea25f338bef9fb13eb73856a';
  static const LOGIN_REDIRECT_URI = 'spokera://login/callback';
  static const SERVER_KAKAO_REDIRECT = 'https://appledolphin.xyz/oauth/kakao/redirect';

  // 🔐 카카오 로그인
  Future<void> loginWithKakao(BuildContext context) async {
    try {
      final authUrl =
          'https://kauth.kakao.com/oauth/authorize'
          '?response_type=code'
          '&client_id=$KAKAO_CLIENT_ID'
          '&redirect_uri=$SERVER_KAKAO_REDIRECT'
          '&prompt=login';

      final result = await FlutterWebAuth.authenticate(
        url: authUrl,
        callbackUrlScheme: "spokera",
      );

      final uri = Uri.parse(result);
      final accessToken = uri.queryParameters['accessToken'];
      final refreshToken = uri.queryParameters['refreshToken'];

      if (accessToken != null && refreshToken != null) {
        // ✅ SecureStorage에 저장
        await saveAccessToken(accessToken);
        await saveRefreshToken(refreshToken);

        print("✅ 토큰 저장 완료");

        // 🔥 사용자 정보 가져오기
        await fetchAndSetUserInfo();

        // 홈 화면으로 이동
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        print("❌ 토큰이 전달되지 않음");
      }
    } catch (e) {
      print("❌ 로그인 실패: $e");
    }
  }

  // 🔍 유저 정보 요청
  Future<void> fetchAndSetUserInfo() async {
    final accessToken = await getAccessToken();
    if (accessToken == null) {
      print("❌ AccessToken 없음");
      return;
    }

    final uri = Uri.parse('$API_BASE_URL/user/me');

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes)); // ✅ 인코딩 문제 방지
      final nickname = data['nickname'] ?? 'Unknown';
      final email = data['email'] ?? '';
      final profileImage = data['profileImage'] ?? '';

      setGlobalUsername(nickname);
      setGlobalProfileImage(
          profileImage.isNotEmpty ? profileImage : "assets/profile_sample.jpg");

      print("👤 사용자 정보 설정 완료: $nickname");
    } else {
      print("❌ 사용자 정보 요청 실패: ${response.statusCode}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              child: Text("카카오 로그인"),
              onPressed: () => loginWithKakao(context),
            ),

            // ✅ 개발용 "건너뛰기" 버튼
            if (kDebugMode)
              ElevatedButton(
                child: Text("건너뛰기 (개발용)"),
                onPressed: () {
                  // 임시 유저 이름 설정
                  setGlobalUsername('개발자테스트');
                  // 홈 화면으로 이동
                  Navigator.pushReplacementNamed(context, '/home');
                },
              ),
          ],
        ),
      ),
    );
  }
}
