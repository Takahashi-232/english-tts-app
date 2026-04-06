import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class Question {
  final String en; // 英語
  final String jp; // 日本語

  Question({required this.en, required this.jp});

  // 保存用（ローカルストレージ）
  Map<String, dynamic> toJson() => {
        "jp": jp,
        "en": en,
      };

  // 読み込み用（JSONファイル / LocalStorage 両対応）
  factory Question.fromJson(Map<String, dynamic> json) {
    final jp = (json['jp'] ?? json['question'] ?? '') as String;
    final en = (json['en'] ?? json['answer'] ?? '') as String;
    return Question(en: en, jp: jp);
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: HomePage());
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Question> questions = [];
  int currentIndex = -1;

  bool isPlaying = false;

  double enSpeed = 1.0;
  double jpSpeed = 1.0;
  double interval = 1.0;
  double nextDelay = 1.0;
  double volume = 1.0;

  String displayedEnglish = "";

  final enController = TextEditingController();
  final jpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadAll();
  }

  Future<void> loadAll() async {
    await loadJson();
    loadLocal();
  }

  // JSON読み込み（GitHub Pages対応）
  Future<void> loadJson() async {
    try {
      final res = await html.window.fetch('assets/questions.json');
      final text = await res.text();
      final data = json.decode(text);

      questions.addAll(
        (data as List).map((e) => Question.fromJson(e)),
      );
    } catch (_) {}
    setState(() {});
  }

  // LocalStorage読み込み
  void loadLocal() {
    final str = html.window.localStorage['my_questions'];
    if (str != null) {
      final data = json.decode(str);
      questions.addAll(
        (data as List).map((e) => Question.fromJson(e)),
      );
    }
    setState(() {});
  }

  void saveLocal() {
    final data = questions.map((e) => e.toJson()).toList();
    html.window.localStorage['my_questions'] = json.encode(data);
  }

  // 追加
  void addQuestion() {
    if (enController.text.isEmpty || jpController.text.isEmpty) return;

    setState(() {
      questions.add(
        Question(en: enController.text, jp: jpController.text),
      );
      enController.clear();
      jpController.clear();
    });

    saveLocal();
  }

  Future<void> speak(String text, String lang, double speed) async {
    html.window.speechSynthesis?.cancel();

    final utter = html.SpeechSynthesisUtterance(text);
    utter.lang = lang;
    utter.rate = speed;
    utter.volume = volume;

    html.window.speechSynthesis?.speak(utter);

    await Future.delayed(
      Duration(milliseconds: (text.length * 80 / speed).toInt()),
    );
  }

  // 🔁 日本語 → 英語 の順で再生
  Future<void> playLoop() async {
    setState(() {
      isPlaying = true;
    });

    while (isPlaying && questions.isNotEmpty) {
      currentIndex = (currentIndex + 1) % questions.length;
      final q = questions[currentIndex];

      // まず日本語を表示して、日本語を読む
      setState(() {
        displayedEnglish = "";
      });

      await speak(q.jp, "ja-JP", jpSpeed);

      await Future.delayed(
        Duration(milliseconds: (interval * 1000).toInt()),
      );

      // 次に英語を読み上げて、その後英語を表示
      await speak(q.en, "en-US", enSpeed);

      setState(() {
        displayedEnglish = q.en;
      });

      await Future.delayed(
        Duration(milliseconds: (nextDelay * 1000).toInt()),
      );
    }
  }

  void stop() {
    setState(() {
      isPlaying = false;
    });
    html.window.speechSynthesis?.cancel();
  }

  void selectQuestion(int i) {
    setState(() {
      currentIndex = i - 1;
    });
  }

  void openSettings() {
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text("設定"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("英語スピード"),
                Slider(
                  value: enSpeed,
                  min: 0.5,
                  max: 2,
                  onChanged: (v) {
                    setState(() => enSpeed = v);
                    setStateDialog(() {});
                  },
                ),
                const Text("日本語スピード"),
                Slider(
                  value: jpSpeed,
                  min: 0.5,
                  max: 2,
                  onChanged: (v) {
                    setState(() => jpSpeed = v);
                    setStateDialog(() {});
                  },
                ),
                const Text("英語→日本語の間隔"),
                Slider(
                  value: interval,
                  min: 0,
                  max: 3,
                  onChanged: (v) {
                    setState(() => interval = v);
                    setStateDialog(() {});
                  },
                ),
                const Text("次の問題までの待ち時間"),
                Slider(
                  value: nextDelay,
                  min: 0,
                  max: 3,
                  onChanged: (v) {
                    setState(() => nextDelay = v);
                    setStateDialog(() {});
                  },
                ),
                const Text("音量"),
                Slider(
                  value: volume,
                  min: 0,
                  max: 1,
                  onChanged: (v) {
                    setState(() => volume = v);
                    setStateDialog(() {});
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("英語TTS")),
      body: Column(
        children: [
          if (currentIndex >= 0)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                questions[currentIndex].jp,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          Text(displayedEnglish),

          // 入力UI
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                TextField(
                  controller: enController,
                  decoration: const InputDecoration(labelText: "英語"),
                ),
                TextField(
                  controller: jpController,
                  decoration: const InputDecoration(labelText: "日本語"),
                ),
                ElevatedButton(
                  onPressed: addQuestion,
                  child: const Text("追加"),
                )
              ],
            ),
          ),

          Expanded(
            child: ListView.builder(
              itemCount: questions.length,
              itemBuilder: (_, i) {
                return ListTile(
                  title: Text(questions[i].jp),
                  tileColor:
                      i == currentIndex ? Colors.lightBlue.shade100 : null,
                  onTap: () => selectQuestion(i),
                );
              },
            ),
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: isPlaying ? null : playLoop,
                child: const Text("開始"),
              ),
              ElevatedButton(
                onPressed: stop,
                child: const Text("停止"),
              ),
              ElevatedButton(
                onPressed: openSettings,
                child: const Text("設定"),
              ),
            ],
          )
        ],
      ),
    );
  }
}