import 'dart:math';
import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

/// 기본 MaterialApp 구조
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '스포츠 매칭 앱',
      debugShowCheckedModeBanner: false,
      home: RankingPage(),
    );
  }
}

/// 상단 탭바를 통해 풋살, 배드민턴, 탁구 탭을 제공하는 페이지
class RankingPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3, // 풋살, 배드민턴, 탁구 탭 3개
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

/// 각 종목별 순위 리스트를 표시하는 위젯 (Stateful로 구현하여 스크롤 제어)
class RankingList extends StatefulWidget {
  final String sport;

  RankingList({required this.sport});

  @override
  _RankingListState createState() => _RankingListState();
}

class _RankingListState extends State<RankingList> {
  final ScrollController _scrollController = ScrollController();
  bool _scrolledToCurrentUser = false;
  final double itemHeight = 72.0; // 각 아이템의 고정 높이

  /// 테스트용 100명의 유저 데이터를 생성하는 함수
  Future<List<Map<String, dynamic>>> fetchRanking() async {
    await Future.delayed(Duration(seconds: 1)); // 지연시간 시뮬레이션
    List<Map<String, dynamic>> ranking = [];
    Random random = Random();

    if (widget.sport == '풋살') {
      ranking = List.generate(100, (index) {
        return {
          'username': 'FutsalPlayer${index + 1}',
          'score': random.nextInt(2001),
        };
      });
    } else if (widget.sport == '배드민턴') {
      ranking = List.generate(100, (index) {
        return {
          'username': 'BadmintonPlayer${index + 1}',
          'score': random.nextInt(2001),
        };
      });
    } else if (widget.sport == '탁구') {
      ranking = List.generate(100, (index) {
        return {
          'username': 'TableTennisPlayer${index + 1}',
          'score': random.nextInt(2001),
        };
      });
    }

    // 점수를 내림차순으로 정렬
    ranking.sort((a, b) => b['score'].compareTo(a['score']));

    // 순위 부여
    for (int i = 0; i < ranking.length; i++) {
      ranking[i]['rank'] = i + 1;
    }
    return ranking;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: fetchRanking(),
      builder: (context, snapshot) {
        // 로딩 상태
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        // 에러 처리
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        // 데이터 없을 경우
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('순위 정보가 없습니다.'));
        }
        final rankingData = snapshot.data!;

        // 현재 사용자 설정 (예: 풋살이면 FutsalPlayer10)
        String currentUser;
        if (widget.sport == '풋살') {
          currentUser = "FutsalPlayer10";
        } else if (widget.sport == '배드민턴') {
          currentUser = "BadmintonPlayer10";
        } else {
          currentUser = "TableTennisPlayer10";
        }

        // 현재 사용자의 인덱스 찾기
        int currentUserIndex =
        rankingData.indexWhere((item) => item['username'] == currentUser);
        if (currentUserIndex == -1) currentUserIndex = 0;

        return LayoutBuilder(
          builder: (context, constraints) {
            // ListView가 차지하는 실제 높이
            double availableHeight = constraints.maxHeight;
            // 현재 사용자의 tile을 중앙에 배치하기 위한 스크롤 offset 계산
            double targetOffset = (currentUserIndex * itemHeight) -
                (availableHeight / 2) +
                (itemHeight / 2);
            if (targetOffset < 0) targetOffset = 0;

            // 아직 스크롤이 실행되지 않았다면 post frame callback에서 jumpTo 호출
            if (!_scrolledToCurrentUser) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_scrollController.hasClients) {
                  _scrollController.jumpTo(targetOffset);
                }
              });
              _scrolledToCurrentUser = true;
            }

            return ListView.builder(
              controller: _scrollController,
              itemCount: rankingData.length,
              itemBuilder: (context, index) {
                final item = rankingData[index];
                bool isCurrentUser = item['username'] == currentUser;
                return SizedBox(
                  height: itemHeight,
                  child: Container(
                    color: isCurrentUser ? Colors.yellow[100] : null,
                    child: ListTile(
                      leading: CircleAvatar(child: Text('${item['rank']}')),
                      title: Text(item['username']),
                      trailing: Text('Score: ${item['score']}'),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
