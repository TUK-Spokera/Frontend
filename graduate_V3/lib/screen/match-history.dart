import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:graduate/utils/global.dart';

class MatchHistoryPage extends StatefulWidget {
  final String userId;
  const MatchHistoryPage({required this.userId});

  @override
  _MatchHistoryPageState createState() => _MatchHistoryPageState();
}

class _MatchHistoryPageState extends State<MatchHistoryPage> {
  late Future<List<dynamic>> matchHistory;

  @override
  void initState() {
    super.initState();
    matchHistory = fetchMatchHistory(widget.userId);
  }

  Future<List<dynamic>> fetchMatchHistory(String userId) async {
    final accessToken = await getAccessToken();

    final response = await http.get(
      Uri.parse('https://appledolphin.xyz/api/match/history'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('대전 기록을 불러올 수 없습니다');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('대전 기록')),
      body: FutureBuilder<List<dynamic>>(
        future: matchHistory,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('불러오기 실패: ${snapshot.error}'));
          }

          final matches = snapshot.data!;
          if (matches.isEmpty) {
            return Center(child: Text('기록된 경기가 없습니다.'));
          }

          return ListView.builder(
            itemCount: matches.length,
            itemBuilder: (context, index) {
              final match = matches[index];
              final startTime = DateTime.parse(match['startTime']);
              final date = "${startTime.year}-${startTime.month.toString().padLeft(2, '0')}-${startTime.day.toString().padLeft(2, '0')}";
              final result = match['result'] == 'WIN' ? '승리' : '패배';

              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text('${match['sportType']}  (${match['matchType']})'),
                  subtitle: Text('$date • ${match['teamType']}팀 • 결과: $result'),
                  trailing: Icon(Icons.chevron_right),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => _buildDetailDialog(match),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDetailDialog(dynamic match) {
    return AlertDialog(
      title: Text('세트별 점수'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: (match['setScores'] as List<dynamic>).map((set) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('세트 ${set['setNumber']}'),
              Text('RED ${set['redTeamScore']} : ${set['blueTeamScore']} BLUE'),
            ],
          );
        }).toList(),
      ),
      actions: [
        TextButton(
          child: Text('닫기'),
          onPressed: () => Navigator.pop(context),
        )
      ],
    );
  }
}