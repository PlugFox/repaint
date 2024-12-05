import 'dart:math' as math; // ignore: unused_import
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:repaint/repaint.dart';
import 'package:repaintexample/src/common/widget/app.dart';
import 'package:url_launcher/url_launcher_string.dart' as url_launcher;

/// {@template shaders_screen}
/// ShadersScreen widget.
/// {@endtemplate}
class FragmentShadersScreen extends StatelessWidget {
  /// {@macro shaders_screen}
  const FragmentShadersScreen({
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
              frameRate: 24,
              render: (canvas, size, _, shader, paint) => canvas.drawRect(
                Offset.zero & size,
                paint,
              ),
            ),
            ShaderContainer(
              shader: 'uniforms',
              frameRate: 60,
              render: (canvas, size, mouse, shader, paint) {
                final now = DateTime.now().millisecondsSinceEpoch / 10000 % 10;
                // clamp(abs(0.5f + 0.5f * sin(time * PI / 4.0f)), 0.0f, 1.0f)
                //print((math.sin(now.clamp(0, 1) / (2 * math.pi))).abs());
                shader
                  ..setFloat(0, size.width)
                  ..setFloat(1, size.height)
                  ..setFloat(2, mouse.dx)
                  ..setFloat(3, mouse.dy)
                  ..setFloat(4, now);
                canvas.drawRect(
                  Offset.zero & size,
                  paint,
                );
              },
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
  final void Function(
    Canvas canvas,
    Size size,
    Offset mouse,
    ui.FragmentShader shader,
    Paint paint,
  ) render;

  /// Blend mode for the shader.
  final BlendMode blendMode;

  /// Frame rate for the shader.
  final int? frameRate;

  @override
  Widget build(BuildContext context) {
    var mouse = Offset.zero;
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverToBoxAdapter(
        child: SizedBox(
          height: 256,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: FutureBuilder<ui.FragmentShader>(
                  initialData: null,
                  future: ResourceManager.loadShader('shaders/$shader.frag'),
                  builder: (context, snapshot) =>
                      switch (snapshot.connectionState) {
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
                                child: MouseRegion(
                                  onHover: (event) =>
                                      mouse = event.localPosition,
                                  child: RePaint.inline<
                                      ({
                                        ui.FragmentShader shader,
                                        Paint paint,
                                      })>(
                                    frameRate: frameRate,
                                    setUp: (box) => (
                                      shader: fragmentShader,
                                      paint: Paint()
                                        ..blendMode = blendMode
                                        ..shader = fragmentShader
                                        ..filterQuality = FilterQuality.none
                                        ..isAntiAlias = false,
                                    ),
                                    update: (_, state, ___) =>
                                        state..paint.blendMode = blendMode,
                                    render: (box, state, canvas) => render(
                                      canvas,
                                      box.size,
                                      mouse,
                                      state.shader,
                                      state.paint,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 8,
                                left: 8,
                                height: 24,
                                right: 8,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: DecoratedBox(
                                    position: DecorationPosition.background,
                                    decoration: ShapeDecoration(
                                      color: Colors.black54,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(4.0),
                                      child: Text(
                                        shader,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelLarge
                                            ?.copyWith(
                                              height: 1,
                                              color: Colors.white,
                                            ),
                                      ),
                                    ),
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
              const Divider(height: 1, color: Colors.black26, thickness: 1),
            ],
          ),
        ),
      ),
    );
  }
}
