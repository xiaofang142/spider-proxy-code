import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'ui/pages/home_page.dart';
import 'ui/pages/capture_list_page.dart';
import 'ui/pages/settings_page.dart';
import 'ui/pages/analysis_page.dart';
import 'core/proxy_service.dart';
import 'core/models/traffic_record.dart';

// App State
class AppState {
  final bool isProxyRunning;
  final int capturedCount;
  final List<CaptureItem> captures;
  final TrafficStats? trafficStats;
  final ProxyStatus proxyStatus;

  AppState({
    this.isProxyRunning = false,
    this.capturedCount = 0,
    this.captures = const [],
    this.trafficStats,
    this.proxyStatus = ProxyStatus.stopped,
  });

  AppState copyWith({
    bool? isProxyRunning,
    int? capturedCount,
    List<CaptureItem>? captures,
    TrafficStats? trafficStats,
    ProxyStatus? proxyStatus,
  }) {
    return AppState(
      isProxyRunning: isProxyRunning ?? this.isProxyRunning,
      capturedCount: capturedCount ?? this.capturedCount,
      captures: captures ?? this.captures,
      trafficStats: trafficStats ?? this.trafficStats,
      proxyStatus: proxyStatus ?? this.proxyStatus,
    );
  }
}

/// 代理状态
enum ProxyStatus {
  stopped,
  starting,
  running,
  stopping,
  error,
}

/// 流量统计
class TrafficStats {
  final int bytesSent;
  final int bytesReceived;
  final int uploadSpeed;
  final int downloadSpeed;
  final int requestCount;
  final DateTime startTime;

  TrafficStats({
    this.bytesSent = 0,
    this.bytesReceived = 0,
    this.uploadSpeed = 0,
    this.downloadSpeed = 0,
    this.requestCount = 0,
    DateTime? startTime,
  }) : startTime = startTime ?? DateTime.now();

  TrafficStats copyWith({
    int? bytesSent,
    int? bytesReceived,
    int? uploadSpeed,
    int? downloadSpeed,
    int? requestCount,
    DateTime? startTime,
  }) {
    return TrafficStats(
      bytesSent: bytesSent ?? this.bytesSent,
      bytesReceived: bytesReceived ?? this.bytesReceived,
      uploadSpeed: uploadSpeed ?? this.uploadSpeed,
      downloadSpeed: downloadSpeed ?? this.downloadSpeed,
      requestCount: requestCount ?? this.requestCount,
      startTime: startTime ?? this.startTime,
    );
  }

  String get totalSent => _formatBytes(bytesSent);
  String get totalReceived => _formatBytes(bytesReceived);
  String get currentUploadSpeed => _formatBytes(uploadSpeed) + '/s';
  String get currentDownloadSpeed => _formatBytes(downloadSpeed) + '/s';

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
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

  /// 从 TrafficRecord 创建 CaptureItem
  factory CaptureItem.fromTrafficRecord(TrafficRecord record) {
    return CaptureItem(
      id: record.id,
      url: record.url,
      method: record.method,
      statusCode: record.statusCode,
      timestamp: record.timestamp,
    );
  }
}

// Reducers
AppState appReducer(AppState state, dynamic action) {
  if (action is ToggleProxyAction) {
    return state.copyWith(
      isProxyRunning: !state.isProxyRunning,
      proxyStatus: state.isProxyRunning ? ProxyStatus.stopping : ProxyStatus.starting,
    );
  } else if (action is ProxyStartedAction) {
    return state.copyWith(
      isProxyRunning: true,
      proxyStatus: ProxyStatus.running,
      trafficStats: TrafficStats(startTime: DateTime.now()),
    );
  } else if (action is ProxyStoppedAction) {
    return state.copyWith(
      isProxyRunning: false,
      proxyStatus: ProxyStatus.stopped,
      trafficStats: null,
    );
  } else if (action is ProxyErrorAction) {
    return state.copyWith(
      proxyStatus: ProxyStatus.error,
    );
  } else if (action is AddCaptureAction) {
    final newCaptures = List<CaptureItem>.from(state.captures)..add(action.capture);
    return state.copyWith(
      captures: newCaptures,
      capturedCount: newCaptures.length,
    );
  } else if (action is UpdateTrafficStatsAction) {
    return state.copyWith(
      trafficStats: action.stats,
    );
  } else if (action is ClearCapturesAction) {
    return state.copyWith(
      captures: [],
      capturedCount: 0,
    );
  }
  return state;
}

class ToggleProxyAction {}
class ProxyStartedAction {}
class ProxyStoppedAction {}
class ProxyErrorAction {
  final String message;
  ProxyErrorAction(this.message);
}

class AddCaptureAction {
  final CaptureItem capture;
  AddCaptureAction(this.capture);
}

class UpdateTrafficStatsAction {
  final TrafficStats stats;
  UpdateTrafficStatsAction(this.stats);
}

class ClearCapturesAction {}

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
  StreamSubscription? _trafficSubscription;

  final ProxyServiceManager _proxyService = ProxyServiceManager();

  final List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    _pages.addAll([
      HomePage(proxyService: _proxyService),
      AnalysisPage(),
      CaptureListPage(proxyService: _proxyService),
      SettingsPage(proxyService: _proxyService),
    ]);

    // 初始化代理服务
    _initializeProxy();
  }

  Future<void> _initializeProxy() async {
    try {
      // 初始化流量存储
      await _proxyService.initialize();

      // 监听流量记录
      _trafficSubscription = _proxyService.trafficStream.listen((record) {
        // 当有新的流量记录时，更新 UI
        if (mounted) {
          StoreProvider.of<AppState>(context).dispatch(
            AddCaptureAction(CaptureItem.fromTrafficRecord(record)),
          );
        }
      });
    } catch (e) {
      print('[MainNavigationPage] Error initializing proxy: $e');
    }
  }

  @override
  void dispose() {
    _trafficSubscription?.cancel();
    _proxyService.dispose();
    super.dispose();
  }

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
            icon: Icon(Icons.analytics),
            label: '分析',
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
