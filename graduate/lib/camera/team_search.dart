import 'package:flutter/material.dart';

class TeamSearchScreen extends StatelessWidget {
  const TeamSearchScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('팀원찾기'),
      ),
      body: const Center(
        child: Text(
          '팀원찾기 페이지입니다',
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
