import 'dart:async';

/// 网络流量监控器
class TrafficMonitor {
  int _bytesSent = 0;
  int _bytesReceived = 0;
  DateTime _startTime = DateTime.now();
  final StreamController<TrafficStats> _statsController = StreamController<TrafficStats>.broadcast();

  Stream<TrafficStats> get statsStream => _statsController.stream;

  TrafficMonitor() {
    // 定期更新统计信息
    Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateStats();
    });
  }

  void recordSent(int bytes) {
    _bytesSent += bytes;
  }

  void recordReceived(int bytes) {
    _bytesReceived += bytes;
  }

  void _updateStats() {
    final duration = DateTime.now().difference(_startTime);
    final stats = TrafficStats(
      bytesSent: _bytesSent,
      bytesReceived: _bytesReceived,
      duration: duration,
      uploadSpeed: _bytesSent ~/ duration.inSeconds,
      downloadSpeed: _bytesReceived ~/ duration.inSeconds,
    );
    _statsController.add(stats);
  }

  void reset() {
    _bytesSent = 0;
    _bytesReceived = 0;
    _startTime = DateTime.now();
  }

  void dispose() {
    _statsController.close();
  }
}

class TrafficStats {
  final int bytesSent;
  final int bytesReceived;
  final Duration duration;
  final int uploadSpeed;
  final int downloadSpeed;

  TrafficStats({
    required this.bytesSent,
    required this.bytesReceived,
    required this.duration,
    required this.uploadSpeed,
    required this.downloadSpeed,
  });

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
