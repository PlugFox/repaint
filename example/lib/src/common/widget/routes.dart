import 'package:flutter/material.dart';
import 'package:repaintexample/src/feature/clock/clock_screen.dart';
import 'package:repaintexample/src/feature/fps/fps_screen.dart';
import 'package:repaintexample/src/feature/home/home_screen.dart';
import 'package:repaintexample/src/feature/shaders/fragment_shaders_screen.dart';

/// The routes to navigate to.
final Map<String, Page<void> Function(Map<String, Object?>?)> $routes =
    <String, Page<void> Function(Map<String, Object?>?)>{
  'home': (arguments) => MaterialPage<void>(
        name: 'home',
        child: const HomeScreen(),
        arguments: arguments,
      ),
  'clock': (arguments) => MaterialPage<void>(
        name: 'clock',
        child: const ClockScreen(),
        arguments: arguments,
      ),
  'fragment-shaders': (arguments) => MaterialPage<void>(
        name: 'fragment-shaders',
        child: const FragmentShadersScreen(),
        arguments: arguments,
      ),
  'fps': (arguments) => MaterialPage<void>(
        name: 'fps',
        child: const FpsScreen(),
        arguments: arguments,
      ),
};
