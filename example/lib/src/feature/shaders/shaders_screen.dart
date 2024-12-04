import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:repaint/repaint.dart';
import 'package:repaintexample/src/common/widget/app.dart';
import 'package:url_launcher/url_launcher_string.dart' as url_launcher;

/// {@template shaders_screen}
/// ShadersScreen widget.
/// {@endtemplate}
class ShadersScreen extends StatelessWidget {
  /// {@macro shaders_screen}
  const ShadersScreen({
    super.key, // ignore: unused_element
  });

  @override
  Widget build(BuildContext context) => Scaffold(
        body: CustomScrollView(
          slivers: <Widget>[
            SliverAppBar(
              leading: BackButton(
                onPressed: () => App.pop(context),
              ),
              title: const Text('Fragment Shaders'),
              centerTitle: true,
              floating: true,
              snap: true,
              actions: <Widget>[
                IconButton(
                  tooltip: 'Flutter Docs',
                  icon: const Icon(Icons.book),
                  onPressed: () => url_launcher.launchUrlString(
                      'https://docs.flutter.dev/ui/design/graphics/fragment-shaders'),
                ),
                IconButton(
                  tooltip: 'The Book of Shaders',
                  icon: const Icon(Icons.book),
                  onPressed: () => url_launcher
                      .launchUrlString('https://thebookofshaders.com'),
                ),
              ],
            ),
            ShaderContainer(
              shader: 'simple',
              blendMode: BlendMode.src,
              render: (canvas, size, paint) => canvas.drawRect(
                Offset.zero & size,
                paint,
              ),
            ),
          ],
        ),
      );
}

class ShaderContainer extends StatelessWidget {
  const ShaderContainer({
    required this.shader,
    required this.render,
    this.blendMode = BlendMode.src,
    this.height = 256,
    this.frameRate = 24,
    super.key, // ignore: unused_element
  });

  /// Shader file to load.
  final String shader;

  /// Height of the container.
  final double height;

  /// Render the shader.
  final void Function(Canvas canvas, Size size, Paint paint) render;

  /// Blend mode for the shader.
  final BlendMode blendMode;

  /// Frame rate for the shader.
  final int? frameRate;

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
        child: SizedBox(
          height: 256,
          child: FutureBuilder<ui.FragmentShader>(
            initialData: null,
            future: ResourceManager.loadShader('shaders/$shader.glsl'),
            builder: (context, snapshot) => switch (snapshot.connectionState) {
              ConnectionState.waiting ||
              ConnectionState.active ||
              ConnectionState.none =>
                const Center(
                  child: CircularProgressIndicator(),
                ),
              ConnectionState.done => switch (snapshot.data) {
                  ui.FragmentShader fragmentShader => Stack(
                      children: <Widget>[
                        const Positioned.fill(
                          child: ColoredBox(
                            color: Colors.grey,
                            child: SizedBox.expand(),
                          ),
                        ),
                        Positioned.fill(
                          child: RePaint.inline<Paint>(
                            frameRate: frameRate,
                            setUp: (box) => Paint()
                              ..blendMode = blendMode
                              ..shader = fragmentShader,
                            update: (_, paint, ___) =>
                                paint..blendMode = blendMode,
                            render: (box, paint, canvas) =>
                                render(canvas, box.size, paint),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          left: 8,
                          height: 24,
                          right: 8,
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: Text(
                              shader,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ),
                        ),
                      ],
                    ),
                  null => const Center(
                      child: Text('Failed to load shader.'),
                    ),
                },
            },
          ),
        ),
      );
}
