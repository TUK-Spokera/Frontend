import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';


final storage = FlutterSecureStorage(); // ✅ 보안 저장소 생성

// ✅ Access Token 저장
Future<void> saveAccessToken(String token) async {
  await storage.write(key: "accessToken", value: token);
}

// ✅ Refresh Token 저장
Future<void> saveRefreshToken(String token) async {
  await storage.write(key: "refreshToken", value: token);
}

// ✅ Access Token 가져오기
Future<String?> getAccessToken() async {
  return await storage.read(key: "accessToken");
}

// ✅ Refresh Token 가져오기
Future<String?> getRefreshToken() async {
  return await storage.read(key: "refreshToken");
}

// ✅ 토큰 삭제 (로그아웃 시 사용)
Future<void> deleteTokens() async {
  await storage.delete(key: "accessToken");
  await storage.delete(key: "refreshToken");
}



// ✅ 글로벌 변수 선언
String globalUsername = "";
String globalProfileImage = "";
//String globalToken = "";

// ✅ 글로벌 변수 설정 함수
void setGlobalUsername(String username) {
  globalUsername = username;
}

void setGlobalProfileImage(String imageUrl) {
  globalProfileImage = imageUrl;
}

// ✅ 글로벌 변수 가져오는 함수
String getGlobalUsername() {
  return globalUsername;
}

String getGlobalProfileImage() {
  return globalProfileImage;
}


int? _globalUserId;

void setGlobalUserId(int id) {
  _globalUserId = id;
}

int getGlobalUserId() {
  return _globalUserId ?? -1; // 기본값 -1
}

const String API_BASE_URL = "https://appledolphin.xyz"; // ✅ API 기본 URL


// ✅ Access Token 자동 갱신 함수
Future<bool> refreshAccessToken() async {
  String? refreshToken = await getRefreshToken();
  if (refreshToken == null) {
    print("❌ Refresh Token 없음. 다시 로그인 필요");
    return false;
  }

  try {
    final response = await http.post(
      Uri.parse("$API_BASE_URL/auth/refresh"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"refreshToken": refreshToken}),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      String newAccessToken = json['accessToken'];

      await saveAccessToken(newAccessToken); // ✅ 새로운 Access Token 저장
      print("🔄 Access Token 갱신 완료: $newAccessToken");
      return true;
    } else {
      print("❌ Access Token 갱신 실패: ${response.body}");
      return false;
    }
  } catch (e) {
    print("❌ 네트워크 오류: $e");
    return false;
  }
}

// ✅ 앱 시작 시 자동 로그인
Future<void> autoLogin() async {
  String? accessToken = await getAccessToken();

  if (accessToken == null) {
    print("🔄 Access Token 없음. 자동 로그인 시도...");
    bool refreshed = await refreshAccessToken();
    if (!refreshed) {
      print("❌ 자동 로그인 실패. 로그인 화면으로 이동 필요");
    }
  } else {
    print("✅ 자동 로그인 성공");
  }
}

