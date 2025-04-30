import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:graduate/screen/matching_map.dart';
import 'package:graduate/screen/chat_list.dart';
import 'package:graduate/screen/mypage.dart';
import 'package:graduate/main.dart';
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';
import 'package:http/http.dart' as http;
import 'package:graduate/screen/main_screen.dart';
import 'package:graduate/utils/global.dart';


class ChatScreen extends StatefulWidget {
  final int matchId;
  final String username;

  ChatScreen({required this.matchId, required this.username});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final List<Map<String, String>> _messages = [];

  late StompClient _stompClient;
  bool _isConnected = false;

  static const String websocketUrl = 'https://appledolphin.xyz/ws';

  Map<String, dynamic>? voteResult;

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
    _initializeStomp();
  }
  void _initializeStomp() async {
    final accessToken = await getAccessToken();
    if (accessToken == null) {
      print('❌ accessToken 없음');
      return;
    }

    print('🪪 accessToken: $accessToken');
    _connectToStomp(accessToken);
  }


  // ✅ 채팅 내역 불러오기 (REST API)
  Future<void> _loadChatHistory() async {
    final accessToken = await getAccessToken();
    final String url = 'http://appledolphin.xyz:8080/api/chat/history/${widget.matchId}';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        List<dynamic> history = jsonDecode(response.body);
        setState(() {
          _messages.addAll(history.map((msg) => {
            'sender': msg['senderName'],
            'text': msg['content']
          }));
        });
      } else {
        print("채팅 내역 불러오기 실패: ${response.statusCode}");
      }
    } catch (e) {
      print("네트워크 오류: $e");
    }
  }

  void _connectToStomp(String accessToken) {

    final stompUrl = 'wss://appledolphin.xyz/ws';
    //print('🌐 STOMP 연결 URL: wss://appledolphin.xyz/ws');

    _stompClient = StompClient(
      config: StompConfig(
        url: stompUrl,
        stompConnectHeaders: {
          'Authorization': 'Bearer $accessToken',
        },
        webSocketConnectHeaders: {
          'Authorization': 'Bearer $accessToken',
        },
        onConnect: _onStompConnect,
        beforeConnect: () async {
          print("STOMP 연결을 시도하는 중...");
          await Future.delayed(Duration(milliseconds: 200));
        },
        onWebSocketError: (dynamic error) {
          print('❌ STOMP 연결 오류 발생: $error');
        },
        onDisconnect: (frame) {
          print('📴 STOMP 연결 종료됨.');
          setState(() {
            _isConnected = false;
          });
        },
        // timeout 등도 넣고 싶다면 여기에 추가 가능
      ),
    );
    _stompClient.activate();
  }



  // ✅ STOMP 연결 성공 시, 채팅방 구독
  void _onStompConnect(StompFrame frame) {
    setState(() {
      _isConnected = true;
    });

    print('STOMP 연결됨.');

    _stompClient.subscribe(
      destination: '/topic/room/${widget.matchId}',
      callback: (StompFrame frame) {
        if (frame.body != null) {
          try {
            final decodedData = jsonDecode(frame.body!);
            if(decodedData['type']== 'VOTE_RESULT'){
              print('투표 결과 수신: $decodedData');
              setState(() {
                voteResult = decodedData;
              });
            } else{
              setState(() {
                _messages.add({
                  'sender': decodedData['senderName'] ?? '알 수 없음',
                  'text': decodedData['content'] ?? '',

                });
            });
    }
          } catch (e) {
            print('JSON 디코딩 오류: $e');
          }
        }
      },
    );
  }

  void _sendVote(String facilityName) {
    if (!_isConnected) {
      print("❌ STOMP 연결되지 않음. 투표 불가");
      return;
    }

    final voteMessage = {
      'matchId': widget.matchId,
      'facilityName': facilityName,
    };

    _stompClient.send(
      destination: '/app/chat.sendVote',
      body: jsonEncode(voteMessage),
    );

    print("📨 투표 전송 완료: $facilityName");
  }



  @override
  void dispose() {
    _stompClient.deactivate();
    super.dispose();
  }

  void _handleSendMessage(String text) {
    if (text.trim().isEmpty) return;

    if (!_stompClient.connected) {
      print("❌ STOMP 연결되지 않음. 메시지 전송 불가");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('채팅 서버와 연결되어 있지 않습니다.')),
      );
      return;
    }

    final message = {
      'matchId': widget.matchId,
      'senderName': widget.username,
      'content': text
    };

    _stompClient.send(
      destination: '/app/chat.sendMessage',
      body: jsonEncode(message),
    );

    _textController.clear();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('채팅방 - Match ID: ${widget.matchId}'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          if (voteResult != null) ...[
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("📊 투표 현황", style: TextStyle(fontWeight: FontWeight.bold)),
                  ...voteResult!['voteCounts'].entries.map<Widget>((entry) {
                    return Text("${entry.key}: ${entry.value}표");
                  }).toList(),
                  if (voteResult!['selectedFacility'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        "✅ 최종 선택: ${voteResult!['selectedFacility']}",
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
          ],

          Expanded(

            child: ListView.builder(
              reverse: true,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[_messages.length - 1 - index];
                final isMe = message['sender'] == widget.username;

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        constraints: BoxConstraints(maxWidth: 200),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blue : Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          message['text']!,
                          style: TextStyle(
                            color: isMe ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        message['sender']!,
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: '메시지 입력...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: () {
                    _handleSendMessage(_textController.text);
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
            onPressed: () async {
              final selectedFacility = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => MatchingMap(matchId: widget.matchId)),
              );

                if (selectedFacility != null) {
                  print("🗳️ 선택된 시설 이름: $selectedFacility");
                    _sendVote(selectedFacility); // 서버로 투표 전송
                }
                },

                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '다음',
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
          ),
        ],
      ),
    );
  }

}
