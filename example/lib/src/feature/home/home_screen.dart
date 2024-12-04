import 'package:flutter/material.dart';
import 'package:repaintexample/src/common/widget/app.dart';

/// {@template home_screen}
/// HomeScreen widget.
/// {@endtemplate}
class HomeScreen extends StatelessWidget {
  /// {@macro home_screen}
  const HomeScreen({
    super.key, // ignore: unused_element
  });

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text('Home Screen'),
              ElevatedButton(
                onPressed: () => App.push(context, 'canvas'),
                child: const Text('Home'),
              ),
            ],
          ),
        ),
      );
}
