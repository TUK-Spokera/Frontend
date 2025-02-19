import 'package:flutter/material.dart';

class MyPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('MYPAGE'),
        centerTitle: true,
      ),
      body: Center(
        child: Text(
          'mypage',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}




