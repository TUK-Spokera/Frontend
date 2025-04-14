import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:graduate/screen/chat.dart';
import 'package:graduate/screen/chat_list.dart';
import 'package:graduate/screen/mypage.dart';
import 'package:graduate/main.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:graduate/screen/matching_list.dart';
import 'package:graduate/utils/global.dart';
import 'package:graduate/screen/main_screen.dart';

import '../camera/gift_search.dart';
import '../camera/team_search.dart';

class Matchingstart extends StatefulWidget {
  @override
  _MatchingScreenState createState() => _MatchingScreenState();
}

class _MatchingScreenState extends State<Matchingstart> {
  int _currentIndex = 0;

  String selectedSport = '선택';
  String selectedTeamConfig = '선택';
  DateTime? selectedDate;
  TimeOfDay? selectedStartTime;
  TimeOfDay? selectedEndTime;

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('오류'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('확인'),
            ),
          ],
        );
      },
    );
  }


  Future<void> sendMatchRequest() async {
    const String apiUrl = "$API_BASE_URL/api/match/recommend";

    // ✅ Access Token 가져오기
    String? accessToken = await getAccessToken();

    if (accessToken == null || accessToken.isEmpty) {
      print("❌ Access Token 없음. 자동 로그인 시도");
      bool success = await refreshAccessToken();
      if (success) {
        accessToken = await getAccessToken();
      } else {
        _showErrorDialog("로그인이 필요합니다.");
        return;
      }
    }

    if (getGlobalUsername().isEmpty) {
      print("ℹ️ 사용자 이름 비어있음 → 정보 요청");
      final fetched = await fetchAndSetUserInfo();
      if (!fetched) {
        _showErrorDialog("사용자 정보를 불러올 수 없습니다.");
        return;
      } else {
        print("✅ 사용자 정보 재요청 성공: ${getGlobalUsername()}");
      }
    }


    // ✅ 항목 체크
    if (selectedSport == '선택' ||
        selectedTeamConfig == '선택' ||
        selectedDate == null ||
        selectedStartTime == null ||
        selectedEndTime == null) {
      _showErrorDialog('모든 항목을 선택해 주세요.');
      return;
    }

    // ✅ 시간 포맷
    String formattedStartTime =
        "${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}T"
        "${selectedStartTime!.hour.toString().padLeft(2, '0')}:${selectedStartTime!.minute.toString().padLeft(2, '0')}:00";

    String formattedEndTime =
        "${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}T"
        "${selectedEndTime!.hour.toString().padLeft(2, '0')}:${selectedEndTime!.minute.toString().padLeft(2, '0')}:00";

    // ✅ 팀 구성 매핑
    String matchType = {
      "1:1": "ONE_VS_ONE",
      "2:2": "TWO_VS_TWO",
      "3:3": "THREE_VS_THREE",
      "5:5": "FIVE_VS_FIVE"
    }[selectedTeamConfig]!;

    Map<String, dynamic> requestData = {
      //"userId" : getGlobalUserId(),
      "sportType": selectedSport,
      "startTime": formattedStartTime,
      "endTime": formattedEndTime,
      "matchType": matchType
    };

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(child: CircularProgressIndicator()),
      );

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          "Authorization": "Bearer $accessToken",
          "Content-Type": "application/json",
        },
        body: jsonEncode(requestData),
      );

      Navigator.pop(context);

      if (response.statusCode == 200) {
        List<dynamic> recommendedMatches = jsonDecode(utf8.decode(response.bodyBytes));
        print("✅ 매칭 목록 불러오기 성공: ${recommendedMatches.length}개");

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MatchingList(
              username: getGlobalUsername(),
              recommendedMatches: recommendedMatches,
              requestData: requestData,
            ),
          ),
        );
      } else if (response.statusCode == 401) {
        print("🔄 토큰 만료 → 갱신 시도");
        bool refreshed = await refreshAccessToken();
        if (refreshed) {
          await sendMatchRequest(); // 다시 시도
        } else {
          _showErrorDialog("다시 로그인 해주세요.");
        }
      } else {
        print("❌ 매칭 목록 불러오기 실패: ${response.statusCode}");
        print("❌ 서버 응답: ${response.body}");
        _showErrorDialog("매칭 목록을 불러오지 못했습니다.");
      }
    } catch (e) {
      Navigator.pop(context);
      print("🔥 네트워크 오류: $e");
      _showErrorDialog("네트워크 오류가 발생했습니다.");
    }
  }




  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('매칭',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.black),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '이름: ',
                 style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                getGlobalUsername(),
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 20),
              buildSectionTitle('스포츠 선택'),
              buildSelectionBox(
                content: selectedSport,
                onTap: () async {
                  String? pickedSport = await showSelectionDialog(
                    context,
                    '스포츠 선택',
                    ['배드민턴', '풋살', '탁구'],
                  );
                  if (pickedSport != null) {
                    setState(() {
                      selectedSport = pickedSport;
                      selectedTeamConfig = '선택';
                    });
                  }
                },
              ),
              SizedBox(height: 20),
              buildSectionTitle('팀 구성 방식'),
              buildSelectionBox(
                content: selectedTeamConfig,
                onTap: selectedSport != '선택'
                    ? () async {
                  String? pickedConfig = await showSelectionDialog(
                    context,
                    '팀 구성 방식 선택',
                    teamConfigurations[selectedSport]!,
                  );
                  if (pickedConfig != null) {
                    setState(() {
                      selectedTeamConfig = pickedConfig;
                    });
                  }
                }
                    : null,
              ),
              SizedBox(height: 20),
              buildSectionTitle('경기 가능 날짜'),
              buildSelectionBox(
                content: selectedDate != null
                    ? '${selectedDate!.year}-${selectedDate!.month}-${selectedDate!.day}'
                    : '선택',
                onTap: () async {
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: selectedDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                  );
                  if (pickedDate != null) {
                    setState(() {
                      selectedDate = pickedDate;
                    });
                  }
                },
              ),
              SizedBox(height: 20),
              buildSectionTitle('경기 가능 시간'),
              SizedBox(height: 8),
              GestureDetector(
                onTap: () => _pickTime(context, true),
                child: buildSelectionBox(
                  content: selectedStartTime != null
                      ? '${selectedStartTime!.hour.toString().padLeft(2, '0')}:${selectedStartTime!.minute.toString().padLeft(2, '0')}'
                      : '시작 시간 선택',
                ),
              ),
              SizedBox(height: 10),
              GestureDetector(
                onTap: () => _pickTime(context, false),
                child: buildSelectionBox(
                  content: selectedEndTime != null
                      ? '${selectedEndTime!.hour.toString().padLeft(2, '0')}:${selectedEndTime!.minute.toString().padLeft(2, '0')}'
                      : '종료 시간 선택',
                ),
              ),
              SizedBox(height: 32),
              ElevatedButton(
                onPressed:sendMatchRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.withOpacity(0.8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 16),
                  minimumSize: Size(double.infinity, 56),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '다음(매칭요청)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward,
                      color: Colors.white.withOpacity(0.8),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

  final List<Widget> _screen = [
    ChatListScreen(username: getGlobalUsername()),
    MyPageScreen(),
    HomeScreenContent(),
  ];

  final Map<String, List<String>> teamConfigurations = {
    '배드민턴': ['1:1', '2:2'],
    '풋살': ['5:5'],
    '탁구': ['1:1', '2:2'],
  };

  Future<void> _pickTime(BuildContext context, bool isStartTime) async {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 250,
        color: Colors.white,
        child: Column(
          children: [
            Expanded(
              child: CupertinoTimerPicker(
                mode: CupertinoTimerPickerMode.hm,
                onTimerDurationChanged: (Duration duration) {
                  setState(() {
                    if (isStartTime) {
                      selectedStartTime = TimeOfDay(
                        hour: duration.inHours,
                        minute: duration.inMinutes % 60,
                      );
                    } else {
                      selectedEndTime = TimeOfDay(
                        hour: duration.inHours,
                        minute: duration.inMinutes % 60,
                      );
                    }
                  });
                },
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text("확인"),
            )
          ],
        ),
      ),
    );
  }


  Widget buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
    );
  }

  Widget buildSelectionBox({required String content, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        margin: EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          border: Border.all(color: Colors.grey[400]!, width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              content,
              style: TextStyle(fontSize: 16, color: onTap != null ? Colors.black : Colors.grey),
            ),
            Icon(
              Icons.arrow_drop_down,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> showSelectionDialog(BuildContext context, String title, List<String> options) async {
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              children: options.map((option) {
                return ListTile(
                  title: Text(option),
                  onTap: () {
                    Navigator.pop(context, option);
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}
Future<bool> fetchAndSetUserInfo() async {
  final accessToken = await getAccessToken();
  if (accessToken == null || accessToken.isEmpty) {
    print("❌ Access Token 없음");
    return false;
  }

  try {
    final response = await http.get(
      Uri.parse('$API_BASE_URL/api/user/me'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final userId = data['userId'];
      final nickname = data['nickname'] ?? '';
      final email = data['email'] ?? '';
      final profileImage = data['profileImage'] ?? '';

      if (nickname.isNotEmpty) {
        setGlobalUsername(nickname);
        setGlobalUserId(userId);
        setGlobalProfileImage(
          profileImage.isNotEmpty ? profileImage : "assets/profile_sample.jpg",
        );
        print("✅ 사용자 정보 저장 완료: $nickname");
        return true;
      } else {
        print("❌ 사용자 닉네임이 응답에 없음");
        return false;
      }
    } else {
      print("❌ 사용자 정보 요청 실패: ${response.statusCode}");
      print("❌ 응답 본문: ${response.body}");
      return false;
    }
  } catch (e) {
    print("❌ 사용자 정보 요청 중 예외 발생: $e");
    return false;
  }
}

