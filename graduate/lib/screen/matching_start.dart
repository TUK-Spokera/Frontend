import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:graduate/screen/chat.dart';
import 'package:graduate/screen/chat_list.dart';
import 'package:graduate/screen/mypage.dart';
import 'package:graduate/main.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class Matchingstart extends StatefulWidget {
  @override
  _MatchingScreenState createState() => _MatchingScreenState();
}

class _MatchingScreenState extends State<Matchingstart> {
  String selectedSport = '선택';
  String selectedTeamConfig = '선택';
  DateTime? selectedDate;
  TimeOfDay? selectedStartTime;
  TimeOfDay? selectedEndTime;

  Future<void> sendMatchRequest() async {
    const String apiUrl = "http://appledolphin.xyz:8080/api/match/request";

    if (selectedSport == '선택' ||
        selectedTeamConfig == '선택' ||
        selectedDate == null ||
        selectedStartTime == null ||
        selectedEndTime == null) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('오류'),
            content: Text('모든 항목을 선택해 주세요.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text('확인'),
              ),
            ],
          );
        },
      );
      return;

  }

    String formattedStartTime =
        "${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}T"
        "${selectedStartTime!.hour.toString().padLeft(2, '0')}:${selectedStartTime!.minute.toString().padLeft(2, '0')}:00";

    String formattedEndTime =
        "${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}T"
        "${selectedEndTime!.hour.toString().padLeft(2, '0')}:${selectedEndTime!.minute.toString().padLeft(2, '0')}:00";


    String matchType;
    if (selectedTeamConfig == "1:1") {
      matchType = "ONE_VS_ONE";
    } else if (selectedTeamConfig == "2:2") {
      matchType = "TWO_VS_TWO";
    } else if (selectedTeamConfig == "3:3") {
      matchType = "THREE_VS_THREE";
    } else if (selectedTeamConfig == "5:5") {
      matchType = "FIVE_VS_FIVE";
    } else {
      return;
    }

    Map<String, dynamic> requestData = {
      "username": "test1", //로그인 되면 바꾸기
      "sportType": selectedSport,
      "startTime": formattedStartTime,
      "endTime": formattedEndTime,
      "matchType": matchType
    };

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Center(
            child: CircularProgressIndicator(),
          );
        },
      );

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestData),
      );

      Navigator.pop(context);

      if (response.statusCode == 200) {
        Map<String, dynamic> responseData = jsonDecode(response.body);
        int matchId = responseData["matchId"];
        String status = responseData["status"];

        if (status == "WAITING") {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text('매칭 요청됨'),
                content: Text('현재 대기 중입니다. 상대방이 나타나면 매칭됩니다.'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text('확인'),
                  ),
                ],
              );
            },
          );
        } else if (status == "MATCHED") {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(matchId: matchId),
            ),
          );
        }
      } else {
        throw Exception("서버 응답 오류");
      }
    } catch (e) {
      Navigator.pop(context);
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('오류 발생'),
            content: Text('매칭 요청 중 오류가 발생했습니다. 다시 시도해주세요.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text('확인'),
              ),
            ],
          );
        },
      );
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
              TextField(
                decoration: InputDecoration(
                  labelText: '사용자의 아이디를 입력하세요.',
                ),
              ),
              SizedBox(height: 20),
              buildSectionTitle('스포츠 선택'),
              buildSelectionBox(
                content: selectedSport,
                onTap: () async {
                  String? pickedSport = await showSelectionDialog(
                    context,
                    '스포츠 선택',
                    ['배드민턴', '풋살', '농구', '당구', '테니스'],
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
        bottomNavigationBar: BottomNavigationBar(
          onTap: (index) {
            switch (index) {
              case 0: //채팅목록
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatList(),
                  ),
                );
                break;
              case 1: //홈
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HomeScreen(),
                  ),
                );
                break;
              case 2: //마이페이지
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MyPage(),
                  ),
                );
                break;
            }
          },
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.chat),
              label: '채팅방',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: '홈',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: '마이페이지',
            ),
          ],
        ),

      );
    }

  final List<Widget> _screen = [
    ChatList(),
    MyPage(),
    HomeScreen(),
  ];

  final Map<String, List<String>> teamConfigurations = {
    '배드민턴': ['1:1', '2:2'],
    '풋살': ['5:5'],
    '농구': ['3:3', '5:5'],
    '당구': ['1:1', '2:2'],
    '테니스': ['1:1', '2:2'],
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