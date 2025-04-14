import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:graduate/utils/global.dart';
import 'package:http/http.dart' as http;

List<String> simulatedMatchResults = [];

class ResultInputDialog extends StatefulWidget {
  final Match match;

  ResultInputDialog({required this.match});

  @override
  _ResultInputDialogState createState() => _ResultInputDialogState();
}

class Match {
  final int id;

  Match({required this.id});

  factory Match.fromJson(Map<String, dynamic> json) {
    return Match(id: json['id']);
  }
}

class _ResultInputDialogState extends State<ResultInputDialog> {
  List<TextEditingController> redControllers =
  List.generate(3, (_) => TextEditingController());
  List<TextEditingController> blueControllers =
  List.generate(3, (_) => TextEditingController());

  String? selectedWinner;
  bool _isSubmitting = false;
  String _message = '';

  Future<void> _submitResult() async {
    if (selectedWinner == null) {
      setState(() {
        _message = '최종 승리팀을 선택해 주세요.';
      });
      return;
    }

    for (int i = 0; i < 3; i++) {
      if (redControllers[i].text.isEmpty || blueControllers[i].text.isEmpty) {
        setState(() {
          _message = '${i + 1}세트 점수를 모두 입력해 주세요.';
        });
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
      _message = '';
    });

    final body = {
      'matchId': 123,
      'redTeamScores':
      redControllers.map((c) => int.tryParse(c.text) ?? 0).toList(),
      'blueTeamScores':
      blueControllers.map((c) => int.tryParse(c.text) ?? 0).toList(),
      'winnerTeam': selectedWinner,
    };

    try {
      final response = await http.post(
        Uri.parse(
            'https://appledolphin.xyz/api/match/result-input/matches/result'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      final responseBody = jsonDecode(utf8.decode(response.bodyBytes));
      final isSuccess = responseBody['success'] ?? false;
      final serverMessage =
          responseBody['message'] ?? '알 수 없는 오류가 발생했습니다.';

      if (response.statusCode == 200 && isSuccess) {
        setState(() => _message = serverMessage);
        await Future.delayed(Duration(milliseconds: 500));
        Navigator.of(context).pop();
      } else {
        setState(() => _message = serverMessage);
      }
    } catch (e) {
      setState(() => _message = '네트워크 오류: $e');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Widget _buildScoreRow(int index) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 6),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${index + 1}세트 점수',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: redControllers[index],
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'RED 점수',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: blueControllers[index],
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'BLUE 점수',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWinnerSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ChoiceChip(
          label: Text('RED 승리'),
          selected: selectedWinner == 'RED',
          onSelected: (_) => setState(() => selectedWinner = 'RED'),
        ),
        SizedBox(width: 10),
        ChoiceChip(
          label: Text('BLUE 승리'),
          selected: selectedWinner == 'BLUE',
          onSelected: (_) => setState(() => selectedWinner = 'BLUE'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;

    return GestureDetector(
      onTap: () => !_isSubmitting ? Navigator.of(context).pop() : null,
      child: Material(
        color: Colors.black54,
        child: Center(
          child: GestureDetector(
            onTap: () {}, // 다이얼로그 외부 클릭 방지
            child: Padding(
              padding: EdgeInsets.only(bottom: viewInsets.bottom),
              child: Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('경기 결과 입력',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      SizedBox(height: 20),
                      _buildScoreRow(0),
                      _buildScoreRow(1),
                      _buildScoreRow(2),
                      _buildWinnerSelector(),
                      SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _submitResult,
                        icon: Icon(Icons.send),
                        label: Text('결과 전송'),
                      ),
                      SizedBox(height: 10),
                      Text(
                        _message,
                        style: TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}