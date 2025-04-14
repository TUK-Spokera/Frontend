import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'chat.dart';
import 'package:graduate/utils/global.dart';


class ChatListScreen extends StatefulWidget {
  final String username;

  ChatListScreen({required this.username}) {
    print("🔥 [ChatListScreen] username 값: $username"); // ✅ 값 확인
  }

  @override
  _ChatListScreenState createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<dynamic> chatRooms = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    print("🚀 [ChatListScreen] initState 실행됨!");  // ✅ 확인용 로그 추가
    _fetchChatRooms();
  }

  Future<void> _fetchChatRooms() async {
    print("🚀 [ChatListScreen] _fetchChatRooms 실행 시작...");

    final url = Uri.parse('http://appledolphin.xyz:8080/api/chat/rooms');
    print("🌍 [ChatListScreen] 요청 URL: $url");

    try {
      final accessToken = await getAccessToken();
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      print("✅ [ChatListScreen] 서버 응답 코드: ${response.statusCode}");

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        print("🎉 [ChatListScreen] 받은 데이터: $data");

        // 중복 제거 (matchId 기준)
        final uniqueChatRooms = {
          for (var room in data) room['matchId']: room
        }.values.toList();

        setState(() {
          chatRooms = uniqueChatRooms;
          isLoading = false;
        });
        print("✅ [ChatListScreen] UI 업데이트 완료! chatRooms 길이: ${chatRooms.length}");
      } else {
        print("❌ [ChatListScreen] 서버 오류: ${response.statusCode}");
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print("🔥 [ChatListScreen] 네트워크 오류 발생: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    print("🎨 [ChatListScreen] build() 실행됨! isLoading: $isLoading, chatRooms 길이: ${chatRooms.length}");

    return Scaffold(
      appBar: AppBar(
        title: Text('채팅방 목록'),
        centerTitle: true,
        backgroundColor: Colors.blue,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator()) // ✅ 로딩 중이면 로딩 표시
          : chatRooms.isEmpty
          ? Center(child: Text("참여한 채팅방이 없습니다.")) // ✅ 데이터가 없으면 메시지 출력
          : ListView.builder(
        itemCount: chatRooms.length,
        itemBuilder: (context, index) {
          final room = chatRooms[index];

          final String sportType = room['sportType'] ?? '알 수 없음';
          final int matchId = room['matchId'] ?? -1;
          final String startTime = room['startTime'] ?? '시간 정보 없음';
          final String endTime = room['endTime'] ?? '시간 정보 없음';

          Map<String, String> sportEmojis = {
            "배드민턴": "🏸",
            "풋살": "⚽",
            "농구": "🏀",
            "당구": "🎱",
            "테니스": "🎾",
          };

          return Card(
            margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: ListTile(
              title: Text(
                "${sportEmojis[sportType] ?? '❓'} $sportType - $matchId",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                "🕒 $startTime ~ $endTime",
                style: TextStyle(color: Colors.grey[600]),
              ),
              trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              onTap: () {
                print("📩 [채팅방 이동] matchId = $matchId");
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      matchId: matchId,
                      username: getGlobalUsername(),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
