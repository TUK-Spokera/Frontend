import 'package:flutter/material.dart';

class ChatList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('채팅목록'),
        centerTitle: true,
      ),
      body: Center(
        child: Text(
          '채팅목록',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
