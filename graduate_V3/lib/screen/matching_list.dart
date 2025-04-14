import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'chat.dart';
import 'package:graduate/utils/global.dart';

class MatchingList extends StatelessWidget {
  final String username;
  final List<dynamic> recommendedMatches;
  final Map<String, dynamic> requestData;

  MatchingList({
    required this.username,
    required this.recommendedMatches,
    required this.requestData,
  });

  Future<void> _joinMatch(BuildContext context, int matchId) async {
    final url = Uri.parse('http://appledolphin.xyz:8080/api/match/join');
    final accessToken = await getAccessToken();
    final requestBody = {"username": username, "matchId": matchId};

    try {
      final response = await http.post(
        url,
        headers: {
          "Authorization": "Bearer $accessToken",
          "Content-Type": "application/json"
        },
        body: jsonEncode(requestBody),
      );
      if (response.statusCode == 200) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => ChatScreen(
            matchId: matchId,
            username: getGlobalUsername(),
          )),
        );
      } else {
        _showErrorDialog(context, '매칭방 참여 실패');
      }
    } catch (e) {
      _showErrorDialog(context, '네트워크 오류');
    }
  }

  Future<void> _createMatch(BuildContext context) async {
    final url = Uri.parse('http://appledolphin.xyz:8080/api/match/create');
    final accessToken = await getAccessToken();

    try {
      final response = await http.post(
        url,
        headers: {
          "Authorization":"Bearer $accessToken",
          "Content-Type": "application/json"
        },
        body: jsonEncode(requestData),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final int matchId = data["matchId"];

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => ChatScreen(
              matchId: matchId,
            username: getGlobalUsername(),
          )),
        );
      } else {
        _showErrorDialog(context, '매칭방 생성 실패');
      }
    } catch (e) {
      _showErrorDialog(context, '네트워크 오류');
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
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

  void saveUsername(String username) {
    setGlobalUsername(username); // 🔹 사용자 입력값 저장
    print(getGlobalUsername());  // 🔹 저장된 값 확인
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("추천된 매칭방")),
      body: recommendedMatches.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("추천된 매칭방이 없습니다."),
            ElevatedButton(
              onPressed: () => _createMatch(context),
              child: Text("방 생성하기"),
            ),
          ],
        ),
      )
          : ListView.builder(
        itemCount: recommendedMatches.length,
        itemBuilder: (context, index) {
          final match = recommendedMatches[index];
          return ListTile(
            title: Text("${match['sportType']} | ${match['startTime']} - ${match['matchId']}"),

            subtitle: Text("추천 점수: ${match['recommendationScore']}"),
            trailing: ElevatedButton(
              onPressed: () => _joinMatch(context, match['matchId']),
              child: Text("참여하기"),
            ),
          );
        },
      ),
    );
  }
}

