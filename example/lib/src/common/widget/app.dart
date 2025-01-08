import 'package:flutter/material.dart';
import 'package:repaintexample/src/common/widget/routes.dart';
import 'package:repaintexample/src/feature/home/home_screen.dart';

/// {@template app}
/// App widget.
/// {@endtemplate}
class App extends StatefulWidget {
  /// {@macro app}
  const App({String? initalRoute, super.key}) : _initalRoute = initalRoute;

  final String? _initalRoute;

  /// Change the navigation stack.
  static void navigate(BuildContext context,
          List<Page<void>> Function(List<Page<void>> pages) change) =>
      context.findAncestorStateOfType<_AppState>()?.navigate(change);

  /// Add a page to the navigation stack.
  static void push(BuildContext context, String page,
          [Map<String, Object?>? arguments]) =>
      context.findAncestorStateOfType<_AppState>()?.push(page, arguments);

  /// Remove the current page from the navigation stack.
  static void pop(BuildContext context) =>
      context.findAncestorStateOfType<_AppState>()?.pop();

  /// Remove the given page from the navigation stack.
  static void removeByName(BuildContext context, Page<void> page) =>
      context.findAncestorStateOfType<_AppState>()?.removeByName(page);

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  static const List<Page<void>> defaultPages = <Page<void>>[
    MaterialPage<void>(name: 'home', child: HomeScreen()),
  ];

  /// The pages to display.
  final ValueNotifier<List<Page<void>>> _pages =
      ValueNotifier<List<Page<void>>>(defaultPages);

  @override
  void initState() {
    super.initState();
    final initialRoute = widget._initalRoute;
    if (initialRoute != null &&
        initialRoute.isNotEmpty &&
        initialRoute != '/') {
      final uri = Uri.tryParse(initialRoute);
      final page = $routes[uri?.pathSegments.firstOrNull]?.call(null);
      if (page != null) navigate((_) => [page]);
    }
  }

  /// Changes the navigation stack.
  void navigate(List<Page<void>> Function(List<Page<void>> pages) change) {
    final pages = change(_pages.value);
    assert(pages.isNotEmpty, 'Pages cannot be empty.');
    assert(pages.every((p) => p.name?.isNotEmpty ?? false),
        'Page names cannot be empty.');
    assert(pages.map((p) => p.name).toSet().length == pages.length,
        'Page names must be unique.');
    _pages.value =
        pages.isEmpty ? defaultPages : List<Page<void>>.unmodifiable(pages);
  }

  /// Navigates to the given page by name.
  void push(String page, [Map<String, Object?>? arguments]) {
    assert(page.isNotEmpty, 'Page name cannot be empty.');
    // Router
    final newPage = $routes[page]?.call(arguments);
    assert(newPage != null, 'Page not found: $page');
    if (newPage == null) return;
    _pages.value = List<Page<void>>.unmodifiable({
      for (final page in _pages.value)
        if (page.name != page.name) page,
      newPage,
    });
  }

  /// Pop the current page from the stack.
  void pop() {
    final pages = _pages.value.sublist(0, _pages.value.length - 1);
    _pages.value =
        pages.isEmpty ? defaultPages : List<Page<void>>.unmodifiable(pages);
  }

  /// Removes the given page from the stack.
  void removeByName(Page<void> page) {
    final pages =
        _pages.value.where((p) => p.name != page.name).toList(growable: false);
    _pages.value =
        pages.isEmpty ? defaultPages : List<Page<void>>.unmodifiable(pages);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'RePaint: Example',
        home: ValueListenableBuilder(
          valueListenable: _pages,
          builder: (context, pages, _) => Navigator(
            reportsRouteUpdateToEngine: false,
            pages: pages,
            onDidRemovePage: removeByName,
          ),
        ),
      );
}
