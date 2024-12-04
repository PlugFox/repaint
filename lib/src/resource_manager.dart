// ignore_for_file: avoid_classes_with_only_static_members

import 'dart:ui' as ui;

/// A resource manager for loading and caching resources.
abstract final class ResourceManager {
  /// A cache for loaded fragment shaders.
  static final Map<String, Future<ui.FragmentShader>> _shaderCache =
      <String, Future<ui.FragmentShader>>{};

  /// Loads a shader from assets.
  static Future<ui.FragmentShader> loadShader(String assetPath) =>
      _shaderCache[assetPath] ??= Future<ui.FragmentShader>(() async {
        final program = await ui.FragmentProgram.fromAsset(assetPath);
        return program.fragmentShader();
      });
}
