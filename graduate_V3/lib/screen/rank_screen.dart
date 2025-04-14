import 'dart:math';
import 'package:flutter/material.dart';

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

  Future<List<Map<String, dynamic>>> fetchRanking() async {
    await Future.delayed(Duration(seconds: 1));
    List<Map<String, dynamic>> ranking = [];
    Random random = Random();

    ranking = List.generate(100, (index) {
      return {
        'username': '${widget.sport}Player${index + 1}',
        'score': random.nextInt(2001),
      };
    });

    ranking.add({
      'username': '남궁용진',
      'score': widget.sport == '풋살' ? 1890 : widget.sport == '배드민턴' ? 1730 : 1500,
    });

    ranking.sort((a, b) => b['score'].compareTo(a['score']));

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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: \${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('순위 정보가 없습니다.'));
        }
        final rankingData = snapshot.data!;
        String currentUser = '남궁용진';

        int currentUserIndex = rankingData.indexWhere((item) => item['username'] == currentUser);
        if (currentUserIndex == -1) currentUserIndex = 0;

        return LayoutBuilder(
          builder: (context, constraints) {
            double availableHeight = constraints.maxHeight;
            double targetOffset = (currentUserIndex * itemHeight) - (availableHeight / 2) + (itemHeight / 2);
            if (targetOffset < 0) targetOffset = 0;

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
