import 'package:flutter/material.dart';

// 시뮬레이션용 전역 변수
List<String> simulatedMatchResults = [];

void main() {
  runApp(MyApp());
}

/// 기본 MaterialApp 구조
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '경기 결과 입력',
      debugShowCheckedModeBanner: false,
      home: MatchResultPage(),
    );
  }
}

/// 승리/패배 결과를 입력하는 페이지
class MatchResultPage extends StatefulWidget {
  @override
  _MatchResultPageState createState() => _MatchResultPageState();
}

class _MatchResultPageState extends State<MatchResultPage> {
  // 사용자가 선택한 결과 (승리 또는 패배)
  String? _selectedResult;
  bool _isSubmitting = false;
  String _message = '';

  /// 서버로부터 완료 메시지를 받을 때까지 계속 대기하는 시뮬레이션 함수
  Future<bool> _waitForServerCompletion() async {
    // 4명의 결과가 집계될 때까지 기다림
    while (simulatedMatchResults.length < 4) {
      await Future.delayed(Duration(seconds: 1));
    }
    // 서버에서 처리 후 완료 메시지 전송까지 추가 딜레이 (예시: 2초)
    await Future.delayed(Duration(seconds: 2));
    // 집계된 결과 검사: 승리 2개, 패배 2개인지 확인
    int winCount = simulatedMatchResults.where((result) => result == '승리').length;
    int lossCount = simulatedMatchResults.where((result) => result == '패배').length;
    return (winCount == 2 && lossCount == 2);
  }

  /// 결과 전송 함수
  Future<void> _submitResult() async {
    if (_selectedResult == null) {
      setState(() {
        _message = '승리 또는 패배를 먼저 선택해 주세요.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _message = '';
    });

    // 현재 사용자의 결과를 전역 변수에 추가 (실제 서버에서는 개별 클라이언트 요청으로 집계됨)
    simulatedMatchResults.add(_selectedResult!);
    print("현재까지 집계된 결과: $simulatedMatchResults");

    // 결과 전송 후, 서버의 완료 메시지를 기다리는 동안 로딩 상태 유지
    bool isValid = await _waitForServerCompletion();

    // 서버에서 완료 메시지를 받으면 로딩 아이콘 제거 후 결과 표시
    if (isValid) {
      setState(() {
        _message = '결과가 정상적으로 서버에 전송되었습니다.';
      });
    } else {
      setState(() {
        _message = '입력한 결과가 올바르지 않습니다. 다시 입력해 주세요.';
      });
      // 잘못된 결과인 경우, 전역 변수 초기화하여 재입력을 요청
      simulatedMatchResults.clear();
    }

    setState(() {
      _isSubmitting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Stack으로 전체 UI와 오버레이(로딩 상태)를 함께 구성
    return Scaffold(
      appBar: AppBar(
        title: Text('경기 결과 입력'),
      ),
      body: Stack(
        children: [
          // 기본 UI (승리/패배 아이콘과 전송 버튼)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 승리와 패배 아이콘이 있는 라인
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 승리 아이콘
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedResult = '승리';
                        });
                      },
                      child: Column(
                        children: [
                          Icon(
                            Icons.emoji_events, // 트로피 아이콘 (승리)
                            size: 80,
                            color: _selectedResult == '승리'
                                ? Colors.green
                                : Colors.grey,
                          ),
                          SizedBox(height: 8),
                          Text(
                            '승리',
                            style: TextStyle(fontSize: 18),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 40),
                    // 패배 아이콘
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedResult = '패배';
                        });
                      },
                      child: Column(
                        children: [
                          Icon(
                            Icons.cancel, // 취소 아이콘 (패배)
                            size: 80,
                            color: _selectedResult == '패배'
                                ? Colors.red
                                : Colors.grey,
                          ),
                          SizedBox(height: 8),
                          Text(
                            '패배',
                            style: TextStyle(fontSize: 18),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 40),
                // 결과 전송 버튼
                ElevatedButton.icon(
                  onPressed: _submitResult,
                  icon: Icon(Icons.send),
                  label: Text('결과 전송'),
                ),
                SizedBox(height: 20),
                Text(
                  _message,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          // _isSubmitting이 true일 때 표시할 오버레이
          if (_isSubmitting)
            AbsorbPointer(
              absorbing: true,
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.grey.withOpacity(0.5),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
