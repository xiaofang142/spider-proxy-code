import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'ui/pages/home_page.dart';
import 'ui/pages/capture_list_page.dart';
import 'ui/pages/settings_page.dart';

// App State
class AppState {
  final bool isProxyRunning;
  final int capturedCount;
  final List<CaptureItem> captures;

  AppState({
    this.isProxyRunning = false,
    this.capturedCount = 0,
    this.captures = const [],
  });

  AppState copyWith({
    bool? isProxyRunning,
    int? capturedCount,
    List<CaptureItem>? captures,
  }) {
    return AppState(
      isProxyRunning: isProxyRunning ?? this.isProxyRunning,
      capturedCount: capturedCount ?? this.capturedCount,
      captures: captures ?? this.captures,
    );
  }
}

class CaptureItem {
  final String id;
  final String url;
  final String method;
  final int statusCode;
  final DateTime timestamp;

  CaptureItem({
    required this.id,
    required this.url,
    required this.method,
    required this.statusCode,
    required this.timestamp,
  });
}

// Reducers
AppState appReducer(AppState state, dynamic action) {
  if (action is ToggleProxyAction) {
    return state.copyWith(isProxyRunning: !state.isProxyRunning);
  } else if (action is AddCaptureAction) {
    final newCaptures = List<CaptureItem>.from(state.captures)..add(action.capture);
    return state.copyWith(
      captures: newCaptures,
      capturedCount: newCaptures.length,
    );
  }
  return state;
}

class ToggleProxyAction {}

class AddCaptureAction {
  final CaptureItem capture;
  AddCaptureAction(this.capture);
}

void main() {
  runApp(const SpiderProxyApp());
}

class SpiderProxyApp extends StatelessWidget {
  const SpiderProxyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final store = Store<AppState>(
      appReducer,
      initialState: AppState(),
    );

    return StoreProvider(
      store: store,
      child: MaterialApp(
        title: 'Spider Proxy',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const MainNavigationPage(),
      ),
    );
  }
}

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const HomePage(),
    const CaptureListPage(),
    const SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.list),
            label: '抓包',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
