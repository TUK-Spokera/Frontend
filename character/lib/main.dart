import 'package:flutter/material.dart';

void main() {
  runApp(CharacterCustomizerApp());
}

class CharacterCustomizerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: CharacterCustomizerScreen(),
    );
  }
}

class CharacterCustomizerScreen extends StatefulWidget {
  @override
  _CharacterCustomizerScreenState createState() => _CharacterCustomizerScreenState();
}

class _CharacterCustomizerScreenState extends State<CharacterCustomizerScreen> {
  int selectedHair = 0;
  int selectedEyes = 0;
  int selectedMouth = 0;
  Color skinColor = Colors.brown[200]!;

  final List<String> hairOptions = ['assets/hair1.png', 'assets/hair2.png'];
  final List<String> eyesOptions = ['assets/eyes1.png', 'assets/eyes2.png'];
  final List<String> mouthOptions = ['assets/mouth1.png', 'assets/mouth2.png'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("캐릭터 커스텀")),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(width: 150, height: 200, color: skinColor), // 얼굴
                  Image.asset(hairOptions[selectedHair], width: 150), // 머리
                  Image.asset(eyesOptions[selectedEyes], width: 100), // 눈
                  Image.asset(mouthOptions[selectedMouth], width: 80), // 입
                ],
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text("머리"),
              DropdownButton<int>(
                value: selectedHair,
                items: List.generate(hairOptions.length, (index) {
                  return DropdownMenuItem(value: index, child: Text("스타일 ${index + 1}"));
                }),
                onChanged: (value) {
                  setState(() {
                    selectedHair = value!;
                  });
                },
              ),
              Text("눈"),
              DropdownButton<int>(
                value: selectedEyes,
                items: List.generate(eyesOptions.length, (index) {
                  return DropdownMenuItem(value: index, child: Text("눈 ${index + 1}"));
                }),
                onChanged: (value) {
                  setState(() {
                    selectedEyes = value!;
                  });
                },
              ),
            ],
          ),
          ElevatedButton(
            onPressed: () {
              // 선택한 캐릭터 데이터 저장하는 로직 추가 가능
            },
            child: Text("저장"),
          ),
        ],
      ),
    );
  }
}
