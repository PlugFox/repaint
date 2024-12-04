import 'package:flutter/material.dart';
import 'package:repaintexample/src/common/widget/app.dart';

/// {@template canvas_screen}
/// CanvasScreen widget.
/// {@endtemplate}
class CanvasScreen extends StatelessWidget {
  /// {@macro canvas_screen}
  const CanvasScreen({
    super.key, // ignore: unused_element
  });

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Canvas Screen'),
        ),
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Text('Canvas Screen'),
                ElevatedButton(
                  onPressed: () => App.pop(context),
                  child: const Text('Back'),
                ),
              ],
            ),
          ),
        ),
      );
}
