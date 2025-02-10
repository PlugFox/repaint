import 'package:flutter/material.dart';
import 'package:repaintexample/src/feature/clock/clock_screen.dart';
import 'package:repaintexample/src/feature/fps/fps_screen.dart';
import 'package:repaintexample/src/feature/home/home_screen.dart';
import 'package:repaintexample/src/feature/performance_overlay/performance_overlay_screen.dart';
import 'package:repaintexample/src/feature/quadtree/quadtree_collision_screen.dart';
import 'package:repaintexample/src/feature/quadtree/quadtree_screen.dart';
import 'package:repaintexample/src/feature/shaders/fragment_shaders_screen.dart';
import 'package:repaintexample/src/feature/sunflower/sunflower_screen.dart';

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
  'performance-overlay': (arguments) => MaterialPage<void>(
        name: 'performance-overlay',
        child: const PerformanceOverlayScreen(),
        arguments: arguments,
      ),
  'sunflower': (arguments) => MaterialPage<void>(
        name: 'sunflower',
        child: const SunflowerScreen(),
        arguments: arguments,
      ),
  'quadtree': (arguments) => MaterialPage<void>(
        name: 'quadtree',
        child: const QuadTreeScreen(),
        arguments: arguments,
      ),
  'quadtree-collisions': (arguments) => MaterialPage<void>(
        name: 'quadtree-collisions',
        child: const QuadTreeCollisionScreen(),
        arguments: arguments,
      ),
};
