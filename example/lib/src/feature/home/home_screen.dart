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
        body: CustomScrollView(
          slivers: [
            const SliverAppBar(
              title: Text('RePaint: Examples'),
              centerTitle: true,
              floating: true,
              snap: true,
            ),
            SliverFixedExtentList(
              itemExtent: 128,
              delegate: SliverChildListDelegate(
                const <Widget>[
                  HomeTile(
                    title: 'Clock',
                    page: 'clock',
                  ),
                  HomeTile(
                    title: 'Shaders',
                    page: 'shaders',
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class HomeTile extends StatelessWidget {
  const HomeTile({
    required this.page,
    required this.title,
    this.subtitle,
    super.key, // ignore: unused_element
  });

  final String title;
  final String? subtitle;
  final String page;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 128,
        child: Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: InkWell(
                onTap: () => App.push(context, page),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    if (subtitle != null) Text(subtitle!),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: Colors.black26, thickness: 1),
          ],
        ),
      );
}
