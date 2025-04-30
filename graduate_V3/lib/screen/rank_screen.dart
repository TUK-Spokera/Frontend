import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:graduate/utils/global.dart';

/// 1) 서버 JSON 구조에 맞춘 모델
class RankingEntry {
  final int rank;
  final int userId;
  final String nickname;
  final int rating;

  RankingEntry({
    required this.rank,
    required this.userId,
    required this.nickname,
    required this.rating,
  });

  factory RankingEntry.fromJson(Map<String, dynamic> json) {
    return RankingEntry(
      rank: json['rank'] as int,
      userId: json['userId'] as int,
      nickname: json['nickname'] as String,
      rating: json['rating'] as int,
    );
  }
}

class RankingPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('스포츠 순위'),
          bottom: TabBar(
            tabs: [
              Tab(text: '풋살'),
              Tab(text: '배드민턴'),
              Tab(text: '탁구'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            RankingList(sport: '풋살'),
            RankingList(sport: '배드민턴'),
            RankingList(sport: '탁구'),
          ],
        ),
      ),
    );
  }
}

class RankingList extends StatefulWidget {
  final String sport;
  RankingList({required this.sport});

  @override
  _RankingListState createState() => _RankingListState();
}

class _RankingListState extends State<RankingList> {
  final ScrollController _scrollController = ScrollController();
  bool _scrolledToCurrentUser = false;
  final double itemHeight = 72.0;

  Future<List<RankingEntry>> fetchRanking() async {
    final accessToken = await getAccessToken();
    final resp = await http.get(
      Uri.parse('https://appledolphin.xyz/api/ranking'), // 실제 엔드포인트로 교체
      headers: {
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
    );
    if (resp.statusCode != 200) {
      throw Exception('순위 정보를 불러오지 못했습니다 (${resp.statusCode})');
    }
    final bodyUtf8 = utf8.decode(resp.bodyBytes);

    final Map<String, dynamic> body = jsonDecode(bodyUtf8);

    final key = widget.sport == '풋살'
        ? 'futsalRanking'
        : widget.sport == '배드민턴'
        ? 'badmintonRanking'
        : 'pingpongRanking';

    final List<dynamic> list = body[key] as List<dynamic>;
    return list.map((e) => RankingEntry.fromJson(e)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = getGlobalUserId();

    return FutureBuilder<List<RankingEntry>>(
      future: fetchRanking(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }

        final rankingData = snap.data!;
        // 1) 내 순위 인덱스 찾기
        int myIndex = rankingData.indexWhere((e) => e.userId == currentUserId);
        if (myIndex == -1) myIndex = 0;

        return LayoutBuilder(builder: (context, cons) {
          final availH = cons.maxHeight;
          // 2) 오프셋 계산 (내 아이템이 중앙에 오도록)
          double offset = myIndex * itemHeight - (availH / 2) +
              (itemHeight / 2);
          if (offset < 0) offset = 0;

          // 3) 한 번만 스크롤
          if (!_scrolledToCurrentUser) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients) {
                _scrollController.animateTo(
                  offset.clamp(
                    0.0,
                    _scrollController.position.maxScrollExtent,
                  ),
                  duration: Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              }
            });
            _scrolledToCurrentUser = true;
          }

          // 4) 실제 리스트 그리기
          return ListView.builder(
            controller: _scrollController,
            itemCount: rankingData.length,
            itemBuilder: (context, i) {
              final e = rankingData[i];
              final isMe = e.userId == currentUserId;
              return SizedBox(
                height: itemHeight, // <-- 여기 높이 꼭 itemHeight 와 동일하게
                child: Container(
                  color: isMe ? Colors.yellow[100] : null,
                  child: ListTile(
                    leading: CircleAvatar(child: Text('${e.rank}')),
                    title: Text(e.nickname),
                    trailing: Text('Rating: ${e.rating}'),
                  ),
                ),
              );
            },
          );
        });
      },
    );
  }
}