import 'dart:math';

import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  var num1 = 1;

  var num2 = 1;

  void play() {
    num1 = Random().nextInt(3) + 1;
    num2 = Random().nextInt(3) + 1;

    setState(() {});
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.orange,
          title: Text('Rock Paper Scissors'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  play();
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(10),
                      child: Image.asset(
                        'assets/i_$num1.png',
                        height: 120,
                        width: 120,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.all(10),
                      child: Image.asset(
                        'assets/i_$num2.png',
                        height: 120,
                        width: 120,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 100,
              ),
              Container(
                width: 100,
                height: 60,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                  onPressed: () {
                    play();
                  },
                  child: Text('Play'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
